# Doplo for KOReader

## Installing on a Kobo

1. Close KOReader, connect the Kobo via USB and open its storage on your computer.
2. Extract the installation ZIP. Copy the entire `doplo.koplugin` folder to `.adds/koreader/plugins/`. The resulting path is `.adds/koreader/plugins/doplo.koplugin/main.lua`. Enable hidden files in your file manager if you cannot see `.adds`.
3. Eject the Kobo and start KOReader. Open the top menu and choose **Tools → Doplo**. A 5×5 puzzle is ready on first launch. After that, your last game opens automatically.

Doplo is available from the file browser and while reading. If the plugin was previously disabled, enable it under **Tools → More tools → Plugin management**, then restart KOReader. On other touch devices, place the plugin folder in the `plugins` folder of the KOReader installation or its writable profile.

## Playing

Tap a cell, then a digit, **■** or **Erase**. Use **Pencil** to add or remove candidates in an empty cell. A gray cell with a dot in the corner is a given. **Undo** and **Redo** also work for pencil marks.

**Game → New puzzle** lets you choose a variant, size and difficulty. On the **Difficulty** screen, select **Prefilled cells: Off** or **On**. The default is **Off**: every new board starts completely empty at every difficulty level. Your choice is remembered, and existing games are preserved. **Game → Saved puzzles** opens previous games. **Check** checks your entries. **Hint** explains one forced value, which you can enter with **Place value**. **Game → Show solution** shows the solution separately. **Return** takes you back to your own entries.

The enlarged detail cell shows all pencil marks in the selected cell, with its row and column clues alongside. Tap the detail cell or hold a board cell to open the larger input dialog. The whole board stays visible, and the edge clues use larger black digits. **Device settings** opens brightness controls on supported devices, rotates the screen 90° at a time, or requests a full flashing refresh for e-ink ghosting. Rotation keeps your current entries, notes and selection. Page-turn buttons move the board selection one cell backward or forward.

The separate **How to play** button offers guided practice for **Doplo** and **Doplo Plus**, with answer choices, explanations and retries. It does not change your current puzzle. Both **How to play** and **Device settings** remain available while viewing a solution.

Completed puzzles get one of sixteen enthusiastic Dutch compliments. The sequence is remembered across sessions, so messages do not repeat until every compliment has had a turn.

## Rules

| Game | Grid | Blocks per row and column | Digits per row and column |
| --- | --- | --- | --- |
| Doplo | 5×5 / 6×6 / 7×7 / 8×8 | 2 | 1–3 / 1–4 / 1–5 / 1–6 |
| Doplo Plus | 7×7 / 8×8 / 9×9 / 10×10 / 11×11 | 2 / 2 / 3 / 3 / 3 | 1–5 / 1–6 / 1–6 / 1–7 / 1–8 |
| Doplo Plus Extended | 12×12 | 4 | 1–8 |

Each digit appears exactly once in each row and column. In **Doplo**, only digits strictly between the two blocks count toward the sum. For example, `1 ■ 2 3 ■` gives a sum of 5. Two adjacent blocks give 0.

In **Doplo Plus**, each uninterrupted run of digits has a sum, including runs at an edge. Read rows from left to right and columns from top to bottom. The row `1 2 ■ 3 ■ 4 5` gives three clues in this order: **3 · 3 · 9**. Consecutive blocks do not create an extra sum. A line with a single uninterrupted run has one clue. The publisher describes the 7×7 and 10×10 sizes. The other Plus sizes are the plugin's own extensions using the same run rule. Doplo 7×7 and 8×8 extend the classic rule. [Publisher's rules, printed p. 40](https://www.kueng-raetsel.ch/hefte/Taschen-Logik-Mix.pdf#page=13)

All bank puzzles have a unique solution, both with and without givens. Difficulty for empty starts is graded by variant and size; large empty grids may require more searching even on Easy.

## Storage

Doplo saves every change locally. To copy your games, close KOReader and copy `settings/doplo-games/` and `settings/doplo.lua` from the KOReader profile.

Version 1.2.0. AGPL-3.0-or-later. [License](LICENSE) · [Sources](SOURCES.md)
