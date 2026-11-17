-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Exact support for a whole row/column, without materializing its permutations.
local bit = require("bit")
local band, bor = bit.band, bit.bor
local L = { power = {}, size = { [0] = 0 }, total = { [0] = 0 }, single = {} }
for v = 0, 8 do
    L.power[v] = 2 ^ v
    L.single[2 ^ v] = v
end
for mask = 1, 511 do
    local low = band(mask, -mask)
    L.size[mask] = 1 + L.size[mask - low]
    L.total[mask] = L.single[low] + L.total[mask - low]
end

-- mask bit 0 is a block; digits 1..d occupy bits 1..d.
function L.support(p, clue, allowed, tick)
    local n, blocks, classic = p.n, p.blocks, p.kind == "classic"
    local prefix = { [0] = 0 }
    for j = 1, #clue do
        prefix[j] = prefix[j - 1] + clue[j]
    end
    local digits = n - blocks
    local total = digits * (digits + 1) / 2
    if classic then
        if #clue ~= 1 or clue[1] < 0 or clue[1] > total then
            return nil
        end
    else
        if #clue < 1 or #clue > blocks + 1 or prefix[#clue] ~= total then
            return nil
        end
        for _, v in ipairs(clue) do
            if v < 1 then
                return nil
            end
        end
    end
    local out, visited = {}, {}
    for pos = 1, n do
        out[pos] = 0
    end
    local work = 0
    -- A cached successful suffix has already contributed ALL its supported
    -- suffix edges. Its incoming edge still contributes at the caller.
    local function visit(pos, used, state)
        local used_blocks = pos - 1 - L.size[used]
        if pos > n then
            if used_blocks ~= blocks then
                return false
            end
            if classic then
                return state == clue[1]
            end
            return state == #clue or state == #clue + 1
        end
        local key = (pos * 512 + used) * 64 + state
        local cached = visited[key]
        if cached ~= nil then
            return cached
        end
        work = work + 1
        if work % 96 == 0 and tick then
            tick(96)
        end
        local options = band(allowed[pos], bit.bnot(used))
        local result = false
        while options ~= 0 do
            local flag = band(options, -options)
            options = options - flag
            local value = L.single[flag]
            local next_state, next_used = state, used
            if value == 0 then
                if used_blocks == blocks then
                    next_state = nil
                elseif classic then
                    if used_blocks == 1 and state ~= clue[1] then
                        next_state = nil
                    end
                else
                    local sum = L.total[used]
                    if state <= #clue and sum == prefix[state] then
                        next_state = state + 1
                    elseif sum ~= prefix[state - 1] then
                        next_state = nil
                    end
                end
            else
                next_used = used + flag
                if classic then
                    if used_blocks == 1 then
                        next_state = state + value
                        if next_state > clue[1] then
                            next_state = nil
                        end
                    end
                elseif state > #clue or L.total[next_used] > prefix[state] then
                    next_state = nil
                end
            end
            if next_state and visit(pos + 1, next_used, next_state) then
                out[pos] = bor(out[pos], flag)
                result = true
            end
        end
        visited[key] = result
        return result
    end
    local ok = visit(1, 0, classic and 0 or 1)
    if tick then
        tick(work % 96 + 1)
    end
    if ok then
        return out
    end
end
return L
