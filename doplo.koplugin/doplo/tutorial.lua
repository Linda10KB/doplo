-- SPDX-License-Identifier: AGPL-3.0-or-later
local Game = require("doplo/game")
local Model = require("doplo/model")
local Tutorial = {}

-- Each lesson completes one valid board. Its state is deliberately separate
-- from the player's game and is never handed to the save store.
local lessons = {
    classic = {
        solution = {
            0, 1, 2, 3, 0,
            3, 0, 1, 2, 0,
            2, 0, 0, 1, 3,
            1, 3, 0, 0, 2,
            0, 2, 3, 0, 1,
        },
        steps = {
            {
                cell = 3, axis = "row", title = "Every digit once",
                instruction = "Every row and column needs two blocks and the digits 1–3 once each. Row 1 already has 1 and 3. Fill the missing digit in C1.",
                retry = "Look along row 1: 1 and 3 are already there. Which digit is missing?",
                explanation = "Exactly: 2 completes the digits 1–3. The two black squares are blocks, not zeroes to add.",
            },
            {
                cell = 6, axis = "row", title = "Between the blocks",
                instruction = "The clue 3 beside row 2 adds only digits BETWEEN its blocks: 1 + 2. A2 is outside them. Fill A2 with the digit missing from this row.",
                retry = "The edge clue ignores A2, but the row still needs all of 1, 2 and 3.",
                explanation = "Yes: A2 is 3. It belongs in the row, but does not count toward the clue. Only 1 + 2 between the blocks counts.",
            },
            {
                cell = 13, axis = "row", title = "A clue of zero",
                instruction = "Row 3 has clue 0: nothing can lie between its blocks. One block is at B3. Fill C3 so the blocks touch. Tap the solid-square key to place a block.",
                retry = "The row already contains 1, 2 and 3. Its second block must touch B3 to leave an empty gap.",
                explanation = "Right: the blocks at B3 and C3 touch. No digits lie between them, so the clue is 0.",
            },
            {
                cell = 22, axis = "row", title = "Use the edge clue",
                instruction = "Row 5 has clue 5. Between its blocks are B5 and the digit 3. What belongs in B5 so those two digits add to 5? Fill it in the board.",
                retry = "Only B5 and 3 lie between the blocks. Their sum must be 5.",
                explanation = "Correct: 2 + 3 = 5. The 1 at the far right is outside the blocks and does not count.",
            },
            {
                cell = 19, axis = "col", title = "Look down a column",
                instruction = "The same rules work downward. Column D already contains 3, 2, 1 and one block. Fill D4 with what this column still needs.",
                retry = "Column D has all three digits. Every column also needs two blocks.",
                explanation = "That is the second block. D4 and D5 touch, matching the 0 clue above column D.",
            },
            {
                cell = 16, axis = "row", title = "Finish your puzzle",
                instruction = "One square remains. Row 4 contains two blocks and the digits 3 and 2. Fill A4 with its missing digit. Then every row AND column will obey the rules.",
                retry = "Row 4 has 2 and 3. Which digit from 1–3 is missing?",
                explanation = "You completed the whole board! Every row and column has two blocks, each digit once, and the correct sum between the blocks.",
            },
        },
    },
    plus = {
        solution = {
            1, 2, 0, 3, 0, 4, 5,
            5, 1, 2, 0, 3, 0, 4,
            4, 5, 1, 2, 0, 3, 0,
            0, 4, 5, 1, 2, 0, 3,
            0, 3, 0, 4, 5, 1, 2,
            3, 0, 4, 5, 1, 2, 0,
            2, 0, 3, 0, 4, 5, 1,
        },
        steps = {
            {
                cell = 11, axis = "row", title = "Digits and blocks",
                instruction = "In this 7×7 puzzle each row and column needs two blocks and the digits 1–5 once each. Row 2 has all five digits and one block. Fill D2 with its second block.",
                retry = "Row 2 already has 1, 2, 3, 4 and 5. Tap the solid-square key to add the other block.",
                explanation = "Exactly. Blocks separate the runs of digits. Plus gives a separate sum for each uninterrupted run.",
            },
            {
                cell = 2, axis = "row", title = "The first run",
                instruction = "Read row 1's clues left to right: 3 · 3 · 9. The FIRST run is 1 and B1, before the first block. Fill B1 so this run adds to the first clue, 3.",
                retry = "The first run ends at C1's block. Add 1 and the value in B1 to make 3.",
                explanation = "Yes: 1 + 2 = 3. The next run is just the digit 3, matching the middle clue. Keep the clues in reading order.",
            },
            {
                cell = 7, axis = "row", title = "The last run",
                instruction = "Now look at row 1's LAST clue, 9. After the second block, its last run is 4 and G1. Fill G1 so that run adds to 9.",
                retry = "Use the last clue for the last run: 4 plus the missing digit must be 9.",
                explanation = "Correct: 4 + 5 = 9. Row 1 now has runs 1 + 2, then 3, then 4 + 5: clues 3 · 3 · 9.",
            },
            {
                cell = 18, axis = "row", title = "Runs at an edge count",
                instruction = "Row 3's clues are 12 · 3. Its first run starts at the left edge: 4 + 5 + 1 + D3. Fill D3 to reach 12. A run needs no block at the outer edge.",
                retry = "The first three digits total 10. Add the missing digit to reach the first clue, 12.",
                explanation = "Right: 4 + 5 + 1 + 2 = 12. The other run is 3. The block at the far right adds no extra clue.",
            },
            {
                cell = 29, axis = "col", title = "Touching blocks",
                instruction = "Column A has all five digits and one block at A4. Fill A5 with its other block. Read the column's clues downward: 10 · 5. Empty gaps never get a clue.",
                retry = "Column A has 1, 5, 4, a block, an empty square, 3 and 2. It needs a second block.",
                explanation = "The blocks touch. The runs are 1 + 5 + 4 = 10 and 3 + 2 = 5. There is no zero clue for the empty gap.",
            },
            {
                cell = 44, axis = "row", title = "Separate the runs",
                instruction = "Row 7 has clues 2 · 3 · 10. Its first two runs must be the single digits 2 and 3. Fill B7 to separate them, before the existing block at D7.",
                retry = "A block splits the 2 and the 3 into separate runs. All five digits are already in this row.",
                explanation = "Yes: the blocks make runs 2, then 3, then 4 + 5 + 1. These match the clues 2 · 3 · 10.",
            },
            {
                cell = 40, axis = "col", title = "Finish down a column",
                instruction = "Column E has clues 3 · 12. Below its second block, the last run is 2 + 5 + E6 + 4. Fill E6 so the run adds to 12 and completes your puzzle.",
                retry = "The known digits in this last run total 11. Which digit brings that to 12?",
                explanation = "You did it: 2 + 5 + 1 + 4 = 12. Every row and column now matches its runs, in order. Larger Plus boards can have more blocks and digits.",
            },
        },
    },
}

