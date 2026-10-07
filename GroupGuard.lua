local ADDON_NAME = "GroupGuard"
local REQUIRED_MEMBERS = 5
local CHAT_TAG = "|cff68c279[GroupGuard]|r"

GroupGuardDB = GroupGuardDB or {}

local function database()
    if type(GroupGuardDB) ~= "table" then
        GroupGuardDB = {}
    end
    if type(GroupGuardDB.roster) ~= "table" then
        GroupGuardDB.roster = {}
    end
    if GroupGuardDB.enabled == nil then
        GroupGuardDB.enabled = true
    end
    return GroupGuardDB
end

local function getTargetGroup()
    local targetGroup = tonumber(database().targetGroup)
    if not targetGroup or targetGroup < 1 or targetGroup > 8 or targetGroup ~= math.floor(targetGroup) then
        return nil
    end
    return targetGroup
end

local function trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function normalizeName(value)
    return trim(value):lower()
end

local function normalizeRealm(value)
    return (value or ""):lower():gsub("[%s%-]+", "")
end

local function parseIdentity(value)
    local clean = trim(value)
    local name, realm = clean:match("^(.-)%s*%-%s*(.-)$")
    if name and realm and name ~= "" and realm ~= "" then
        return {
            name = normalizeName(name),
            realm = normalizeRealm(realm),
        }
    end
    return {
        name = normalizeName(clean),
    }
end

local function identityForUnit(unit, rosterName)
    local unitName, unitRealm = UnitName(unit)
    local unitIdentity = unitName and parseIdentity(unitName) or nil
    local rosterIdentity = rosterName and parseIdentity(rosterName) or nil
    local name = unitIdentity and unitIdentity.name or (rosterIdentity and rosterIdentity.name)
    local realm = unitRealm

    if not realm or realm == "" then
        realm = (unitIdentity and unitIdentity.realm)
            or (rosterIdentity and rosterIdentity.realm)
            or GetRealmName()
    end

    return {
        name = name and normalizeName(name) or "",
        realm = normalizeRealm(realm),
    }
end

local function identityMatches(expected, actual)
    if expected.name ~= actual.name then
        return false
    end
    return expected.realm == nil or expected.realm == actual.realm
end

local function failure(detail)
    return { safe = false, detail = detail }
end

