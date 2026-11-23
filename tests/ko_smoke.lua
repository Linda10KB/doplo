-- This file runs only in the disposable KO_HOME created by tools/test_koreader.py.
local UI = require("ui/uimanager")
local Device = require("device")
local Geom = require("ui/geometry")
local Event = require("ui/event")
local Key = require("device/key")
local time = require("ui/time")
local phase = os.getenv("DOPLO_PHASE")
local function pause(s)
    coroutine.yield(s or 0.05)
end
local function top()
    return UI:getTopmostVisibleWidget()
end
local function touch(b, ges)
    UI:sendEvent(Event:new(
        "Gesture",
        {
            ges = ges or "tap",
            pos = Geom:new({
                x = math.floor(b.x + b.w / 2),
                y = math.floor(b.y + b.h / 2),
                w = 0,
                h = 0,
            }),
            time = time.now(),
        }
    ))
end
local function button(w, id)
    for _, b in ipairs(w.geometry.buttons) do
        if b.id == id then
            touch(b)
            return
        end
    end
    error("No board button " .. id)
end
local function choose(label, pattern)
    UI:_repaint()
    local dialog = top()
    assert(dialog.buttontable, "Expected button dialog for " .. label .. " on " .. tostring(dialog.name))
    for _, row in ipairs(dialog.buttontable.buttons_layout) do
        for _, b in ipairs(row) do
            if b.text == label or (pattern and b.text:find(label, 1, true)) then
                assert(b.dimen and b.dimen.w > 0, "dialog button not painted")
                touch(b.dimen)
                return
            end
        end
    end
    error("Missing dialog option " .. label .. " in " .. tostring(dialog.title))
end
local function capture(name)
    UI:_repaint()
    Device.screen.bb:writePNG(os.getenv("DOPLO_SCREENS") .. "/" .. name .. ".png")
end

local function repaintFullscreen(context)
    local screen = Device.screen
    local originalRefresh = screen.refreshFullImp
    local refreshedFullscreen = false
    -- All SDL refresh modes end here. A correct framebuffer alone does not
    -- prove that the e-ink panel received the changed pixels outside a dialog.
    screen.refreshFullImp = function(self, x, y, width, height, ...)
        if x == 0 and y == 0 and width == self:getWidth() and height == self:getHeight() then
            refreshedFullscreen = true
        end
        return originalRefresh(self, x, y, width, height, ...)
    end
    local ok, repaintError = pcall(function()
        UI:_repaint()
    end)
    screen.refreshFullImp = originalRefresh
    assert(ok, repaintError)
    assert(refreshedFullscreen, context .. " must refresh the whole display, not just the closed dialog")
end

local function screensaverPreferences()
    local preferences = {}
    for key, value in pairs(G_reader_settings.data) do
        if key:find("screensaver", 1, true) then
            preferences[key] = value
        end
    end
    return require("dump")(preferences, nil, true)
end

