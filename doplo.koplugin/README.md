# Doplo voor KOReader

## Installeren op een Kobo

1. Sluit KOReader af, sluit de Kobo via USB aan en open de opslag op je computer.
2. Pak de installatie-ZIP uit. Kopieer de hele map `doplo.koplugin` naar `.adds/koreader/plugins/`. Het resultaat is `.adds/koreader/plugins/doplo.koplugin/main.lua`. Zet de weergave van verborgen bestanden aan als je `.adds` niet ziet.
3. Werp de Kobo uit en start KOReader. Open het bovenmenu en kies **Tools → Doplo**. Op de eerste start staat een 5×5-puzzel klaar. Daarna opent je laatst gespeelde puzzel.

Doplo is beschikbaar vanuit de bestandsbrowser en tijdens het lezen. Een eerder uitgeschakelde plugin kun je weer aanzetten onder **Tools → More tools → Plugin management**. Herstart daarna KOReader. Op andere touchapparaten hoort de pluginmap in de `plugins`-map van de KOReader-installatie of het schrijfbare KOReader-profiel.

## Spelen

Tik op een vak en vervolgens op een cijfer, **×** of **Erase**. Met **Pencil** zet of verwijder je kandidaten in een leeg vak. Een grijs vak met een stip in de hoek is een vaste aanwijzing. **Undo** en **Redo** werken ook voor potloodnotities.

**Game → New puzzle** laat je variant, formaat en moeilijkheid kiezen. **Game → Saved puzzles** opent eerdere spellen. **Check** controleert je invoer. **Hint** licht één gedwongen waarde toe. Met **Place value** kun je die invullen. **Game → Show solution** toont de oplossing apart. Met **Return** kom je terug bij je eigen invulling.

Houd een vak ingedrukt voor een groter invoervenster met beide reeksaanwijzingen. Bij Doplo Plus kun je met **View** een deel van het bord vergroten. De randaanwijzingen blijven voor de hele rij of kolom gelden. De bladerknoppen verplaatsen op het spelbord de selectie één vak terug of vooruit.

## Regels

| Spel | Rooster | Kruisjes per rij en kolom | Cijfers per rij en kolom |
| --- | --- | --- | --- |
| Doplo | 5×5 / 6×6 | 2 | 1–3 / 1–4 |
| Doplo Plus | 7×7 / 10×10 | 2 / 3 | 1–5 / 1–7 |
| Doplo Plus Extended | 12×12 | 4 | 1–8 |

Elk cijfer komt per rij en per kolom precies één keer voor. Bij **Doplo** telt alleen wat strikt tussen de twee kruisjes staat. Zo geeft `1 × 2 3 ×` de som 5. Twee kruisjes naast elkaar geven 0.

Bij **Doplo Plus** krijgt elke aaneengesloten groep cijfers een som, ook aan de rand. Lees rijen van links naar rechts en kolommen van boven naar beneden. De rij `1 2 × 3 × 4 5` geeft drie aanwijzingen, in de volgorde **3 · 3 · 9**. Opeenvolgende kruisjes creëren geen extra som. In een lijn met één aaneengesloten groep staat één aanwijzing. De uitgever beschrijft de formaten 7×7 en 10×10. Het formaat 12×12 past dezelfde regel toe op vier kruisjes. [Uitgeversregels, gedrukte p. 40](https://www.kueng-raetsel.ch/hefte/Taschen-Logik-Mix.pdf#page=13)

## Opslag

Doplo bewaart elke wijziging lokaal. Om je spellen te kopiëren maak je, met KOReader afgesloten, een kopie van `settings/doplo-games/` en `settings/doplo.lua` uit het KOReader-profiel. De Nederlandse handleiding gebruikt de Engelse knopnamen die je in de plugin ziet.

Versie 1.0.0. AGPL-3.0-or-later. [Licentie](LICENSE) · [Herkomst](SOURCES.md)