local Practice = {}
Practice.__index = Practice

function Tutorial.new(kind)
    local lesson = assert(lessons[kind], "Unknown tutorial variant")
    local practice = setmetatable({ kind = kind, lesson = lesson }, Practice)
    practice:restart()
    return practice
end

function Practice:restart()
    local size = self.kind == "classic" and 5 or 7
    local givens = Model.copy(self.lesson.solution)
    for _, step in ipairs(self.lesson.steps) do
        givens[step.cell] = -1
    end
    local puzzle = Model.puzzle(Model.config(self.kind, size), self.lesson.solution, givens)
    puzzle.level = "Easy"
    self.game = Game.new(puzzle)
    self.step = 1
    self.complete = false
    self:beginStep()
end

function Practice:current()
    return self.lesson.steps[self.step]
end

function Practice:beginStep()
    self.game.selected = self:current().cell
    self.accepted = false
    self.feedback = nil
end

function Practice:input(value)
    if self.complete or self.accepted then
        return false
    end
    local cell = self:current().cell
    if value ~= self.game.p.solution[cell] then
        self.feedback = "Try again. " .. self:current().retry
        return false
    end
    self.game:edit(cell, value, false)
    self.accepted = true
    self.feedback = self:current().explanation
    return true
end

function Practice:advance()
    if not self.accepted or self.complete then
        return false
    end
    if self.step == #self.lesson.steps then
        self.complete = true
        return true
    end
    self.step = self.step + 1
    self:beginStep()
    return true
end

function Practice:back()
    if self.complete then
        self.complete = false
        return
    end
    local previousStep = math.max(1, self.step - 1)
    -- Rebuild only this disposable exercise; saved games are never involved.
    self:restart()
    while self.step < previousStep do
        self:input(self.game.p.solution[self:current().cell])
        self:advance()
    end
end

function Tutorial.show(screen)
    screen:choose("How to play\n\nFill a real practice puzzle, one guided step at a time. Your own puzzle stays as it is.", {
        {
            { "Doplo", function()
                require("doplo/tutorial_screen").show(screen, Tutorial.new("classic"))
            end },
            { "Doplo Plus", function()
                require("doplo/tutorial_screen").show(screen, Tutorial.new("plus"))
            end },
        },
        { { "Back to puzzle" } },
    })
end

return Tutorial
