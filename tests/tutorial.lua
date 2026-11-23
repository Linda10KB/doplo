-- Run from the repository root with LuaJIT 2.1.
package.path = "doplo.koplugin/?.lua;" .. package.path
local Tutorial = require("doplo/tutorial")
local Model = require("doplo/model")
local Layout = require("doplo/layout")
local TutorialLayout = require("doplo/tutorial_layout")

local function complete(practice)
    for index, step in ipairs(practice.lesson.steps) do
        assert(practice.step == index)
        assert(practice.game.selected == step.cell)
        assert(practice.game.board[step.cell] == -1)
        assert(not practice:advance(), "Cannot skip an unfilled square")
        local correct = practice.game.p.solution[step.cell]
        local incorrect = (correct + 1) % (practice.game.p.n - practice.game.p.blocks + 1)
        assert(not practice:input(incorrect))
        assert(practice.feedback:find("Try again.", 1, true))
        assert(practice.game.board[step.cell] == -1, "Wrong values must not enter the board")
        assert(practice:input(correct))
        assert(practice.game.board[step.cell] == correct)
        assert(practice.accepted and practice.feedback == step.explanation)
        assert(not practice:input(incorrect), "Completed steps cannot be changed")
        assert(practice:advance())
    end
    assert(practice.complete and practice.game:solved())
    assert(not practice:advance() and not practice:input(1))
end

for _, kind in ipairs({ "classic", "plus" }) do
    local practice = Tutorial.new(kind)
    assert(Model.validPuzzle(practice.game.p))
    local initialBoard = Model.copy(practice.game.board)
    local secondPractice = Tutorial.new(kind)
    complete(practice)
    assert(Model.equal(secondPractice.game.board, initialBoard), "Practice sessions must be independent")
    practice:back()
    assert(not practice.complete and practice.accepted and practice.game:solved())
    practice:back()
    assert(practice.step == #practice.lesson.steps - 1 and not practice.accepted)
    assert(practice.game.board[practice:current().cell] == -1)
    practice:restart()
    assert(practice.step == 1 and not practice.complete and not practice.accepted)
    assert(Model.equal(practice.game.board, initialBoard))
    practice:back()
    assert(practice.step == 1 and Model.equal(practice.game.board, initialBoard))
    print("PASS " .. kind .. " practice entry, feedback, completion, back and restart")

    for _, size in ipairs({ { 600, 800 }, { 800, 600 }, { 1264, 1680 }, { 320, 480 }, { 480, 320 } }) do
        local geometry = TutorialLayout.make(practice.game.p, size[1], size[2])
        assert(geometry.cell >= 10 and geometry.instruction.h > 0)
        local lastCell = Layout.cell(geometry, practice.game.p.n ^ 2)
        assert(lastCell.x + lastCell.w <= size[1] and lastCell.y + lastCell.h <= size[2])
        assert(geometry.gy - geometry.top >= 0 and geometry.gx - geometry.left >= 0)
        for _, button in ipairs(geometry.buttons) do
            assert(button.x >= 0 and button.y >= 0)
            assert(button.x + button.w <= size[1] and button.y + button.h <= size[2])
            assert(not Layout.cellAt(geometry, button.x + button.w / 2, button.y + button.h / 2))
        end
    end
    print("PASS " .. kind .. " practice layout in portrait, landscape and small screens")
end

-- Opening the picker and practice needs no access to the current game or store.
local screen = {}
function screen:choose(title, rows)
    self.dialog = { title = title, rows = rows }
end
local opened
package.loaded["doplo/tutorial_screen"] = {
    show = function(parent, practice)
        assert(parent == screen)
        opened = practice
    end,
}
Tutorial.show(screen)
assert(screen.dialog.title:find("How to play", 1, true))
screen.dialog.rows[1][1][2]()
assert(opened.kind == "classic")
screen.dialog.rows[1][2][2]()
assert(opened.kind == "plus")
print("PASS practice opens independently of the player's game")
