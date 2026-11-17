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
function Layout.tile(n, upper, left)
    local span = math.ceil(n / 2)
    return { row = upper and 1 or n - span + 1, col = left and 1 or n - span + 1, span = span }
end
function Layout.make(p, w, h, tile)
    local u = math.min(w, h) / 600
    local function px(v)
        return math.max(1, floor(v * u + 0.5))
    end
    local edge, gap, head = px(19), px(6), px(70)
    local wide = w >= h * 1.16
    local a = {
        w = w,
        h = h,
        u = u,
        px = px,
        head = head,
        buttons = {},
        n = p.n,
        firstRow = tile and tile.row or 1,
        firstCol = tile and tile.col or 1,
        span = tile and tile.span or p.n,
    }
    local function button(id, b, label)
        b.id, b.label = id, label
        a.buttons[#a.buttons + 1] = b
    end
    local closeW, gameW = px(66), px(75)
    button("game", rect(w - edge - closeW - gap - gameW, px(12), gameW, px(43)), "Game")
    button("close", rect(w - edge - closeW, px(12), closeW, px(43)), "Close")
    local viewW = p.n >= 7 and px(64) + gap or 0
    if viewW > 0 then
        button("view", rect(w - edge - closeW - gameW - viewW - 2 * gap, px(12), viewW - gap, px(43)), "View")
    end
    a.title = rect(edge, px(2), w - 2 * edge - closeW - gameW - viewW - 2 * gap, px(42))
    a.subtitle = rect(edge, px(42), a.title.w, px(22))

    local panelX = wide and floor(w * 0.63) or edge
    local panelW = w - panelX - edge
    local keyH, barH = wide and px(52) or px(50), px(43)
    local digits, keys = p.n - p.blocks, {}
    for v = 1, digits do
        keys[#keys + 1] = v
    end
    keys[#keys + 1], keys[#keys + 2] = 0, -1
    local per = wide and math.min(4, #keys) or math.min(6, #keys)
    local keyRows = math.ceil(#keys / per)
    local panelH = px(36) + gap + keyRows * (keyH + gap) + barH
    local panelY = wide and floor((h + head - panelH) / 2) or h - edge - panelH
    a.panel = rect(panelX, panelY, panelW, panelH)
    a.info = rect(panelX, panelY, panelW, px(36))
    local y = a.info.y + a.info.h + gap
    for row = 1, keyRows do
        local count = math.min(per, #keys - (row - 1) * per)
        local bw = (panelW - (count - 1) * gap) / count
        for j = 1, count do
            local v = keys[(row - 1) * per + j]
            button(
                "v" .. v,
                rect(panelX + (j - 1) * (bw + gap), y, bw, keyH),
                v == -1 and "Erase" or (v == 0 and "×" or tostring(v))
            )
        end
        y = y + keyH + gap
    end
    local tools = { { "pencil", "Pencil" }, { "undo", "Undo" }, { "redo", "Redo" }, { "hint", "Hint" }, {
        "check",
        "Check",
    } }
    local bw = (panelW - 4 * gap) / 5
    for j, item in ipairs(tools) do
        button(item[1], rect(panelX + (j - 1) * (bw + gap), y, bw, barH), item[2])
    end
    local boardW = (wide and panelX - edge or w) - 2 * edge
    local boardH = (wide and h - edge or panelY - px(12)) - head - px(10)
    local maxR, maxC = 1, 1
    for i = 1, p.n do
        maxR = math.max(maxR, #p.row[i])
        maxC = math.max(maxC, #p.col[i])
    end
    local leftUnits = p.kind == "classic" and 0.74 or maxR * 0.48 + 0.15
    local topUnits = p.kind == "classic" and 0.68 or maxC * 0.42 + 0.12
    local cell = floor(math.min(boardW / (a.span + leftUnits), boardH / (a.span + topUnits)))
    local left, top = floor(cell * leftUnits), floor(cell * topUnits)
    local totalW, totalH = a.span * cell + left, a.span * cell + top
    a.cell, a.left, a.top, a.maxR, a.maxC = cell, left, top, maxR, maxC
    a.gx = edge + floor((boardW - totalW) / 2) + left
    a.gy = head + px(5) + floor((boardH - totalH) / 2) + top
    return a
end
function Layout.cell(a, i)
    local col = (i - 1) % a.n + 1 - a.firstCol
    local row = math.floor((i - 1) / a.n) + 1 - a.firstRow
    if col < 0 or row < 0 or col >= a.span or row >= a.span then
        return nil
    end
    return rect(a.gx + col * a.cell, a.gy + row * a.cell, a.cell, a.cell)
end
function Layout.cellAt(a, x, y)
    local col, row = floor((x - a.gx) / a.cell), floor((y - a.gy) / a.cell)
    if col >= 0 and col < a.span and row >= 0 and row < a.span then
        return (row + a.firstRow - 1) * a.n + col + a.firstCol
    end
end
return Layout
