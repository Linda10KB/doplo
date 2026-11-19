-- SPDX-License-Identifier: AGPL-3.0-or-later
local Device = require("device")
local UIManager = require("ui/uimanager")

local DeviceSettings = {}

local function refreshScreen(screen)
    -- A full refresh uses the flashing waveform needed to clear e-ink ghosting.
    UIManager:setDirty(screen, "full")
end

local function rotateScreen(screen)
    local nextRotation = (Device.screen:getRotationMode() + 1) % 4
    local host = screen.owner.ui
    local rotationHandler = host.view or host

    -- Follow KOReader's own menu: let the reader or file manager update its
    -- layout too, so closing Doplo returns to a correctly sized host window.
    rotationHandler:onSetRotationMode(nextRotation)
    screen:layout()
    refreshScreen(screen)
end

local function showBrightness()
    local FrontlightWidget = require("ui/widget/frontlightwidget")
    UIManager:show(FrontlightWidget:new({}))
end

function DeviceSettings.show(screen)
    local rows = {}

    if Device:hasFrontlight() then
        rows[#rows + 1] = { { "Brightness", showBrightness } }
    end

    rows[#rows + 1] = { { "Rotate 90°", function()
        rotateScreen(screen)
    end } }

    rows[#rows + 1] = { { "Refresh screen", function()
        refreshScreen(screen)
    end } }

    rows[#rows + 1] = { { "Back to puzzle" } }

    return screen:choose("Device settings", rows)
end

return DeviceSettings
