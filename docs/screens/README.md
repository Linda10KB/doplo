# Photos and screenshots

## Kobo photos

The user-provided photos show Doplo Plus running on a physical Kobo:

| Image | Contents |
| --- | --- |
| [At a desk](kobo-desk.jpg) | A partially filled board with enlarged pencil marks |
| [In low light](kobo-low-light.jpg) | An illuminated screen showing an earlier interface |

The original photos are included without edits. They document use on a device; the automated checks below run in desktop KOReader.

## Screenshots

These images show Doplo 1.2.0 in the official KOReader v2025.10 Linux x86-64 build. They were captured from the actual SDL framebuffer on 2026-11-19 with KOReader's language set to English.

| Image | Resolution | Contents |
| --- | --- | --- |
| [Doplo 5×5](doplo-5x5.png) | 1264×1680 | Empty Easy puzzle with pencil marks in A1 and the enlarged detail cell |
| [Doplo Plus 12×12](doplo-plus-12x12.png) | 1264×1680 | Empty Hard puzzle with the whole board, edge clues and keypad visible |
| [Doplo Plus detail](doplo-plus-detail.png) | 1264×1680 | Pencil marks for a block, 1 and 8 in L12, enlarged below the board |
| [Input dialog](doplo-input-dialog.png) | 1264×1680 | The larger input dialog for L12, with its clues, pencil marks and keypad |
| [Landscape](landscape.png) | 800×600 | The saved 5×5 puzzle reopened with its selection and pencil marks preserved |
| [Device settings](device-settings.png) | 1264×1680 | Brightness, rotation and full refresh in one menu |
| [Doplo practice](tutorial-doplo.png) | 1264×1680 | A standalone practice row with answer buttons |
| [Plus practice](tutorial-plus-feedback.png) | 800×600 | Incorrect-answer feedback and retry in landscape |

The detail-cell image replaces the old `doplo-plus-zoom.png`; the current interface keeps the whole board visible.

## Regenerating the images

Extract the official KOReader Linux build, then run these commands from the repository root. Replace `/path/to/koreader` with the directory containing both `reader.lua` and `luajit`.

```sh
python3 tools/package.py --out /tmp/doplo-release
python3 tools/test_koreader.py /path/to/koreader \
  --zip /tmp/doplo-release/doplo-v1.2.0.koplugin.zip \
  --screens docs/screens
```

The test uses a temporary profile, the SDL dummy video driver and software rendering. It installs the packaged plugin, exercises the real KOReader widgets and saves the PNGs above plus additional rotation, tutorial-completion and success-notification captures. A successful run reports `DOPLO PASS play`, `DOPLO PASS reopen` and `DOPLO PASS reader`.

These are desktop captures. Physical e-ink refresh behavior and hardware controls still require an e-reader test. See the [verification report](../VERIFICATION.md).
