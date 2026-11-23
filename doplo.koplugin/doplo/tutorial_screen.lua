-- SPDX-License-Identifier: AGPL-3.0-or-later
local Device = require("device")
local UIManager = require("ui/uimanager")
local InputContainer = require("ui/widget/container/inputcontainer")
local Geometry = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local Font = require("ui/font")
local TextBoxWidget = require("ui/widget/textboxwidget")
local BlitBuffer = require("ffi/blitbuffer")
local Model = require("doplo/model")
local Layout = require("doplo/layout")
local TutorialLayout = require("doplo/tutorial_layout")
local Paint = require("doplo/paint")
local TutorialScreen = InputContainer:extend({
    name = "doplo_tutorial",
    covers_fullscreen = true,
    stop_events_propagation = true,
})
local BLACK, WHITE = BlitBuffer.COLOR_BLACK, BlitBuffer.COLOR_WHITE

function TutorialScreen:init()
    self.painter = Paint.new()
    self:layout()
    self.ges_events = {
        Tap = { GestureRange:new({ ges = "tap", range = function() return self.dimen end }) },
    }
    if Device:hasKeys() then
        self.key_events.Leave = { { Device.input.group.Back } }
        self.key_events.NextStep = { { Device.input.group.PgFwd } }
        self.key_events.PreviousStep = { { Device.input.group.PgBack } }
    end
end

function TutorialScreen:layout()
    self.dimen = Geometry:new({ x = 0, y = 0, w = Device.screen:getWidth(), h = Device.screen:getHeight() })
    self.geometry = TutorialLayout.make(self.practice.game.p, self.dimen.w, self.dimen.h)
    self:clearInstruction()
end

function TutorialScreen:clearInstruction()
    if self.instruction then
        self.instruction:free()
        self.instruction = nil
    end
end

function TutorialScreen:refresh()
    self:clearInstruction()
    UIManager:setDirty(self, "ui")
end

function TutorialScreen:onSetDimensions()
    self:layout()
    self:refresh()
end

TutorialScreen.onScreenResize = TutorialScreen.onSetDimensions

function TutorialScreen:instructionText()
    local practice = self.practice
    if practice.complete then
        return "Your practice puzzle is complete!\n\nOn your own board, tap a square and then a digit or block. Pencil keeps possible values; Erase clears a square. Hold a square for larger keys. Undo, Check and Hint can help.\n\nTap Back to puzzle when you are ready."
    end
    if practice.feedback then
        local heading = practice.accepted and "Well done! " or ""
        return heading .. practice.feedback
            .. (practice.accepted and "\n\nTap Next when you are ready." or "")
    end
    return practice:current().instruction .. "\n\nTap the square marked ?, then a key below."
end

function TutorialScreen:paintInstruction(buffer)
    local box = self.geometry.instruction
    if not self.instruction then
        local size = math.floor(self.geometry.px(19) * 100 / Device.screen:scaleBySize(100) + 0.5)
        repeat
            self.instruction = TextBoxWidget:new({
                text = self:instructionText(),
                face = Font:getFace("cfont", size),
                width = box.w,
                alignment = "left",
                fgcolor = BLACK,
            })
            if self.instruction:getSize().h <= box.h or size <= 12 then
                break
            end
            self:clearInstruction()
            size = size - 1
        until false
    end
    self.instruction:paintTo(buffer, box.x, box.y)
end

function TutorialScreen:paintFocus(buffer)
    if self.practice.complete then
        return
    end
    local layout = self.geometry
    local step = self.practice:current()
    local selected = Layout.cell(layout, step.cell)
    local focus
    if step.axis == "row" then
        focus = Layout.rect(layout.gx - layout.left, selected.y, layout.left + layout.cell * layout.n, layout.cell)
    else
        focus = Layout.rect(selected.x, layout.gy - layout.top, layout.cell, layout.top + layout.cell * layout.n)
    end
    buffer:paintBorder(focus.x, focus.y, focus.w, focus.h, layout.px(2), BLACK)
end

function TutorialScreen:paintCoordinates(buffer)
    local layout = self.geometry
    for index = 1, layout.n do
        local column = Layout.rect(layout.gx + (index - 1) * layout.cell, layout.gy - layout.top, layout.cell, layout.px(20))
        local row = Layout.rect(layout.gx - layout.left, layout.gy + (index - 1) * layout.cell, layout.px(20), layout.cell)
        self.painter:text(buffer, column, string.char(64 + index), layout.px(13), "cfont")
        self.painter:text(buffer, row, index, layout.px(13), "cfont")
    end
