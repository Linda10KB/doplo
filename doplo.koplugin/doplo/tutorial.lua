-- SPDX-License-Identifier: AGPL-3.0-or-later
local Tutorial = {}

-- Practice uses its own small examples, never the player's current board.
local lessons = {
    classic = {
        name = "Doplo",
        exercises = {
            {
                prompt = "On a 5 × 5 board, every row and column has two blocks and the digits 1–3 once each."
                    .. "\n\n■   1   ?   3   ■\n\nWhich digit is missing?",
                choices = { "1", "2", "3" },
                answer = "2",
                explanation = "The missing digit is 2."
                    .. " Each digit appears exactly once in every row and column.",
                retry = "1 and 3 are already in this row. Each digit appears once.",
            },
            {
                prompt = "Only digits between the two blocks count toward the edge clue."
                    .. "\n\n1   ■   2   3   ■\n\nWhat is this row's clue?",
                choices = { "1", "5", "6" },
                answer = "5",
                explanation = "2 + 3 = 5."
                    .. " The 1 is outside the blocks, so it does not count toward the sum.",
                retry = "Start after the first block and stop at the second.",
            },
            {
                prompt = "The same rule works down a column. What if the blocks touch?"
                    .. "\n\n1   ■   ■   2   3\n\nWhat is this row's clue?",
                choices = { "0", "3", "6" },
                answer = "0",
                explanation = "There are no digits between the blocks, so the clue is 0."
                    .. " Larger Doplo boards still use two blocks, with more digits.",
                retry = "Count only digits strictly between the blocks.",
            },
        },
    },
    plus = {
        name = "Doplo Plus",
        exercises = {
            {
                prompt = "On a 7 × 7 board, every row and column has two blocks and the digits 1–5 once each."
                    .. "\n\n1   2   ■   3   ■   4   ?\n\nWhich digit is missing?",
                choices = { "3", "5", "■" },
                answer = "5",
                explanation = "The missing digit is 5."
                    .. " The row already has two blocks and each of the other digits.",
                retry = "There are already two blocks, and the digits 1–4.",
            },
            {
                prompt = "Each uninterrupted run of digits has its own sum."
                    .. " Read rows left to right; columns top to bottom."
                    .. "\n\n1   2   ■   3   ■   4   5\n\nWhich clues match, in order?",
                choices = { "3 · 3 · 9", "9 · 3 · 3", "15" },
                answer = "3 · 3 · 9",
                explanation = "The runs are 1 + 2, then 3, then 4 + 5."
                    .. " Their clues are 3 · 3 · 9, in that order.",
                retry = "Blocks split the runs. Keep the sums in reading order.",
            },
            {
                prompt = "Runs touching an edge count too."
                    .. "\n\n■   1   2   ■   3   4   5\n\nWhich clues match this row?",
                choices = { "3", "3 · 12", "0 · 3 · 12" },
                answer = "3 · 12",
                explanation = "1 + 2 = 3 and 3 + 4 + 5 = 12. The run at the right edge counts."
                    .. " A block at the left edge adds no clue.",
                retry = "Count both runs of digits, including the one at the edge.",
            },
            {
                prompt = "Touching blocks do not create an extra run."
                    .. "\n\n■   ■   2   1   5   4   3\n\nWhich clues match this row?",
                choices = { "0 · 15", "15", "0 · 0 · 15" },
                answer = "15",
                explanation = "All five digits form one run: 2 + 1 + 5 + 4 + 3 = 15."
                    .. " There are no zero clues for empty gaps."
                    .. " Larger Plus sizes can use more blocks and digits.",
                retry = "Only runs containing digits get a clue.",
            },
        },
    },
}

local Practice = {}
Practice.__index = Practice

function Practice:new(screen, kind)
    return setmetatable({ screen = screen, lesson = lessons[kind] }, self)
end

function Practice:navigation(step)
    return {
        {
            "Back",
            function()
                if step == 1 then
                    Tutorial.show(self.screen)
                    return
                end
                self:showExercise(step - 1)
            end,
        },
        { "Back to puzzle" },
    }
end

function Practice:showExercise(step, feedback)
    local exercise = self.lesson.exercises[step]
    local title = ("%s · Practice %d/%d\n\n%s"):format(
        self.lesson.name,
        step,
        #self.lesson.exercises,
        exercise.prompt
    )
    if feedback then
        title = title .. "\n\nNot quite. " .. exercise.retry
    end

    local answers = {}
    for _, choice in ipairs(exercise.choices) do
        answers[#answers + 1] = {
            choice,
            function()
                if choice ~= exercise.answer then
                    self:showExercise(step, true)
                    return
                end
                self:showAnswer(step)
            end,
        }
    end

    self.screen:choose(title, { answers, self:navigation(step) })
end

function Practice:showAnswer(step)
    local exercise = self.lesson.exercises[step]
    local isLastExercise = step == #self.lesson.exercises
    local title = ("%s · Correct!\n\n%s"):format(self.lesson.name, exercise.explanation)

    self.screen:choose(title, {
        {
            {
                "Try again",
                function()
                    self:showExercise(step)
                end,
            },
            {
                isLastExercise and "Controls" or "Next",
                function()
                    if isLastExercise then
                        self:showControls()
                        return
                    end
                    self:showExercise(step + 1)
                end,
            },
        },
        { { "Back to puzzle" } },
    })
end

function Practice:showControls()
    local title = self.lesson.name
        .. " · Practice complete\n\n"
        .. "Rows AND columns must obey the rules.\n\n"
        .. "Tap a cell, then a digit or ■.\n"
        .. "Pencil toggles candidates; Erase clears.\n"
        .. "Hold a cell for the larger keypad.\n"
        .. "A dotted cell is fixed. Undo takes a move back.\n"
        .. "Use Check or Hint when you need help."

    self.screen:choose(title, {
        {
            {
                "Practice again",
                function()
                    self:showExercise(1)
                end,
            },
            {
                "Other game",
                function()
                    Tutorial.show(self.screen)
                end,
            },
        },
        { { "Back to puzzle" } },
    })
end

function Tutorial.show(screen)
    screen:choose("How to play\n\nChoose a guided practice. Your puzzle stays as it is.", {
        {
            {
                "Doplo",
                function()
                    Practice:new(screen, "classic"):showExercise(1)
                end,
            },
            {
                "Doplo Plus",
                function()
                    Practice:new(screen, "plus"):showExercise(1)
                end,
            },
        },
        { { "Back to puzzle" } },
    })
end

return Tutorial
