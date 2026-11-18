# Verificatie van versie 1.1.0

Lokaal op macOS met LuaJIT uitgevoerd:

- `luajit tests/engine.lua`: regels, onafhankelijke oplosser voor de oorspronkelijke kleine formaten, alle 960 voorraadpuzzels, live generatie, hints, undo/redo, herstel van speldata en geometrie op vijf schermmaten.
- `luajit tests/ui.lua`: bediening met testdubbels voor KOReader. Controleert zwarte blokken, zichtbare selectie, grote pencil-notities, verversingen, het invoervenster, de startoptie, alle voorraadkeuzes, annulering en terugval bij een timeout.
- De volledige voorraad bevat 12 puzzels voor elk van 80 combinaties. Elke puzzel is afzonderlijk opnieuw opgelost en op uniciteit en niveau gecontroleerd. Lege starts bevatten geen vaste waarden.
- De nieuwe indeling is bekeken via een lokale renderharness. Dit is geen echte KOReader-framebufferopname.
- De installatie-ZIP is opnieuw gebouwd en gecontroleerd op structuur en integriteit.

De native frontlight-aanroep is gecontroleerd tegen de aanwezige KOReader-broncode en de officiële `frontend/ui/widget/frontlightwidget.lua`. De daadwerkelijke helderheidsregeling, e-inkverversing en fysieke bediening moeten nog op de e-reader worden getest. De bijgewerkte native tests `tests/ko_smoke.lua` en `tests/storage.lua` zijn in deze macOS-omgeving niet uitgevoerd; daarvoor is een uitvoerbare KOReader-build nodig.

```sh
luajit tests/engine.lua
luajit tests/ui.lua
python3 tools/package.py --out /tmp/doplo-release
python3 tools/test_koreader.py /path/to/koreader \
  --zip /tmp/doplo-release/doplo-v1.1.0.koplugin.zip \
  --screens /tmp/doplo-screens
```

De volgende resultaten en de bestaande afbeeldingen in `docs/screens/` horen bij de eerdere versie en tonen dus nog de oude zoomfunctie.

---

# Testverslag voor versie 1.0.0

