# Wissen-Tab in der PIRATEN-App – Darstellungskonzept (ohne Textwände)

## Zielbild
Der Tab **„Wissen“** vermittelt Grundlagen des politischen Betriebs (z.B. Bundestagswahl, Kommunalpolitik) sowie parteiinterne und organisatorische Themen (z.B. Adressänderung, Verbände finden, Kreisparteitag organisieren).  
Die Darstellung ist **smartphone-gerecht**, **motivierend** und **schrittweise** aufgebaut: Nutzerinnen und Nutzer sollen **nicht von langen Textblöcken erschlagen** werden, sondern **in kurzen Lektionen** lernen und dabei **Fortschritt** erleben.

---

## Leitprinzipien
1. **Micro-Learning statt Artikel**  
   Inhalte werden als **Lektion in kleinen Abschnitten** präsentiert: erst Überblick, dann Details.
2. **Progressive Disclosure**  
   Komplexität wird „aufklappbar“ gemacht (Details, Beispiele, Rechtstexte), damit die erste Ansicht leicht bleibt.
3. **Interaktion statt Passivkonsum**  
   Checklisten, kurze Quizfragen und kleine Aufgaben erhöhen Aufmerksamkeit und Lernerfolg.
4. **Motivation durch sichtbaren Fortschritt**  
   Lesedauer, Fortschrittsanzeige und „abgeschlossen“-Status machen Lernen greifbar.

---

## Informationsarchitektur (Navigation)
### 1) Wissen-Startseite
- **Suche** (schnell ein Thema finden)
- **Empfohlen** (kuratiert / featured)
- **Weiterlesen** (Fortsetzen, wo man zuletzt war)
- **Kategorien als Kacheln/Cards** (aus GitHub-Ordnern ableitbar)

### 2) Kategorie-Ansicht
- Kurzer **Kategorie-Introtext**
- **Themenliste als Cards**, pro Thema:
  - Titel + Kurzbeschreibung (Summary)
  - geschätzte Lesedauer
  - Level (z.B. Einsteiger)
  - Status: ungelesen / begonnen / abgeschlossen

### 3) Themen-Ansicht als „Lektion“
Statt einer langen Seite wird ein Thema in **verdauliche Lernblöcke** zerlegt.

---

## Lektionen-Design (damit Lesen Spaß macht)
Jede Lektion folgt möglichst einem einheitlichen, wiedererkennbaren Muster:

1. **Kurzüberblick (30 Sekunden)**  
   3–7 Bulletpoints als Einstieg.
2. **Warum ist das wichtig?**  
   Ein kurzer Absatz zur Einordnung.
3. **Schritt-für-Schritt / Abschnitte**  
   Kleine, nummerierte Teilkapitel.
4. **Begriffe** (Glossar, ausklappbar)  
   Begriffserklärungen als „kleine Häppchen“.
5. **Checkliste** (interaktiv)  
   Abhakbar; fördert das Gefühl von Fortschritt.
6. **Mini-Quiz** (optional, 2–5 Fragen)  
   Kurzer Abschluss zur Selbstprüfung.
7. **Nächste Schritte**  
   Verweise auf verwandte Themen oder „Was kann ich als Nächstes tun?“.

---

## UI-Muster gegen Textwände (SwiftUI-tauglich)
- **Abschnitts-Cards**: Jede Überschrift ist eine Card; Tap öffnet Details.
- **Accordion / Disclosure**: Beispiele, Details, Vertiefungen aufklappbar.
- **Callouts**: „Tipp“, „Achtung“, „Merksatz“ als visuelle Boxen.
- **Lesefortschritt**: Progressbar + „noch X Minuten“.
- **Interaktive Checklisten**: lokal speicherbar, optional synchronisierbar.
- **Quiz als Abschluss**: kleine Belohnung (Badge/Status), optional Streak.

---

## „Wissenspfade“ statt lose Sammlung
Neben Kategorien kann es kuratierte **Wissenspfade** geben (Reihenfolge von Lektionen), z.B.:
- **„Neu bei den PIRATEN“**
- **„Kommunalpolitik – Einstieg“**
- **„Vorstand & Aufgaben“**

Pfad-Idee: Lektionen wie Level (z.B. 1–5), jede Lektion 5–8 Minuten.  
Ergebnis: Orientierung, Motivation und ein klarer Einstieg – ohne Suchstress.

---

## Erwarteter Nutzen für das Projekt
- **Niedrige Einstiegshürde** für neue Piraten
- **Schneller Wissenserwerb** durch kurze, klare Lernschritte
- **Wiederverwendbare Struktur**: Inhalte sind konsistent, wartbar und erweiterbar
- **Gute Nutzererfahrung** auf dem Handy durch „weniger Text auf einmal“

---

## Offene Punkte / nächste Schritte
- Festlegung der **UI-Komponentenbibliothek** für Markdown + Callouts + Quiz.
- Definition der **Frontmatter-Felder**, die die App zwingend benötigt (Titel, Summary, Dauer, Level, Quiz, Related).
- Entscheidung, wie **Fortschritt** gespeichert wird (lokal vs. Account).