local function getExpectedRoster()
    local expected = {}
    local seen = {}

    for _, rawName in ipairs(database().roster) do
        if type(rawName) ~= "string" or trim(rawName) == "" then
            return nil, "Saved roster is invalid. Set it again with /gg set."
        end

        local identity = parseIdentity(rawName)
        if identity.name == "" then
            return nil, "Saved roster is invalid. Set it again with /gg set."
        end

        local key = identity.name .. "|" .. (identity.realm or "")
        if seen[key] then
            return nil, "Saved roster has duplicate names. Set it again with /gg set."
        end

        seen[key] = true
        expected[#expected + 1] = identity
    end

    if #expected ~= REQUIRED_MEMBERS then
        return nil, ("Roster has %d names; set exactly 5 with /gg set."):format(#expected)
    end

    return expected
end

local function evaluateRoster()
    local targetGroup = getTargetGroup()
    if not targetGroup then
        return failure("Target group is not set or invalid. Set it with /gg group <1-8>.")
    end

    local expected, configError = getExpectedRoster()
    if not expected then
        return failure(configError)
    end

    local playerIdentity = identityForUnit("player")
    local playerIsConfigured = false
    for _, identity in ipairs(expected) do
        if identityMatches(identity, playerIdentity) then
            playerIsConfigured = true
            break
        end
    end
    if not playerIsConfigured then
        return failure("Your character is not one of the five saved names.")
    end

    if not IsInRaid() then
        return failure("Not in a raid; party chat is not verified.")
    end

    local targetGroupCount = 0
    local expectedInTargetGroup = {}
    local expectedFound = {}
    local rosterIncomplete = false
    local ambiguousNames = false
    local raidSize = tonumber(GetNumGroupMembers()) or 0

    for index = 1, raidSize do
        local rosterName, _, subgroup = GetRaidRosterInfo(index)
        if type(rosterName) ~= "string" or rosterName == "" then
            rosterIncomplete = true
        else
            local groupNumber = tonumber(subgroup)
            if groupNumber == targetGroup then
                targetGroupCount = targetGroupCount + 1
            end

            local actualIdentity = identityForUnit("raid" .. index, rosterName)
            local matchedIndex
            for expectedIndex, identity in ipairs(expected) do
                if identityMatches(identity, actualIdentity) then
                    if matchedIndex then
                        ambiguousNames = true
                    else
                        matchedIndex = expectedIndex
                    end
                end
            end

            if matchedIndex then
                if expectedFound[matchedIndex] then
                    ambiguousNames = true
                else
                    expectedFound[matchedIndex] = true
                end
                if groupNumber == targetGroup then
                    expectedInTargetGroup[matchedIndex] = true
                end
            end
        end
    end

    if rosterIncomplete then
        return failure("Raid roster data is incomplete; treat party chat as unsafe.")
    end
    if ambiguousNames then
        return failure("A name matches multiple raiders. Add realm names with /gg set.")
    end

    local expectedInTargetGroupCount = 0
    for index = 1, REQUIRED_MEMBERS do
        if expectedInTargetGroup[index] then
            expectedInTargetGroupCount = expectedInTargetGroupCount + 1
        end
    end

    if targetGroupCount ~= REQUIRED_MEMBERS then
        return failure(("Group %d has %d people; exactly 5 are required."):format(targetGroup, targetGroupCount))
    end
    if expectedInTargetGroupCount ~= REQUIRED_MEMBERS then
        return failure(("Only %d/5 expected people are in Group %d."):format(expectedInTargetGroupCount, targetGroup))
    end

    return {
        safe = true,
        detail = ("All 5 saved members are in Group %d."):format(targetGroup),
    }
end

local panel = CreateFrame("Frame", "GroupGuardFrame", UIParent)
panel:SetSize(160, 55)
panel:SetFrameStrata("HIGH")
panel:SetClampedToScreen(true)
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetPoint("TOP", UIParent, "TOP", 0, -155)

local background = panel:CreateTexture(nil, "BACKGROUND")
background:SetTexture("Interface\\Buttons\\WHITE8X8")
background:SetAllPoints()
background:SetVertexColor(0.34, 0.07, 0.08, 0.96)

local accent = panel:CreateTexture(nil, "BORDER")
accent:SetTexture("Interface\\Buttons\\WHITE8X8")
accent:SetPoint("TOPLEFT")
accent:SetPoint("BOTTOMLEFT")
accent:SetWidth(4)
accent:SetVertexColor(1, 0.22, 0.2, 1)

local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 9, -6)
local initialTargetGroup = getTargetGroup()
heading:SetText(initialTargetGroup and ("GROUP %d CHECK"):format(initialTargetGroup) or "GROUP ? CHECK")
heading:SetTextColor(0.9, 0.92, 0.95, 1)

local stateText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
stateText:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -2)
stateText:SetText(initialTargetGroup and ("G%d BROKE"):format(initialTargetGroup) or "GROUP? BROKE")
stateText:SetTextColor(1, 1, 1, 1)

local detailText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
detailText:SetPoint("TOPLEFT", stateText, "BOTTOMLEFT", 0, -2)
detailText:SetWidth(140)
detailText:SetWordWrap(true)
detailText:SetJustifyH("LEFT")
detailText:SetText("Waiting for raid roster.")

local function updateDisplay()
    local targetGroup = getTargetGroup()
    heading:SetText(targetGroup and ("GROUP %d CHECK"):format(targetGroup) or "GROUP ? CHECK")
    local groupLabel = targetGroup and ("G%d"):format(targetGroup) or "GROUP?"

    if not database().enabled then
        panel:Hide()
        return { safe = false, detail = "Indicator disabled. Use /gg on to enable it." }
    end

    if not IsInRaid() then
        panel:Hide()
        return { safe = false, detail = "Not in a raid." }
    end

    panel:Show()
    local result = evaluateRoster()
    if result.safe then
        background:SetVertexColor(0.04, 0.28, 0.12, 0.96)
        accent:SetVertexColor(0.3, 1, 0.48, 1)
        stateText:SetText(groupLabel .. " GOOD")
    else
        background:SetVertexColor(0.34, 0.07, 0.08, 0.96)
        accent:SetVertexColor(1, 0.22, 0.2, 1)
        stateText:SetText("ALERT ALERT " .. groupLabel .. " BROKE")
    end
    detailText:SetText(result.detail)
    return result
end

local validPoints = {
    CENTER = true,
    TOP = true,
    TOPLEFT = true,
    TOPRIGHT = true,
    LEFT = true,
    RIGHT = true,
    BOTTOM = true,
    BOTTOMLEFT = true,
    BOTTOMRIGHT = true,
}

local function restorePosition()
    local position = database().position
    panel:ClearAllPoints()

    if type(position) == "table"
        and validPoints[position.point]
        and validPoints[position.relativePoint]
    then
        panel:SetPoint(
            position.point,
            UIParent,
            position.relativePoint,
            tonumber(position.x) or 0,
            tonumber(position.y) or -155
        )
    else
        panel:SetPoint("TOP", UIParent, "TOP", 0, -155)
    end
