# MeinePIRATEN — Documentation

Engineering documentation for **MeinePIRATEN**, a native iOS application for
members of the Piratenpartei Deutschland.

> **Status:** pre-1.0 development. See [`open-issues.md`](./open-issues.md)
> for known blockers and tracked items.

## Why this app exists

The party's communication has fragmented across many messengers. From a
community perspective this has three consequences:

1. **No shared place.** Members only hear from the small subgroups they
   happen to be in. There is no common ground for party-wide discussion.
2. **Knowledge dies in chats.** Information that could onboard new members
   or coordinate political actions evaporates in message history.
3. **Critical mass is never reached.** Political actions fail to mobilise
   because no single channel reaches enough members.

The long-term answer is the party's Discourse instance at
`diskussion.piratenpartei.de` as the canonical place for discussion and
knowledge. The short-term obstacle is behavioural: members do not sit down
at a desktop to read a forum. They have a "Telegram mentality" — they
open their phone for five minutes and expect something to be there.

**MeinePIRATEN bridges that gap.** It is a mobile, notification-driven
front-end that channels activity into Discourse while exposing it through
an interface that feels familiar to messenger users.

## How to read these documents

| If you want to… | Start here |
|---|---|
| Understand *what* the app does | [`requirements.md`](./requirements.md) |
| Understand *why* architectural choices were made | [`adr/`](./adr/) |
| Understand *how* the pieces fit together | [`architecture.md`](./architecture.md) |
| Understand the external systems it talks to | [`integrations.md`](./integrations.md) |
| Understand what is *not yet solved* | [`open-issues.md`](./open-issues.md) |
| Understand terminology | [`glossary.md`](./glossary.md) |
| See the reasoning behind specific decisions | [`decisions-log.md`](./decisions-log.md) |
| Review project security posture | [`threat-model.md`](./threat-model.md) |
| Check the release checklist | [`release-checklist.md`](./release-checklist.md) |

## Document conventions

- Requirements use **MoSCoW** (Must / Should / Could / Won't) and are stably
  numbered (`FR-AUTH-001`, `NFR-001`) so they can be referenced from issues,
  ADRs and code comments.
- Architecture decisions follow the lightweight **Michael Nygard ADR**
  format.
- All engineering documents are written in English so contributors outside
  the German-speaking party can participate. The app's UI itself is German.
- Open issues have stable `OPEN-xx` identifiers.
- Q&A style decisions captured during the initial architecture pass have
  stable `Q-xxx` identifiers in [`decisions-log.md`](./decisions-log.md).

## Repository layout

```
meine-piraten-ios/
├── docs/                                      ← you are here
│   ├── README.md
│   ├── requirements.md
│   ├── architecture.md
│   ├── integrations.md
│   ├── open-issues.md
│   ├── glossary.md
│   ├── decisions-log.md
│   ├── threat-model.md
│   ├── release-checklist.md
│   └── adr/
│       ├── README.md
│       ├── TEMPLATE.md
│       └── 0001-…-0013-…
├── PIRATEN/                                   ← app source
├── PIRATENTests/
├── PIRATENUITests/
├── Config/
│   ├── Secrets.sample.xcconfig                ← committed
│   └── Secrets.xcconfig                       ← gitignored, local
└── PIRATEN.xcodeproj
```
