# Glossary

Short definitions of project-specific terms. Kept brief on purpose — add a
line when a new term of art enters the codebase.

| Term | Meaning |
|---|---|
| **Piratenpartei** | Pirate Party of Germany; the app's user base. |
| **Pirat / Piratin** | Member of the Piratenpartei. Used as the endonym in UI copy. |
| **Vorstand** | Elected board of a party chapter. Can be federal (BuVo), state (LaVo) or local. |
| **Landesverband (LV)** | State-level party chapter. |
| **Bezirksverband (BZV)** | District-level party chapter. |
| **Kreisverband (KV)** | Municipal / regional party chapter. |
| **GMM** | *Generalversammlung der Mitglieder* — general members' meeting. |
| **Stammtisch** | Regular informal meet-up. |
| **BGE** | *Bedingungsloses Grundeinkommen* — universal basic income; a long-standing party policy area. |
| **PiratenSSO** | The party's central Single Sign-On. Every member has an account. Implemented on Keycloak. |
| **Discourse** | The forum software running at `diskussion.piratenpartei.de`. Backend of record for discussion content in this app. |
| **Agitatorrr** | Party events tool, at `agitatorrr.de`. The app consumes its public iCal feed. Also historically known as "Piragitator". |
| **meine-piraten.de** | Services maintained by the party for members; hosts the ToDo and News APIs the app consumes. |
| **PIRATEN-Kanon** | The curated body of introductory and reference content, maintained in a GitHub repository and surfaced by the app as "Wissen". |
| **Kajüte** | The app's home screen. Nautical register matching the party's identity. |
| **Treffen / Aktion** | Event type badges shown on the Termine tab. |
| **User API Key** | Discourse-specific per-user authentication credential, obtained via `/user-api-key/new` (ADR-0009). |
| **ADR** | Architecture Decision Record. A short document capturing one decision, its context and its consequences. |
| **MoSCoW** | Requirements-prioritisation scheme: Must / Should / Could / Won't. |
| **TestFlight** | Apple's beta distribution system. The app's initial release vehicle before public App Store distribution. |