end

panel:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() then
        self:StartMoving()
        self.isMoving = true
    end
end)

panel:SetScript("OnDragStop", function(self)
    if not self.isMoving then
        return
    end
    self:StopMovingOrSizing()
    self.isMoving = nil

    local point, _, relativePoint, x, y = self:GetPoint(1)
    database().position = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end)

panel:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Hold Shift and drag to move", 1, 1, 1)
    GameTooltip:AddLine("Commands: /gg help", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
panel:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local function printHelp()
    print(CHAT_TAG .. " Set five names, including your character:")
    print("  /gg set Name1, Name2, Name3, Name4, Name5")
    print("  Add -Realm to names if the same name appears more than once.")
    print("  /gg group <1-8> sets the target raid group. No group is assumed.")
    print("  /gg on|off|toggle  /gg status  /gg roster  /gg clear  /gg help")
end

local function parseRosterList(input)
    local names = {}
    local seen = {}
    local list = input .. ","

    for entry in list:gmatch("(.-),") do
        local clean = trim(entry)
        if clean == "" then
            return nil, "Roster entries cannot be empty."
        end

        local identity = parseIdentity(clean)
        local key = identity.name .. "|" .. (identity.realm or "")
        if identity.name == "" or seen[key] then
            return nil, "Roster names must be non-empty and unique."
        end

        seen[key] = true
        names[#names + 1] = clean
    end

    if #names ~= REQUIRED_MEMBERS then
        return nil, ("Enter exactly 5 comma-separated names; received %d."):format(#names)
    end
    return names
end

local function handleSlashCommand(message)
    local command, rest = (message or ""):match("^(%S+)%s*(.*)$")
    command = command and command:lower() or ""
    rest = trim(rest or "")

    if command == "set" then
        local names, parseError = parseRosterList(rest)
        if not names then
            print(CHAT_TAG .. " " .. parseError)
            return
        end

        database().roster = names
        local result = updateDisplay()
        print(CHAT_TAG .. " Saved the five names for this character.")
        if not result.safe then
            print(CHAT_TAG .. " " .. result.detail)
        end
    elseif command == "group" then
        if rest == "" then
            local targetGroup = getTargetGroup()
            print(CHAT_TAG .. ("Target raid group: %s."):format(targetGroup and tostring(targetGroup) or "not set"))
            return
        end

        local targetGroup = tonumber(rest)
        if not targetGroup or targetGroup < 1 or targetGroup > 8 or targetGroup ~= math.floor(targetGroup) then
            print(CHAT_TAG .. " Enter a whole raid group number from 1 to 8. Use /gg group <1-8>.")
            return
        end

        database().targetGroup = targetGroup
        local result = updateDisplay()
        print(CHAT_TAG .. ("Target raid group set to %d."):format(targetGroup))
        if not result.safe then
            print(CHAT_TAG .. " " .. result.detail)
        end
    elseif command == "on" or command == "enable" then
        database().enabled = true
        updateDisplay()
        print(CHAT_TAG .. " Indicator enabled.")
    elseif command == "off" or command == "disable" then
        database().enabled = false
        updateDisplay()
        print(CHAT_TAG .. " Indicator disabled. Use /gg on to show it again.")
    elseif command == "toggle" then
        database().enabled = not database().enabled
        updateDisplay()
        print(CHAT_TAG .. " Indicator " .. (database().enabled and "enabled." or "disabled."))
    elseif command == "status" then
        local result = updateDisplay()
        local status = database().enabled
            and (result.safe and "PARTY CHAT VERIFIED" or "DO NOT USE PARTY CHAT")
            or "INDICATOR DISABLED"
        print(CHAT_TAG .. " " .. status .. ": " .. result.detail)
    elseif command == "roster" then
        local roster = database().roster
        if #roster == 0 then
            print(CHAT_TAG .. " No roster saved. Use /gg set Name1, Name2, Name3, Name4, Name5.")
        else
            print(CHAT_TAG .. " Saved roster: " .. table.concat(roster, ", "))
        end
    elseif command == "clear" then
        database().roster = {}
        updateDisplay()
        print(CHAT_TAG .. " Saved roster cleared.")
    elseif command == "" or command == "help" then
        printHelp()
    else
        print(CHAT_TAG .. " Unknown command. Use /gg help.")
    end
end

SLASH_GROUPGUARD1 = "/gg"
SLASH_GROUPGUARD2 = "/groupguard"
SlashCmdList.GROUPGUARD = handleSlashCommand

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == ADDON_NAME then
            database()
            restorePosition()
            updateDisplay()
        end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        updateDisplay()
    end
end)
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
