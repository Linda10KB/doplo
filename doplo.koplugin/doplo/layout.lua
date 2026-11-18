-- SPDX-License-Identifier: AGPL-3.0-or-later
local Layout = {}
local floor = math.floor
local function rect(x, y, w, h)
    return { x = floor(x), y = floor(y), w = floor(w), h = floor(h) }
end
Layout.rect = rect
function Layout.inside(a, x, y)
    return x >= a.x and x < a.x + a.w and y >= a.y and y < a.y + a.h
end
function Layout.make(p, w, h, frontlight)
    local u = math.min(w, h) / 600
    local function px(v)
        return math.max(1, floor(v * u + 0.5))
    end
    local edge, gap, head = px(16), px(6), px(70)
    local wide = w >= h * 1.16
    local a = { w = w, h = h, u = u, px = px, head = head, buttons = {}, n = p.n,
        firstRow = 1, firstCol = 1, span = p.n }
    local function button(id, b, label)
        b.id, b.label = id, label
        a.buttons[#a.buttons + 1] = b
    end
    local closeW, gameW, lightW = px(66), px(75), frontlight and px(94) + gap or 0
    button("game", rect(w - edge - closeW - gap - gameW, px(12), gameW, px(43)), "Game")
    button("close", rect(w - edge - closeW, px(12), closeW, px(43)), "Close")
    if frontlight then
        button("brightness", rect(w - edge - closeW - gameW - lightW - 2 * gap, px(12), lightW - gap, px(43)), "Brightness")
    end
    a.title = rect(edge, px(2), w - 2 * edge - closeW - gameW - lightW - 2 * gap, px(42))
    a.subtitle = rect(edge, px(42), a.title.w, px(22))

    local panelX = wide and floor(w * 0.62) or edge
    local panelW = w - panelX - edge
    local keyH, barH = px(48), px(43)
    local digits, keys = p.n - p.blocks, {}
    for v = 1, digits do
        keys[#keys + 1] = v
    end
    keys[#keys + 1], keys[#keys + 2] = 0, -1
    local per = wide and math.min(4, #keys) or math.min(6, #keys)
    local keyRows = math.ceil(#keys / per)
    local detailH = wide and px(172) or px(100)
    local panelH = detailH + gap + keyRows * (keyH + gap) + barH
    local panelY = wide and floor((h + head - panelH) / 2) or h - edge - panelH
    a.panel = rect(panelX, panelY, panelW, panelH)
    a.info = rect(panelX, panelY, panelW, detailH)
    local zoom = px(96)
    a.detail = rect(panelX, panelY, zoom, zoom)
    local textX = wide and panelX or panelX + zoom + px(12)
    local textY = wide and panelY + zoom + gap or panelY
    local textW = wide and panelW or panelW - zoom - px(12)
    local lineH = wide and px(24) or px(25)
    a.detailLabel = rect(wide and panelX + zoom + gap or textX, panelY,
        wide and panelW - zoom - gap or textW, lineH)
    a.counter = rect(a.detailLabel.x, panelY + lineH, a.detailLabel.w, lineH)
    a.rowDetail = rect(textX, textY + (wide and 0 or 2 * lineH), textW, lineH)
    a.colDetail = rect(textX, a.rowDetail.y + lineH, textW, lineH)
    local y = a.info.y + a.info.h + gap
    for row = 1, keyRows do
        local count = math.min(per, #keys - (row - 1) * per)
        local bw = (panelW - (count - 1) * gap) / count
        for j = 1, count do
            local v = keys[(row - 1) * per + j]
            button("v" .. v, rect(panelX + (j - 1) * (bw + gap), y, bw, keyH),
                v == -1 and "Erase" or (v == 0 and "■" or tostring(v)))
        end
        y = y + keyH + gap
    end
    local actions = { { "pencil", "Pencil" }, { "undo", "Undo" }, { "redo", "Redo" }, { "hint", "Hint" }, { "check", "Check" } }
    local bw = (panelW - 4 * gap) / 5
    for j, entry in ipairs(actions) do
        button(entry[1], rect(panelX + (j - 1) * (bw + gap), y, bw, barH), entry[2])
    end
    local boardW = (wide and panelX - gap or w - edge) - edge
    local boardH = (wide and h - edge or panelY - px(12)) - head - px(5)
    local maxR, maxC = 1, 1
    for i = 1, p.n do
        maxR = math.max(maxR, #p.row[i])
        maxC = math.max(maxC, #p.col[i])
    end
    -- Reserve actual text space, independent of cell size. Large grids must
    -- never shrink their edge clues into miniature cell-relative type.
    local clueSize = px(p.kind == "classic" and 25 or 22)
    local slotW, slotH = px(30), px(26)
    local left, top = maxR * slotW + px(6), maxC * slotH + px(6)
    local cell = math.max(1, floor(math.min((boardW - left) / p.n, (boardH - top) / p.n)))
    a.cell, a.left, a.top, a.maxR, a.maxC = cell, left, top, maxR, maxC
    a.clueSize, a.slotW, a.slotH = clueSize, slotW, slotH
    a.gx = edge + floor((boardW - cell * p.n - left) / 2) + left
    a.gy = head + px(5) + floor((boardH - cell * p.n - top) / 2) + top
    return a
end
function Layout.cell(a, i)
    local col = (i - 1) % a.n
    local row = floor((i - 1) / a.n)
    if col < 0 or row < 0 or col >= a.n or row >= a.n then
        return nil
    end
    return rect(a.gx + col * a.cell, a.gy + row * a.cell, a.cell, a.cell)
end
function Layout.cellAt(a, x, y)
    local col, row = floor((x - a.gx) / a.cell), floor((y - a.gy) / a.cell)
    if col >= 0 and col < a.n and row >= 0 and row < a.n then
        return row * a.n + col + 1
    end
end
return Layout
