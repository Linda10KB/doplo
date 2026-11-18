-- SPDX-License-Identifier: AGPL-3.0-or-later
local D = {}
-- Empty starts are graded within their variant/size. Their score counts
-- propagation rounds plus four rounds per doubling of search nodes.
D.emptyThresholds = {
    classic = { [5] = {4, 5, 7}, [6] = {7, 9, 11}, [7] = {11, 14, 18}, [8] = {14, 18, 24} },
    plus = { [7] = {4, 5, 6}, [8] = {6, 7, 9}, [9] = {5, 6, 7},
        [10] = {6, 7, 8}, [11] = {8, 9, 11}, [12] = {6, 7, 8} },
}
function D.rate(stats, puzzle)
    if stats.status ~= "ok" or stats.count ~= 1 then
        return nil
    end
    if puzzle and puzzle.prefilled == false then
        local limits = D.emptyThresholds[puzzle.kind][puzzle.n]
        local score = stats.waves + 4 * math.log(math.max(1, stats.nodes)) / math.log(2)
        for i, level in ipairs({ "Easy", "Medium", "Hard" }) do
            if score <= limits[i] then
                return level
            end
        end
        return "Expert"
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
