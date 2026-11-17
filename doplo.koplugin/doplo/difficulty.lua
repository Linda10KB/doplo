-- SPDX-License-Identifier: AGPL-3.0-or-later
local D = {}
function D.rate(stats)
    if stats.status ~= "ok" or stats.count ~= 1 then
        return nil
    end
    if stats.nodes > 1 or stats.waves >= 9 then
        return "Expert"
    end
    if stats.waves >= 6 then
        return "Hard"
    end
    if stats.waves >= 4 then
        return "Medium"
    end
    return "Easy"
end
return D
