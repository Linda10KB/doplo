# Version 1.1.0 verification

## Documentation and screenshot refresh — 2026-11-18

Rechecked on Linux x86-64 using the official **KOReader v2025.10** build and its bundled LuaJIT:

- All 17 engine test groups passed, including checks of all 960 bank puzzles.
- All five UI test groups passed, including a regression check that an unset starting-mode preference produces empty puzzles for both bank selection and live generation.
- All four native storage tests passed.
- The installation ZIP passed its structure and integrity checks. The native installation test passed all three phases: `DOPLO PASS play`, `DOPLO PASS reopen` and `DOPLO PASS reader`.
- Five fresh framebuffer screenshots were captured and visually inspected. They show the current full-board interface, enlarged detail cell and larger input dialog. The obsolete section-zoom image was replaced with `doplo-plus-detail.png`. [Screenshots and reproduction instructions](screens/README.md)

The native run exposed a missing-preference bug: KOReader returns `nil` for an unset boolean setting, even when `false` is supplied as its default. The plugin now explicitly interprets only `true` as enabling prefilled cells, so empty puzzles retain the correct starting mode and difficulty rating.

## Initial verification

The initial checks were run locally on macOS with LuaJIT:

- `luajit tests/engine.lua`: rules, an independent solver for the original small sizes, all 960 bank puzzles, live generation, hints, undo/redo, saved-game recovery and geometry at five screen sizes.
- `luajit tests/ui.lua`: controls using KOReader test doubles. Checks solid blocks, visible selection, enlarged pencil marks, refreshes, the input dialog, the starting mode, all bank choices, cancellation and timeout fallback.
- The full bank contains 12 puzzles for each of 80 combinations. Every puzzle was independently solved again and checked for uniqueness and difficulty. Empty starts contain no givens.
- The new layout was inspected using a local rendering harness. That preview was not a real KOReader framebuffer capture.
- The installation ZIP was rebuilt and checked for structure and integrity.

The native frontlight call was checked against the available KOReader source and the official `frontend/ui/widget/frontlightwidget.lua`. Actual brightness adjustment, e-ink refresh behavior and physical controls still need testing on an e-reader. The updated native tests, `tests/ko_smoke.lua` and `tests/storage.lua`, were not run in that macOS environment; they require an executable KOReader build.

```sh
luajit tests/engine.lua
luajit tests/ui.lua
python3 tools/package.py --out /tmp/doplo-release
python3 tools/test_koreader.py /path/to/koreader \
  --zip /tmp/doplo-release/doplo-v1.1.0.koplugin.zip \
  --screens /tmp/doplo-screens
```

The following report records the results for the previous release, including its former section zoom feature.

---

# Version 1.0.0 test report

The release was tested with the official Linux x86-64 builds of **KOReader v2025.10** and **v2026.07.1**, using their bundled LuaJIT, KOReader widgets and SDL. The installation test extracts the final ZIP into a fresh profile and starts the unmodified application. Test code is included only in the source repository. [KOReader v2025.10](https://github.com/koreader/koreader/releases/tag/v2025.10) · [KOReader v2026.07.1](https://github.com/koreader/koreader/releases/tag/v2026.07.1)

## Results

| Component | Coverage | Result |
| --- | --- | --- |
| Puzzle engine | 15 test groups covering the model, solver, hints, history, generator and screen layout | Passed |
| Classic rules | Both example sums, digits outside the blocks, adjacent blocks, duplicates, givens and conflicting row or column rules | Passed |
| Plus rules | Ordered runs, edge runs, repeated run sums, adjacent blocks, impossible clues and four blocks in 12×12 | Passed |
| Independent line checks | Permutation enumeration compared with the production analysis. Every occurring clue at 5×5, 6×6 and 7×7, with both full and restricted cell domains | Passed |
| Independent board checks | A second solver builds complete rows and checks column prefixes. All 48 classic 5×5 and 48 Plus 7×7 bank puzzles have one solution. Another 60 classic inputs were compared, with zero, one or multiple solutions | Passed |
| Full bank | All 240 puzzles solved again. Each board was checked for its unique solution, givens, rules and assigned difficulty | Passed |
| Generation | A fresh, uniquely solvable puzzle for each of the twenty size/difficulty combinations. An interrupted search cannot certify uniqueness | Passed |
| Hints | Forced values through the final move, conflicting entries, a completed board and proof by elimination checked against a second solver | Passed |
| Storage | Four file tests using KOReader JSON and real filesystem functions. Restart, separate game histories, truncation, unknown schema, an abandoned temporary file and recovery after a failed write | Passed on both versions |
| Playing through KOReader | Tap Doplo in the rendered Tools menu. Enter digits and blocks, erase, add notes, undo/redo, **Check**, apply a hint, view the solution and return. Also larger input, section zoom, logical page-turn events, cancellation, timeout, bank selection, live generation and completing a puzzle through taps | Passed on both versions |
| Resuming and opening from a book | Close the game and application. Restart KOReader in landscape and resume the same puzzle, selection and notes. Also open the plugin while reading a text file and return to that book | Passed on both versions |
| Rendering | 1264×1680 portrait, 800×600 landscape and 600×800 in the reader. Also direct rendering to an 8-bit grayscale buffer. Geometry tests cover five screen sizes, including 320×480 | Passed |

## Running the tests yourself

The engine tests use LuaJIT 2.1, including its built-in `bit` module. Desktop tests require Python 3 and an extracted official KOReader Linux build. Pass the directory containing **both** `reader.lua` and `luajit`. To reproduce this archived report, run the commands below from the repository root at tag `v1.0.0`. For the current version, use the 1.1.0 commands above.

```sh
luajit tests/engine.lua
python3 tools/package.py --out /tmp/doplo-release
python3 tools/test_koreader.py /path/to/koreader \
  --zip /tmp/doplo-release/doplo-v1.0.0.koplugin.zip \
  --screens /tmp/doplo-screens
```

You can also run the first command with `/path/to/koreader/luajit`. The desktop test uses a temporary KOReader profile and starts three separate processes. A successful run ends with `DOPLO PASS play`, `DOPLO PASS reopen` and `DOPLO PASS reader`. The `--screens` option saves actual framebuffer images from that run.

Rebuild the verified bank with `luajit tools/build_bank.lua > /tmp/doplo-bank.lua`. Fixed seeds make the output reproducible. Compare the result with `doplo.koplugin/doplo/bank.lua`.

## Hardware and limitations

A physical Kobo Libra Colour was not available. The screenshots were captured using the desktop build and show the real components and geometry. Ghosting, response time on a physical Kaleido panel, taps at the screen edge, suspension using the power button and the actual behavior of the two page-turn buttons require device testing. The automated test sends logical KOReader key events and invokes saving on suspend.

The solver supports eight distinct digits and the block value. Version 1.0.0's interface offered the five tested sizes. A hint has a work limit and a time limit of approximately seven seconds. When either limit is reached, the plugin reports that it could not complete the proof within the limit. Timings on a Kobo have not been measured.
