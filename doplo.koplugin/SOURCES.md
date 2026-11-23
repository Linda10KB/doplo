# Sources and license

The plugin's Lua implementation, tests, puzzle bank and documentation are licensed under **AGPL-3.0-or-later**. Copyright © 2026 Doplo plugin contributors. The bundled license text is the unmodified GNU AGPL version 3. Screenshots in the source project show KOReader running this plugin. [License text](LICENSE)

## Game rules

Küng / Keesing Schweiz describes the classic game in *Doplo Anleitung*. Issue 1 of *Logik-Rätsel für unterwegs* includes the Plus rules and examples on printed page 40. Printed page numbers differ from PDF page numbers. The plugin uses independently generated grids. [Classic rules](https://www.kueng-raetsel.ch/anleitungen/) · [Doplo Plus, PDF page 13](https://www.kueng-raetsel.ch/hefte/Taschen-Logik-Mix.pdf#page=13)

## Software consulted

| Project | License of the consulted source | How it was used |
| --- | --- | --- |
| Sjlver/rublock | MIT | The workflow of creating a valid grid, deriving its clues and checking uniqueness. Constraint propagation and search-step counting were studied as algorithmic references. The Lua solver uses its own line algorithm for both game variants. [Generator](https://github.com/Sjlver/rublock/blob/abbeada0a2f85c1b236e88ad8948b5f436d2a360/src/bin/gen_puzzle.rs) · [Solver](https://github.com/Sjlver/rublock/blob/abbeada0a2f85c1b236e88ad8948b5f436d2a360/src/queue_solver.rs) |
| SmilingWayne/puzzlekit | MIT | The Skyscraper solver's constraint model illustrates edge constraints on a Latin square. Its separate dataset catalog lists DoppelBlock. This release contains its own puzzles and runs without OR-Tools or Python. [Solver](https://github.com/SmilingWayne/puzzlekit/blob/9ef8ebbb262039401d72e37af0d23f9c9b46a5b0/src/puzzlekit/solvers/skyscraper.py) · [Dataset catalog](https://github.com/SmilingWayne/puzzlekit-dataset) |
| koreader/koreader | AGPL-3.0 | The installed KOReader runtime provides the plugin loader, menu registration, InputContainer, GestureRange, TextWidget, ButtonDialog, framebuffer, timer, settings, sleep-screen rendering and filesystem functions. The installation ZIP contains only the plugin. [Plugin loader](https://github.com/koreader/koreader/blob/v2026.07.1/frontend/pluginloader.lua) · [InputContainer](https://github.com/koreader/koreader/blob/v2026.07.1/frontend/ui/widget/container/inputcontainer.lua) · [Kobo device definitions](https://github.com/koreader/koreader/blob/v2026.07.1/frontend/device/kobo/device.lua) · [Sleep screen lifecycle](https://github.com/koreader/koreader/blob/v2025.10/frontend/ui/screensaver.lua) |
| koreader/contrib | AGPL-3.0 for the collection. Submodules have their own licenses. | The catalog shows standalone plugin folders for games including 2048, Solitaire and Sudoku. [Catalog](https://github.com/koreader/contrib/tree/5ed759ec8f59435ae722e8c0d2dadc1171930358) |
| omer-faruq/nonogram.koplugin | GPL-3.0 | A reference for launching a game from the Tools menu, tap gesture ranges, targeted e-ink refreshes and separate game storage. Doplo has its own board controls and separate JSON storage per puzzle. [Implementation](https://github.com/omer-faruq/nonogram.koplugin/blob/f4d44bc05b17b3649dfdb078b0b91081aaa9afcb/main.lua) · [License](https://github.com/omer-faruq/nonogram.koplugin/blob/f4d44bc05b17b3649dfdb078b0b91081aaa9afcb/LICENSE) |
| robx/pzprjs | MIT | An additional check of the classic definition in an existing player, including counts, duplicates and sum validation. [Doppelblock](https://github.com/robx/pzprjs/blob/028ca1e6115fc8009eed67c0dbb6c01f8a56aaad/src/variety/doppelblock.js) |
| semiexp/cspuz_core | MIT for the consulted puzzle code. The repository lists additional licenses for SAT components. | A second formulation of the classic edge constraint using cells with a block on either side. [Doppelblock model](https://github.com/semiexp/cspuz_core/blob/2fba19520bcebf7908ef0ce8c319f0b20cac8969/cspuz_rs_puzzles/src/puzzles/doppelblock.rs) · [Licenses](https://github.com/semiexp/cspuz_core/blob/2fba19520bcebf7908ef0ce8c319f0b20cac8969/LICENSE) |

Reuse is limited to API calls and algorithmic ideas. No source code from the consulted puzzle implementations was copied or translated, and no puzzles were taken from publisher material or datasets. KOReader provides fonts and text rendering on the device.

## Sleep cover

The bundled `resources/doplo-cover.png` is original artwork generated with OpenAI's built-in image generation tool on 2026-11-23, from the user's requested rainbow-gradient Doplo cover and playful review stickers. Its review text is fictional. The source repository records the prompt in `docs/cover-prompt.txt`.
