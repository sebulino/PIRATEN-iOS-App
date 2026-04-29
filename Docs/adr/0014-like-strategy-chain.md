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

The initial chain shipped with three strategies, but the owner verified
in the browser Network tab on 2026-04-22 that the live instance uses
`POST /post_actions` directly — the discourse-reactions plugin is not
installed. `DiscourseReactionsStrategy` was therefore dropped from the
chain (it would only have returned 404). The remaining two strategies,
in order:

1. `PostActionsFormStrategy` — `POST /post_actions.json` with
   `Content-Type: application/x-www-form-urlencoded` and
   `id=…&post_action_type_id=2`. Matches what the Discourse web UI
   sends. Targets hypothesis B.
2. `PostActionsJSONStrategy` — current shipping behaviour with JSON
   body. Kept as a fallback so we don't regress if a future Discourse
   release reverses the parser preference.

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
- **Negative.** The first like per install may issue up to two
  requests instead of one (down from three before the chain was
  narrowed by browser observation). After the first success, the cache
  absorbs this cost.
- **Negative.** "Confirmed success" relies on string matching against
  the response body for `/post_actions.json` strategies. If Discourse
  changes its response shape, the marker check would false-negative
  and we'd fall through unnecessarily. Mitigated by trying the
  reactions strategy first, where confirmation is body-non-empty.
- **Follow-ups.**
  - Browser-Network-tab confirmed the canonical `/post_actions`
    endpoint is in use; reactions plugin dropped from the chain
    on 2026-04-22.
  - One additional browser observation will narrow the chain to a
    single strategy: read the request `Content-Type` header and the
    payload encoding (Form Data vs Request Payload) for the Discourse
    web UI's like POST. If `application/x-www-form-urlencoded` →
    keep only `PostActionsFormStrategy`. If `application/json` →
    something else is going on; pursue hypothesis C (User API Key
    scope) via a follow-up ADR amending the
    `/user-api-key/new` handshake scopes.
  - Once TestFlight observation confirms a single winning strategy,
    narrow the registry to that one strategy and remove the others.
    Expected before App Store submission.
  - `RealDiscourseRepository.runStrategyChain` is a candidate for
    extraction into a generic `OperationStrategyChain<T>` if a second
    operation ends up needing the same probe-and-cache pattern.
