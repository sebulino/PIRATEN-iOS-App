# ADR-0014 — Like / unlike via a strategy chain with cached winner

- **Status:** Accepted
- **Date:** 2026-04
- **Deciders:** Sebastian Alscher
- **Related:** FR-FORUM-004, ADR-0009, OPEN-02 (#70)

## Context

Likes posted from the app did not propagate to the live Discourse instance.
The optimistic UI flipped the heart state on-device, but reloading the
topic from any other Discourse client showed no like. `POST /post_actions.json`
returned 2xx; the action simply was not persisted server-side. Documented
as OPEN-02 and tagged as a v1 ship blocker because FR-FORUM-004 promises
likes work end-to-end.

Three hypotheses fit the observed silent-2xx signature:

**A — discourse-reactions plugin override.** The plugin replaces the
canonical like flow with its own controller at
`/discourse-reactions/posts/{id}/custom-reactions/{reaction}/toggle.json`.
The legacy `/post_actions.json` route is left in place but becomes a
no-op. This is the most common cause of the symptom in the wild.

**B — request shape.** Some Discourse builds parse the JSON body for
post actions loosely but only honour form-encoded payloads through the
PostActionsController. The web UI sends form-encoded; the app sent JSON.

**C — User API Key scope.** The handshake requests `read,write,session_info`.
If the instance's scope-to-route mapping does not include post actions
under `write`, the request would 403 — but the observed behaviour is
2xx, so this is the least likely root cause and is not addressed here.

Prior investigation (browsing the official Discourse mobile app source,
following the documented API) did not converge on a fix. We do not have
admin access to the instance to read its plugin list or its scope
mapping directly.

## Decision

**Likes flow through a strategy chain. Each strategy is one concrete
endpoint shape. The repository tries strategies in order until one
returns confirmed success, and caches the winner in UserDefaults.**

The chain is defined in
[`PIRATEN/Core/Data/Discourse/LikeStrategy.swift`](../../PIRATEN/Core/Data/Discourse/LikeStrategy.swift)
as `LikeStrategyRegistry.all`.

The initial chain shipped with three strategies. Two rounds of
empirical narrowing on 2026-04-22 collapsed it to a single strategy:

**Round 1 (URL).** Owner captured a like in the browser Network tab.
The request went to `POST /post_actions` directly — the
discourse-reactions plugin is not installed on this instance.
`DiscourseReactionsStrategy` dropped (would have returned 404).

**Round 2 (request shape).** Same browser capture revealed the precise
shape:

```
POST /post_actions HTTP/1.1
Content-Type: application/x-www-form-urlencoded; charset=UTF-8
X-Requested-With: XMLHttpRequest
Content-Length: 46

id=1911&post_action_type_id=2&flag_topic=false
```

Three things the previous JSON shipping behaviour got wrong:

- Body was JSON, not form-encoded. Likely cause of OPEN-02's silent
  failure: Rails' default `wrap_parameters` initializer wraps JSON
  bodies under a key matching the controller name
  (`post_actions_controller` → `post_action`), which can route the
  request through a different code path than the form-encoded variant
  even though Rails-level `params[:id]` is technically still populated.
- `flag_topic=false` was missing. Even on like requests, some Discourse
  builds short-circuit when this field is absent.
- `X-Requested-With: XMLHttpRequest` was missing. Defensive against
  controllers that gate write actions on the AJAX-marker header.

`PostActionsFormStrategy` was updated to reproduce all three. The
chain is now `[PostActionsFormStrategy]` only. The other strategy
implementations remain in `LikeStrategy.swift` as documentation of
alternatives considered; they are not wired in.

A success is defined as either:

- A 2xx response from a strategy whose endpoint inherently confirms the
  action (the reactions plugin echoes the post's reactions; we check the
  body is non-empty).
- For the `/post_actions.json` strategies, a 2xx response whose body
  contains the `actions_summary` marker or `"acted":true`. An empty
  2xx body is treated as a soft failure — the chain moves on to the
  next strategy.

A 4xx/5xx is always a hard failure and aborts the chain (we don't want
to mask a genuine auth failure as silent fall-through). A 404 from the
reactions strategy is a soft failure (plugin not installed → fall through).

The winning strategy's identifier is persisted under
`discourse_like_winning_strategy` in UserDefaults. On subsequent likes
the cached winner is moved to the front of the chain, so steady-state
behaviour is one request per like — not three.

Unlike is symmetric: `DiscourseReactionsStrategy` is a toggle on the
plugin endpoint, and the `PostActions` strategies share a single
`DELETE /post_actions/{postId}.json?post_action_type_id=2` request.

## Consequences

- **Positive.** OPEN-02 closes regardless of which of A, B, C is
  actually the cause on the live instance — the chain probes for the
  one that works. The fix is observable: if a like persists, we know
  which strategy won by reading the cache key. Re-installing or
  swapping plugins on the Discourse side does not require an app
  release; the cache invalidates on next mismatch and the chain
  re-discovers.
- **Negative.** The chain machinery (probe-and-cache) is now overkill
  for a single-strategy registry. It's kept anyway because (a) it costs
  one indirection per like, (b) it gives a single place to re-add
  strategies if Discourse changes behaviour, and (c) the cached
  identifier in UserDefaults is observable in DEBUG builds, useful for
  quick diagnosis without redeploying. Removing the chain in favour
  of a direct call would be a one-line refactor if it ever feels
  worth it.
- **Negative.** "Confirmed success" relies on string matching against
  the response body for `/post_actions.json` strategies. If Discourse
  changes its response shape, the marker check would false-negative
  and we'd fall through unnecessarily. Mitigated by trying the
  reactions strategy first, where confirmation is body-non-empty.
- **Follow-ups.**
  - Browser-Network-tab observation 2026-04-22 narrowed the chain in
    two rounds: first to drop the reactions plugin, then to commit to
    `PostActionsFormStrategy` exclusively after capturing the exact
    request shape (form-encoded body with `flag_topic=false`,
    `X-Requested-With: XMLHttpRequest`, no CSRF token because User
    API Key auth bypasses Discourse's CSRF protection).
  - Verification: tap a like in TestFlight; reload the topic from a
    separate Discourse client and confirm the like appears. If it
    does, OPEN-02 is fully closed. If it does not despite the request
    shape now matching the web UI byte-for-byte, the next hypothesis
    is User API Key scope mapping — pursued via a follow-up ADR
    amending the `/user-api-key/new` handshake scopes.
  - `RealDiscourseRepository.runStrategyChain` is a candidate for
    extraction into a generic `OperationStrategyChain<T>` if a second
    operation ends up needing the same probe-and-cache pattern.