De release is getest met de officiële Linux x86-64-versies **KOReader v2025.10** en **v2026.07.1**, met de bijbehorende LuaJIT, KOReader-widgets en SDL. De installatietest pakt de uiteindelijke ZIP uit in een nieuw profiel en start het ongewijzigde programma. De testcode bevindt zich alleen in de bronrepository. [KOReader v2025.10](https://github.com/koreader/koreader/releases/tag/v2025.10) · [KOReader v2026.07.1](https://github.com/koreader/koreader/releases/tag/v2026.07.1)

## Resultaten

| Onderdeel | Bereik | Resultaat |
| --- | --- | --- |
| Puzzelengine | 15 testgroepen voor model, oplosser, hints, geschiedenis, generator en schermindeling | Geslaagd |
| Klassieke regels | Beide voorbeeldsommen, buitenliggende cijfers, aangrenzende blokken, duplicaten, vaste waarden en tegenstrijdige rij- of kolomregels | Geslaagd |
| Plus-regels | Geordende groepen, randgroepen, herhaalde groepssommen, aangrenzende kruisjes, onmogelijke aanwijzingen en vier kruisjes in 12×12 | Geslaagd |
| Onafhankelijke lijncontrole | Permutatie-enumeratie tegenover de productieanalyse. Alle voorkomende aanwijzingen bij 5×5, 6×6 en 7×7, met volledige en beperkte celkeuzes | Geslaagd |
| Onafhankelijke bordcontrole | Een tweede oplosser bouwt complete rijen en controleert kolomvoorvoegsels. Alle 48 klassieke 5×5- en 48 Plus 7×7-voorraadpuzzels hebben één oplossing. Ook 60 extra klassieke invoeren zijn vergeleken, met nul, één of meerdere oplossingen | Geslaagd |
| Hele voorraad | Alle 240 puzzels opnieuw opgelost. Voor elk bord zijn de unieke oplossing, vaste waarden, regels en het toegewezen niveau gecontroleerd | Geslaagd |
| Genereren | Een verse, uniek oplosbare puzzel voor elk van de twintig formaat-niveaucombinaties. Een afgebroken zoektocht kan geen certificaat van uniciteit opleveren | Geslaagd |
| Hints | Gedwongen waarden tot en met de laatste zet, tegenstrijdige invoer, voltooid bord en bewijs door uitsluiting tegen een tweede oplosser | Geslaagd |
| Opslag | Vier bestandstests met KOReader-JSON en de echte bestandssysteemfuncties. Herstart, eigen spelgeschiedenis, truncatie, onbekend schema, achtergebleven tijdelijk bestand en herstel na een mislukte schrijfactie | Geslaagd op beide versies |
| Spelen via KOReader | Tik op Doplo in het getekende Tools-menu. Invoer, kruisjes, wissen, notities, undo/redo, **Check**, hint toepassen, oplossing bekijken en terugkeren. Ook grote invoer, sectiezoom, logische bladerknoppen, annulering, timeout, voorraadkeuze, echte nieuwe generatie en uitspelen via tikken | Geslaagd op beide versies |
| Hervatten en toegang vanuit een boek | Sluit het spel en het programma. Start KOReader opnieuw in liggende stand en hervat dezelfde puzzel, selectie en notities. Open de plugin ook in een geopend tekstboek en keer terug naar dat boek | Geslaagd op beide versies |
| Beeld | 1264×1680 staand, 800×600 liggend en 600×800 in de lezer. Ook rechtstreeks tekenen in een 8-bits grijswaardenbuffer. De geometrische tests omvatten vijf schermmaten, waaronder 320×480 | Geslaagd |

## Zelf uitvoeren

De enginetests gebruiken LuaJIT 2.1, inclusief de ingebouwde `bit`-module. De desktopproeven hebben Python 3 en een uitgepakte officiële KOReader Linux-build nodig. Gebruik als argument de map waarin **zowel** `reader.lua` als `luajit` staan. Start in de hoofdmap van de repository.

```sh
luajit tests/engine.lua
python3 tools/package.py --out /tmp/doplo-release
python3 tools/test_koreader.py /path/to/koreader \
  --zip /tmp/doplo-release/doplo-v1.0.0.koplugin.zip \
  --screens /tmp/doplo-screens
```

Je kunt het eerste commando ook met `/path/to/koreader/luajit` uitvoeren. De desktoptest gebruikt een tijdelijk KOReader-profiel en boot drie afzonderlijke processen. Een geslaagde uitvoering eindigt met `DOPLO PASS play`, `DOPLO PASS reopen` en `DOPLO PASS reader`. De optie `--screens` bewaart de echte framebufferbeelden uit die uitvoering.

Met `luajit tools/build_bank.lua > /tmp/doplo-bank.lua` bouw je de gecontroleerde voorraad opnieuw. De vaste seeds maken de uitvoer reproduceerbaar. Je kunt het resultaat vergelijken met `doplo.koplugin/doplo/bank.lua`.

## Hardware en grenzen

Een fysieke Kobo Libra Colour was hier niet beschikbaar. De schermopnamen komen uit de desktopversie. Ze laten de echte componenten en geometrie zien. Ghosting, reactietijd van een fysiek Kaleido-paneel, aanraking aan de schermrand, slaapstand via de aan-uitknop en de feitelijke werking van de twee bladerknoppen vragen een apparaattest. De automatische test stuurt de logische KOReader-toetsgebeurtenissen en roept de opslag bij slaapstand aan.

De solver ondersteunt acht verschillende cijfers en de blokwaarde. De interface biedt de vijf geteste formaten. Een hint heeft een rekenlimiet en een tijdslimiet van ongeveer zeven seconden. Zodra een van beide bereikt is, meldt de plugin dat het bewijs niet binnen de limiet is gevonden. Tijden op de Kobo zijn niet gemeten.
