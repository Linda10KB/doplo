-- SPDX-License-Identifier: AGPL-3.0-or-later
local Celebration = {}

local compliments = {
    "Wauw, ook vandaag ben jij weer een denderend succes.",
    "Je bent prachtig. En je puzzel ook.",
    "Alles wat je doet is toch wel leuk. Dit was zelfs belachelijk goed.",
    "Jij bent nu vast smerig trots op jezelf. Terecht.",
    "Ergens staat een denkbeeldig stadion voor je op de banken.",
    "Wat een hoofd. Wat een talent. Wat een schandalig lekker resultaat.",
    "Je brein verdient een glittercape en een vrije middag.",
    "Alle vakjes kloppen. Je uitstraling trouwens ook.",
    "Vandaag ben jij de reden dat de confetti op is.",
    "Kijk jou nou. Gewoon even excellent zitten wezen.",
    "De puzzel is af. De bewondering voor jou nog lang niet.",
    "Als logisch nadenken een parfum was, rook jij nu peperduur.",
    "Je hebt dit zo goed gedaan dat het bijna onbeleefd is.",
    "Pak dat denkbeeldige podium. Deze staande ovatie is voor jou.",
    "Zelfs je potloodstreepjes wisten al: dit wordt een legende.",
    "Je innerlijke overwinningsdans mag nu schaamteloos naar buiten.",
}

local settingKey = "last_celebration"

-- Keep the position in plugin settings so reopening Doplo does not repeat the
-- previous compliment. Every message gets a turn before the cycle starts again.
function Celebration.next(settings)
    local previousIndex = settings:readSetting(settingKey)
    local validIndex = type(previousIndex) == "number"
        and previousIndex == math.floor(previousIndex)
        and previousIndex >= 1
        and previousIndex <= #compliments

    local nextIndex = 1
    if validIndex then
        nextIndex = previousIndex % #compliments + 1
    end

    settings:saveSetting(settingKey, nextIndex):flush()
    return "Solved! Helemaal goed.\n\n" .. compliments[nextIndex]
end

return Celebration