local function sleepAndWake(window, foreground)
    foreground = foreground or window
    local screensaver = require("ui/screensaver")
    local attachment = assert(window.owner.sleepCover, "Doplo sleep cover was not attached")
    local preferences = screensaverPreferences()
    local originalRotation = Device.screen:getRotationMode()
    local currentGame = window.game
    local selectedCell, historySize = currentGame.selected, #currentGame.history
    for cycle = 1, 2 do
        Device:simulateSuspend()
        UI:_repaint()
        assert(screensaver.image_file == window.owner.path .. "/resources/doplo-cover.png")
        assert(screensaver.screensaver_type == "cover" and screensaver.show_message == false)
        assert(top() == screensaver.screensaver_widget and Device.screen_saver_mode)
        if cycle == 1 then
            capture("sleep-cover-" .. phase)
        end
        Device:simulateResume()
        UI:_repaint()
        assert(top() == foreground and not Device.screen_saver_mode)
        assert(Device.screen:getRotationMode() == originalRotation)
        assert(window.game == currentGame and currentGame.selected == selectedCell)
        assert(#currentGame.history == historySize)
        assert(screensaverPreferences() == preferences)
    end
    return attachment.originalSetup
end

local function checkCoverRestored(host, originalSetup)
    local screensaver = require("ui/screensaver")
    assert(not host.doplo.sleepCover and screensaver.setup == originalSetup)
    screensaver:setup()
    assert(screensaver.image_file ~= host.doplo.path .. "/resources/doplo-cover.png")
    screensaver:show()
    UI:_repaint()
    screensaver:close()
    UI:_repaint()
    assert(top() == host and not Device.screen_saver_mode)
end

local function rotateAndRestore(window)
    local initialRotation = Device.screen:getRotationMode()
    local originalWidth, originalHeight = window.dimen.w, window.dimen.h
    local currentGame = window.game
    local selectedCell, pencilMode = currentGame.selected, currentGame.pencil
    local historySize = #currentGame.history
    for turn = 1, 4 do
        button(window, "device")
        choose("Rotate 90°")
        UI:_repaint()
        assert(top() == window)
        assert(Device.screen:getRotationMode() == (initialRotation + turn) % 4)
        assert(window.dimen.w == Device.screen:getWidth())
        assert(window.dimen.h == Device.screen:getHeight())
        assert(window.game == currentGame and currentGame.selected == selectedCell)
        assert(currentGame.pencil == pencilMode and #currentGame.history == historySize)
        button(window, "device")
        choose("Refresh screen")
        assert(top() == window)
        if turn == 1 then
            assert(window.dimen.w == originalHeight and window.dimen.h == originalWidth)
            capture("rotated-" .. phase)
        end
    end
    assert(window.dimen.w == originalWidth and window.dimen.h == originalHeight)
end

local function practice(window, variant)
    local game = window.game
    local reveal = window.reveal
    local selectedCell, historySize = game.selected, #game.history
    local originalBoard = require("doplo/model").copy(game.board)
    button(window, "help")
    choose(variant)
    local tutorial = top()
    assert(tutorial.name == "doplo_tutorial")
    repaintFullscreen("Opening " .. variant .. " practice")
    local exercise = tutorial.practice
    local layout = require("doplo/layout")
    capture(variant == "Doplo" and "tutorial-doplo" or "tutorial-plus")
    button(tutorial, "next")
    assert(exercise.step == 1, "Next must wait for an entry")
    button(tutorial, "v3")
    assert(exercise.feedback:find("Try again.", 1, true))
    assert(exercise.game.board[exercise:current().cell] == -1)
    repaintFullscreen("Practice feedback")
    capture(variant == "Doplo" and "tutorial-doplo-feedback" or "tutorial-plus-feedback")
    for stepIndex, step in ipairs(exercise.lesson.steps) do
        touch(layout.cell(tutorial.geometry, step.cell))
        button(tutorial, "v" .. exercise.game.p.solution[step.cell])
        assert(exercise.accepted)
        assert(exercise.game.board[step.cell] == exercise.game.p.solution[step.cell])
        if stepIndex == 1 then
            local practiceBoard = require("doplo/model").copy(exercise.game.board)
            local feedback = exercise.feedback
            window.dirty = true
            sleepAndWake(window, tutorial)
            assert(not window.dirty, "Suspending practice must flush the underlying game")
            assert(tutorial.practice == exercise and exercise.step == 1 and exercise.accepted)
            assert(exercise.feedback == feedback)
            assert(require("doplo/model").equal(exercise.game.board, practiceBoard))
        end
        button(tutorial, "next")
        repaintFullscreen("Advancing practice")
    end
    assert(exercise.complete and exercise.game:solved())
    capture("tutorial-controls-" .. phase)
    button(tutorial, "close")
    repaintFullscreen("Returning to the puzzle")
    assert(top() == window and window.game == game)
    assert(window.reveal == reveal)
    assert(game.selected == selectedCell and #game.history == historySize)
    assert(require("doplo/model").equal(game.board, originalBoard))
end

local function idfile(what, data)
    local path = os.getenv("KO_HOME") .. "/test-" .. what
    local f = assert(io.open(path, data and "w" or "r"))
    if data then
        f:write(data)
    else
        data = f:read("*a")
    end
    f:close()
    return data
end
local function run()
    local host = phase == "reader" and require("apps/reader/readerui").instance
        or require("apps/filemanager/filemanager").instance
    assert(host and host.doplo, "PluginLoader did not register Doplo")
    -- A fresh KOReader profile may present its own migration/first-run notices.
    while top() and top() ~= host and (top().text or top().toast) do
        UI:close(top())
    end
    host.menu:setUpdateItemTable()
    local tabIndex
    for k, v in ipairs(host.menu.tab_item_table) do
        if v.id == "tools" or v.icon == "appbar.tools" then
            tabIndex = k
            break
        end
    end
    assert(tabIndex, "No Tools tab")
    host.menu:onShowMenu(tabIndex)
    local menu = assert(host.menu.menu_container)[1]
    local target
    for page = 1, menu.page_num do
        menu:onGotoPage(page)
        UI:_repaint()
        for _, v in ipairs(menu.item_group) do
            if v.item and v.item.id == "doplo" then
                target = v
                break
            end
        end
        if target then
            break
        end
    end
    assert(target, "No Doplo item in Tools")
    touch(target.dimen)
    pause()
    local w = assert(
        host.doplo.window,
        "Game did not open: "
            .. tostring(top().name)
            .. " "
            .. tostring(top().text)
            .. " "
            .. tostring(top().title)
    )
    assert(
        top() == w,
        "Board covered by "
            .. tostring(top().name)
            .. " "
            .. tostring(top().text)
            .. " "
            .. tostring(top().title)
    )
    local originalScreensaverSetup = sleepAndWake(w)
    local layout = require("doplo/layout")
    if phase == "reader" then
        assert(w.game.p.n == 5)
        rotateAndRestore(w)
        button(w, "close")
        assert(not host.doplo.window)
        checkCoverRestored(host, originalScreensaverSetup)
        return
    end
    if phase == "reopen" then
        assert(w.id == idfile("classic") and w.game.p.n == 5)
        assert(w.game.notes[w.game.selected] ~= 0 and w.game.pencil)
        local savedHistory = host.doplo.settings:readSetting("celebration_history")
        assert(require("dump")(savedHistory, nil, true) == idfile("celebrations"),
            "Compliment history changed across a real KOReader restart")
        require("doplo/celebration").next(host.doplo.settings)
        local continuedHistory = host.doplo.settings:readSetting("celebration_history")
        assert(not savedHistory.seen[continuedHistory.last], "Restart repeated a seen compliment")
        capture("landscape")
        practice(w, "Doplo Plus")
        rotateAndRestore(w)
        button(w, "close")
        assert(not host.doplo.window)
        checkCoverRestored(host, originalScreensaverSetup)
        return
    end
    local g = w.game
    assert(g.p.n == 5 and g.p.level == "Easy" and g:filled() == 0 and g.p.prefilled == false)
    idfile("classic", w.id)
    local i = g.selected
    touch(layout.cell(w.geometry, i))
    button(w, "v1")
    assert(g.board[i] == 1)
    button(w, "v0")
    assert(g.board[i] == 0)
    button(w, "undo")
    assert(g.board[i] == 1)
    button(w, "redo")
    assert(g.board[i] == 0)
    button(w, "v-1")
    assert(g.board[i] == -1)
    button(w, "pencil")
    button(w, "v1")
    button(w, "v2")
    assert(g.board[i] == -1 and g.notes[i] == 6)
    UI:sendEvent(Event:new("KeyPress", Key:new("RPgFwd", {})))
    assert(g.selected ~= i)
    UI:sendEvent(Event:new("KeyPress", Key:new("RPgBack", {})))
    assert(g.selected == i)
    capture("doplo-5x5")
    button(w, "device")
    capture("device-settings")
    choose("Back to puzzle")
    rotateAndRestore(w)
    practice(w, "Doplo")
    practice(w, "Doplo Plus")
    local bb = require("ffi/blitbuffer")
    local mono = bb.new(w.dimen.w, w.dimen.h, bb.TYPE_BB8)
    w:paintTo(mono)
    local b = layout.cell(w.geometry, 1)
    assert(mono:getPixel(b.x, b.y):getColor8().a < 100 and mono:getPixel(0, 0):getColor8().a == 255)
    mono:free()
    button(w, "check")
    assert(top().text:find("consistent", 1, true))
    UI:close(top())
    touch(layout.cell(w.geometry, i), "hold")
    choose("Back")
    button(w, "hint")
    while w.job do
        pause()
    end
    assert(top().title:find("=", 1, true))
    choose("Place value")
    assert(g.board[g.selected] == g.p.solution[g.selected])
    button(w, "undo")
    w:select(i)
    button(w, "game")
    choose("Show solution")
    choose("Show solution")
    assert(w.reveal and g.board[i] == -1)
    button(w, "device")
    choose("Refresh screen")
    button(w, "help")
    choose("Back to puzzle")
    assert(w.reveal and top() == w)
    practice(w, "Doplo")
    button(w, "v3")
    assert(g.board[i] == -1)
    button(w, "game")
    assert(not w.reveal)
    button(w, "game")
    choose("New puzzle")
    choose("Doplo Plus")
    choose("12 × 12", true)
    choose("Expert")
    assert(w.job)
    choose("Cancel")
    pause()
    assert(not w.job and w.game == g)
    -- Exercise scheduler handoff and the automatic fallback without relying on CPU speed.
    local beats, finished = 0, 0
    w:work("Time limit test", function(tick)
        while true do
            beats = beats + 1
            tick(128)
        end
    end, function()
        error("Unbounded operation finished")
    end, function()
        finished = finished + 1
    end, 0.20)
    while w.job do
        pause(0.025)
    end
    assert(beats > 0 and finished == 1 and w.game == g)
    button(w, "game")
    choose("New puzzle")
    choose("Doplo Plus")
    choose("12 × 12", true)
    choose("Hard")
    choose("Play ready puzzle")
    pause()
    assert(w.game.p.n == 12 and w.game.p.level == "Hard" and w.game:filled() == 0)
    capture("doplo-plus-12x12")
    local corner = layout.cell(w.geometry, 144)
    touch(corner)
    assert(w.game.selected == 144 and w.geometry.span == 12)
    button(w, "pencil")
    button(w, "v1")
    button(w, "v8")
    button(w, "v0")
    capture("doplo-plus-detail")
    touch(w.geometry.detail)
    assert(top().title:find("Pencil: ■, 1, 8", 1, true))
    capture("doplo-input-dialog")
    choose("2")
    assert(top().title:find("Pencil: ■, 1, 2, 8", 1, true))
    choose("Back")
    UI:sendEvent(Event:new("KeyPress", Key:new("RPgFwd", {})))
    assert(w.game.selected == 1 and w.geometry.span == 12 and w.geometry.firstCol == 1 and w.geometry.firstRow == 1)
    local generator = require("doplo/generator")
    local privateRandom = generator.random
    generator.random = function()
        return privateRandom(81923)
    end
    button(w, "game")
    choose("New puzzle")
    choose("Doplo")
    choose("6 × 6")
    choose("Prefilled cells: Off")
    assert(host.doplo.settings:readSetting("prefilled_cells") == true)
    choose("Medium")
    generator.random = privateRandom
    while w.job do
        pause()
    end
    assert(w.game.p.n == 6 and w.game.p.level == "Medium" and host.doplo.settings:hasNot("ready_classic_6_prefilled_Medium"))
    -- Complete this board via the public gestures and check the solved message.
    for pos, v in ipairs(w.game.p.solution) do
        if w.game.p.givens[pos] == -1 then
            touch(layout.cell(w.geometry, pos))
            button(w, "v" .. v)
        end
    end
    assert(w.game:solved())
    assert(top().text == host.doplo.settings:readSetting("celebration_history").last)
    local firstCompliment = top().text
    capture("celebration")
    UI:close(top())
    button(w, "check")
    assert(top().text ~= firstCompliment)
    assert(top().text == host.doplo.settings:readSetting("celebration_history").last)
    idfile("celebrations", require("dump")(
        host.doplo.settings:readSetting("celebration_history"), nil, true))
    UI:close(top())
    button(w, "game")
    choose("Saved puzzles")
    choose("Doplo 5×5", true)
    assert(w.id == idfile("classic") and w.game.notes[i] == 6)
    w:select(i)
    w:onSuspend()
    button(w, "close")
    assert(not host.doplo.window)
    checkCoverRestored(host, originalScreensaverSetup)
end
local co = coroutine.create(run)
local function step()
    local ok, delay = coroutine.resume(co)
    if not ok then
        io.stderr:write(debug.traceback(co, tostring(delay)) .. "\n")
        UI:quit(3)
    elseif coroutine.status(co) == "dead" then
        print("DOPLO PASS " .. phase)
        UI:quit(0)
    else
        UI:scheduleIn(delay, step)
    end
end
UI:scheduleIn(0.30, step)
