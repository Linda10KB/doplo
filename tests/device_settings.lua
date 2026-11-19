-- Device controls use KOReader's native host rotation and full-refresh request.
package.path = "doplo.koplugin/?.lua;" .. package.path

local display = { rotation = 0, width = 600, height = 800 }

function display:getRotationMode()
    return self.rotation
end

local device = { screen = display, hasLight = true }

function device:hasFrontlight()
    return self.hasLight
end

local manager = {}

function manager:setDirty(widget, refreshType)
    self.dirtyWidget = widget
    self.refreshType = refreshType
end

function manager:show(widget)
    self.shownWidget = widget
end

local frontlight = {}

function frontlight:new()
    return { name = "native_frontlight" }
end

package.loaded.device = device
package.loaded["ui/uimanager"] = manager
package.loaded["ui/widget/frontlightwidget"] = frontlight

local DeviceSettings = require("doplo/device_settings")
local originalGame = { selected = 12, pencil = true, notes = { 7 }, board = { 3 } }
local host = { rotations = 0 }

function host:onSetRotationMode(rotation)
    self.rotations = self.rotations + 1
    display.rotation = rotation
    display.width, display.height = display.height, display.width
end

local screen = { owner = { ui = host }, game = originalGame, reveal = true }

function screen:layout()
    self.width = display.width
    self.height = display.height
end

function screen:choose(title, rows)
    self.title = title
    self.options = {}
    for _, row in ipairs(rows) do
        for _, option in ipairs(row) do
            self.options[option[1]] = option[2] or true
        end
    end
end

DeviceSettings.show(screen)
assert(screen.title == "Device settings")
screen.options.Brightness()
assert(manager.shownWidget.name == "native_frontlight")

screen.options["Refresh screen"]()
assert(manager.dirtyWidget == screen and manager.refreshType == "full")

for rotation = 1, 4 do
    screen.options["Rotate 90°"]()
    assert(display.rotation == rotation % 4)
    assert(screen.width == display.width and screen.height == display.height)
    assert(manager.dirtyWidget == screen and manager.refreshType == "full")
end
assert(host.rotations == 4 and screen.width == 600 and screen.height == 800)
assert(screen.game == originalGame and screen.game.selected == 12 and screen.game.pencil)
assert(screen.game.notes[1] == 7 and screen.game.board[1] == 3 and screen.reveal)
print("PASS device brightness, full refresh and four rotations preserving puzzle state")

device.hasLight = false
DeviceSettings.show(screen)
assert(screen.options.Brightness == nil)
assert(screen.options["Rotate 90°"] and screen.options["Refresh screen"])

local readerView = { rotations = 0, onSetRotationMode = host.onSetRotationMode }
host.view = readerView
screen.options["Rotate 90°"]()
assert(readerView.rotations == 1 and host.rotations == 4)
assert(screen.width == 800 and screen.height == 600)
print("PASS devices without frontlights and native reader-view rotation")