end

function TutorialScreen:paintButtons(buffer)
    local practice = self.practice
    for _, button in ipairs(self.geometry.buttons) do
        local enabled = true
        if button.id == "next" then
            enabled = practice.accepted and not practice.complete
        elseif button.id == "back" then
            enabled = practice.step > 1 or practice.complete
        elseif button.id:match("^v%d+$") then
            enabled = not practice.accepted and not practice.complete
        end
        local label = button.id == "next" and practice.step == #practice.lesson.steps and "Finish" or button.label
        local color = enabled and BLACK or BlitBuffer.Color8(150)
        buffer:paintBorder(button.x, button.y, button.w, button.h, self.geometry.px(1), color)
        if button.id:match("^v%d+$") then
            self.painter:value(buffer, button, tonumber(button.id:sub(2)), self.geometry.px(27), "tfont", color)
        else
            self.painter:text(buffer, button, label, self.geometry.px(16), "cfont", color)
        end
    end
end

function TutorialScreen:paintTo(buffer)
    if self.dimen.w ~= Device.screen:getWidth() or self.dimen.h ~= Device.screen:getHeight() then
        self:layout()
    end
    local layout, practice = self.geometry, self.practice
    local game = practice.game
    local selectedRow = math.floor((game.selected - 1) / game.p.n) + 1
    local selectedColumn = (game.selected - 1) % game.p.n + 1
    buffer:paintRect(0, 0, layout.w, layout.h, WHITE)
    self.painter:text(buffer, layout.title, Model.name(game.p) .. " · How to play", layout.px(26), "tfont", BLACK, "left")
    self.painter:text(buffer, layout.subtitle, "Practice board · Your own puzzle is kept", layout.px(16), "cfont", BLACK, "left")
    local clueLayout = setmetatable({
        left = layout.left - layout.px(20),
        top = layout.top - layout.px(20),
    }, { __index = layout })
    self.painter:clues(buffer, clueLayout, game.p, selectedRow, selectedColumn)
    self.painter:boardCells(buffer, layout, game, false)
    if not practice.accepted and not practice.complete then
        self.painter:text(buffer, Layout.cell(layout, game.selected), "?", layout.cell * 0.55, "tfont")
    end
    self.painter:grid(buffer, layout, game, false)
    self:paintCoordinates(buffer)
    self:paintFocus(buffer)
    local heading = practice.complete and "Ready to play!"
        or ("%d / %d · %s"):format(practice.step, #practice.lesson.steps, practice:current().title)
    self.painter:text(buffer, layout.stepTitle, heading, layout.px(22), "tfont", BLACK, "left")
    self:paintInstruction(buffer)
    self:paintButtons(buffer)
end

function TutorialScreen:activateButton(id)
    local practice = self.practice
    if id == "close" then
        self:onLeave()
        return
    elseif id == "next" then
        practice:advance()
    elseif id == "back" then
        practice:back()
    elseif id == "restart" then
        practice:restart()
    elseif id:match("^v%d+$") then
        practice:input(tonumber(id:sub(2)))
    end
    self:refresh()
end

function TutorialScreen:onTap(_, gesture)
    local layout = self.geometry
    local x, y = gesture.pos.x, gesture.pos.y
    local cell = Layout.cellAt(layout, x, y)
    if cell then
        if cell ~= self.practice:current().cell and not self.practice.accepted and not self.practice.complete then
            self.practice.feedback = "This step uses the outlined square. " .. self.practice:current().instruction
        elseif not self.practice.accepted then
            self.practice.feedback = nil
        end
        self:refresh()
        return true
    end
    for _, button in ipairs(layout.buttons) do
        if Layout.inside(button, x, y) then
            self:activateButton(button.id)
            return true
        end
    end
    return true
end

function TutorialScreen:onNextStep()
    self:activateButton("next")
    return true
end

function TutorialScreen:onPreviousStep()
    self:activateButton("back")
    return true
end

function TutorialScreen:onSuspend()
    self.parent:onSuspend()
end

function TutorialScreen:onFlushSettings()
    self.parent:flush()
end

function TutorialScreen:onLeave()
    self.parent:onSetDimensions()
    UIManager:close(self, "partial")
    return true
end

function TutorialScreen:onCloseWidget()
    self.painter:clear()
    self:clearInstruction()
end

function TutorialScreen.show(parent, practice)
    local window = TutorialScreen:new({ parent = parent, practice = practice })
    UIManager:show(window)
    return window
end

return TutorialScreen
