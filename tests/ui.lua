-- Headless interaction/rendering regression tests. Native KOReader smoke tests
-- remain in ko_smoke.lua; these doubles exercise our own event routing only.
package.path = 'doplo.koplugin/?.lua;' .. package.path
local function class(base)
    base = base or {}
    base.__index = base
    function base:extend(t) return class(setmetatable(t, self)) end
    function base:new(t)
        t = setmetatable(t or {}, self)
        t.key_events = {}
        if t.init then t:init() end
        return t
    end
    return base
end
local ui = { stack = {}, dirty = {}, scheduled = {} }
function ui:show(w) self.stack[#self.stack + 1] = w end
function ui:close(w)
    for i = #self.stack, 1, -1 do if self.stack[i] == w then table.remove(self.stack, i) end end
end
function ui:setDirty(_, _, b) self.dirty[#self.dirty + 1] = b or true end
function ui:scheduleIn(_, callback) self.scheduled[callback] = true end
function ui:unschedule(callback) self.scheduled[callback] = nil end
local screen = { w = 600, h = 800 }
function screen:getWidth() return self.w end
function screen:getHeight() return self.h end
function screen:scaleBySize(v) return v end
local device = { screen = screen, light = true }
function device:hasKeys() return false end
function device:hasFrontlight() return self.light end
package.loaded.device = device
package.loaded['ui/uimanager'] = ui
for _, name in ipairs({ 'ui/widget/container/inputcontainer', 'ui/widget/container/widgetcontainer',
    'ui/geometry', 'ui/gesturerange', 'ui/widget/buttondialog', 'ui/widget/infomessage' }) do
    package.loaded[name] = class()
end
package.loaded['ui/widget/frontlightwidget'] = class({ name = 'native_frontlight' })
package.loaded['ui/time'] = { now = function() return 0 end, s = function(n) return n end,
    ms = function(n) return n / 1000 end, to_us = function(n) return n * 1000000 end }
package.loaded['ffi/blitbuffer'] = { COLOR_BLACK = 0, COLOR_WHITE = 255, Color8 = function(n) return n end }
package.loaded['ui/font'] = { getFace = function(_, name, size) return { name = name, size = size } end }
local Text = class()
function Text:getSize() return { w = #self.text * self.face.size * 0.56, h = self.face.size } end
function Text:paintTo(bb, x, y)
    bb.texts[#bb.texts + 1] = { text = self.text, x = x, y = y, size = self.face.size, color = self.fgcolor }
end
function Text:free() end
package.loaded['ui/widget/textwidget'] = Text
local W, M, G, Game, Layout = require('doplo/screen'), require('doplo/model'), require('doplo/generator'), require('doplo/game'), require('doplo/layout')
local values, writes = {}, 0
local settings = {}
function settings:readSetting(k, default) if values[k] == nil then return default end return values[k] end
function settings:saveSetting(k, v) values[k] = v return self end
function settings:flush() return self end
local owner = { settings = settings, store = { save = function() writes = writes + 1; return true end } }
local p = G.candidate(M.config('plus', 11), G.random(642), 0)
p.level = 'Hard'
local w = W:new({ owner = owner, id = 'test', game = Game.new(p) })
local function tap(b) w:onTap(nil, { pos = { x = b.x + b.w / 2, y = b.y + b.h / 2 } }) end
local function button(id)
    for _, b in ipairs(w.a.buttons) do if b.id == id then tap(b) return end end
    error('Missing button ' .. id)
end
local function choose(text)
    local dialog = ui.stack[#ui.stack]
    for _, row in ipairs(dialog.buttons) do
        for _, b in ipairs(row) do if b.text == text then b.callback() return end end
    end
    error('Missing choice ' .. text)
end
local function newBuffer()
    local bb = { rects = {}, texts = {} }
    function bb:paintRect(x, y, width, height, color)
        self.rects[#self.rects + 1] = {x, y, width, height, color}
    end
    function bb:paintBorder(x, y, width, height, thick, color)
        self:paintRect(x, y, width, thick, color)
        self:paintRect(x, y + height - thick, width, thick, color)
        self:paintRect(x, y, thick, height, color)
        self:paintRect(x + width - thick, y, thick, height, color)
    end
    function bb:pixel(x, y)
        for i = #self.rects, 1, -1 do
            local r = self.rects[i]
            if x >= r[1] and x < r[1] + r[3] and y >= r[2] and y < r[2] + r[4] then return r[5] end
        end
    end
    return bb
end
button('brightness')
assert(ui.stack[#ui.stack].name == 'native_frontlight')
ui:close(ui.stack[#ui.stack])
w.reveal = true
button('brightness')
assert(ui.stack[#ui.stack].name == 'native_frontlight')
ui:close(ui.stack[#ui.stack])
w.reveal = false
device.light = false
w:layout()
for _, b in ipairs(w.a.buttons) do assert(b.id ~= 'brightness' and b.id ~= 'view') end
device.light = true
w:layout()
print('PASS native brightness access, device capability and solution view')
button('pencil')
button('v1')
button('v8')
button('v0')
assert(w.game.notes[1] == 259 and writes == 4)
local bb = newBuffer()
w:paintTo(bb)
local largeNotes = {}
for _, t in ipairs(bb.texts) do
    if Layout.inside(w.a.detail, t.x, t.y) then
        largeNotes[t.text] = true
        assert(t.size >= 20)
    end
end
assert(largeNotes['1'] and largeNotes['8'])
local d = w.a.detail
assert(bb:pixel(d.x + d.w * 5 / 6, d.y + d.h * 5 / 6) == 0)
ui.dirty = {}
button('undo')
assert(w.game.notes[1] == 258)
local refreshed = false
for _, b in ipairs(ui.dirty) do if b ~= true and b.x == w.a.info.x and b.y == w.a.info.y then refreshed = true end end
assert(refreshed)
button('redo')
tap(w.a.detail)
assert(ui.stack[#ui.stack].title:find('Pencil: ■, 1, 8', 1, true))
choose('2')
assert(w.game.notes[1] == 263 and ui.stack[#ui.stack].title:find('Pencil: ■, 1, 2, 8', 1, true))
choose('Back')
button('pencil')
button('v0')
bb = newBuffer()
w:paintTo(bb)
local cell = Layout.cell(w.a, 1)
for _, offset in ipairs({0.3, 0.5, 0.7}) do
    assert(bb:pixel(cell.x + cell.w * offset, cell.y + cell.h * offset) == 0)
end
assert(bb:pixel(d.x + d.w / 2, d.y + d.h / 2) == 0)
assert(bb:pixel(cell.x + 2, cell.y + 2) == 255) -- selection remains visible
button('v-1')
assert(w.game.board[1] == -1 and w.game.notes[1] == 0)
print('PASS filled blocks, enlarged notes, dialog editing, undo and refreshes')
w:select(p.n * p.n)
w:onNextCell()
assert(w.game.selected == 1 and w.a.span == p.n)
w:onPrevCell()
assert(w.game.selected == p.n * p.n and w.a.firstCol == 1 and w.a.firstRow == 1)
local cfg = M.config('classic', 8)
w:newLevel(cfg)
choose('Prefilled cells: Off')
assert(values.prefilled_cells == true)
choose('Prefilled cells: On')
assert(values.prefilled_cells == false)
choose('Back')
choose('7 × 7')
assert(ui.stack[#ui.stack].title:find('Doplo 7×7', 1, true))
ui.stack = {}
w:newSize('plus')
choose('11 × 11')
assert(ui.stack[#ui.stack].title:find('Doplo Plus 11×11', 1, true))
print('PASS full-board navigation, new sizes and persistent prefill toggle')
-- Ready puzzles and cancellation use the same selected mode, including after
-- a timeout; classic and Plus must never share a size-based bank key.
package.loaded.datastorage = {}
package.loaded.luasettings = {}
package.loaded['doplo/store'] = {}
local Plugin = dofile('doplo.koplugin/main.lua')
owner.ready = Plugin.ready
owner.start = function(_, nextPuzzle) owner.started = nextPuzzle end
for _, kind in ipairs({'classic', 'plus'}) do
    for _, n in ipairs(M.sizes[kind]) do
        for _, level in ipairs(M.levels) do
            for _, prefilled in ipairs({false, true}) do
                values.prefilled_cells = prefilled
                local ready = owner:ready(M.config(kind, n), level)
                assert(ready.kind == kind and ready.n == n and ready.level == level)
                assert(ready.prefilled == prefilled)
                assert(prefilled or Game.new(ready):filled() == 0)
            end
        end
    end
end
values.prefilled_cells = false
w:generate(M.config('classic', 8), 'Expert')
choose('Play ready puzzle')
assert(not w.job and owner.started.prefilled == false and Game.new(owner.started):filled() == 0)
owner.started = nil
w:generate(M.config('plus', 11), 'Easy')
choose('Cancel')
assert(not w.job and owner.started == nil)
w:generate(M.config('plus', 11), 'Easy')
w.job.deadline = -1
w.job.step()
assert(not w.job and owner.started.prefilled == false and Game.new(owner.started):filled() == 0)
print('PASS ready-puzzle coverage, cancellation and empty-start timeout fallback')
if os.getenv('DOPLO_PREVIEW') then
    w.game = Game.new(owner:ready(M.config('plus', 12), 'Hard'))
    w.game:edit(1, 1, true); w.game:edit(1, 5, true); w.game:edit(1, 8, true); w.game:edit(1, 0, true)
    w.game:edit(14, 0, false); w.game.selected = 1; w.game.pencil = true
    w:layout(); bb = newBuffer(); w:paintTo(bb)
    local f = assert(io.open(os.getenv('DOPLO_PREVIEW'), 'w'))
    f:write(('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d">'):format(screen.w, screen.h))
    for _, r in ipairs(bb.rects) do
        f:write(('<rect x="%d" y="%d" width="%d" height="%d" fill="rgb(%d,%d,%d)"/>'):format(r[1],r[2],r[3],r[4],r[5],r[5],r[5]))
    end
    for _, t in ipairs(bb.texts) do
        f:write(('<text x="%d" y="%d" font-size="%d" fill="rgb(%d,%d,%d)">%s</text>'):format(t.x,t.y+t.size,t.size,t.color,t.color,t.color,t.text:gsub('&','&amp;'):gsub('<','&lt;')))
    end
    f:write('</svg>'); f:close()
end
