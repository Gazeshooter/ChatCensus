local CCensus = CreateFrame("Frame", "ChatCensusFrame")

local active = nil
local channelName = nil
local names = {}
local nameCount = 0
local idleTime = 0
local timeout = 1.5

local debugMode = nil

CCensus:RegisterEvent("CHAT_MSG_CHANNEL_LIST")

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff88ff88[ChatCensus]|r " .. msg)
end

local function Trim(s)
    if not s then return nil end
    s = string.gsub(s, "^%s+", "")
    s = string.gsub(s, "%s+$", "")
    return s
end

local function CleanName(name)
    name = Trim(name)
    if not name or name == "" then return nil end

    -- Remove channel owner/mod markers.
    name = string.gsub(name, "^[@*]+", "")

    -- Remove WoW colour codes if present.
    name = string.gsub(name, "|c%x%x%x%x%x%x%x%x", "")
    name = string.gsub(name, "|r", "")

    name = Trim(name)

    -- Ignore empty strings.
    if not name or name == "" then return nil end

    -- Ignore obvious non-name text.
    if string.find(name, " ") then return nil end

    return name
end

local function AddName(name)
    name = CleanName(name)
    if not name then return end

    local key = string.lower(name)

    if not names[key] then
        names[key] = name
        nameCount = nameCount + 1
    end
end

local function ParseChannelListLine(msg)
    if not msg then return end

    if debugMode or rawOnlyMode then
        Print("RAW: " .. msg)
    end

    if rawOnlyMode then
        return
    end

    -- Strip WoW 1.12 channel-list prefix:
    -- [1. General - Elwynn Forest] Nameone, Nametwo
    msg = string.gsub(msg, "^%s*%[[^%]]+%]%s*", "")

    -- Also support formats with a colon:
    -- world: Nameone, Nametwo
    local colon = string.find(msg, ":")
    if colon then
        msg = string.sub(msg, colon + 1)
    end

    -- Split names by comma.
    local startPos = 1

    while true do
        local comma = string.find(msg, ",", startPos)

        if comma then
            AddName(string.sub(msg, startPos, comma - 1))
            startPos = comma + 1
        else
            AddName(string.sub(msg, startPos))
            break
        end
    end
end

local function FinishScan()
    active = nil
    CCensus:SetScript("OnUpdate", nil)

    Print(channelName .. " census complete: |cffffffff" .. nameCount .. "|r unique names found.")
end

local function OnUpdate()
    if not active then return end

    idleTime = idleTime + arg1

    -- There is no clean "channel list finished" event in 1.12,
    -- so we finish after the output has gone quiet.
    if idleTime >= timeout then
        FinishScan()
    end
end

CCensus:SetScript("OnEvent", function()
    if event == "CHAT_MSG_CHANNEL_LIST" and active then
        idleTime = 0
        ParseChannelListLine(arg1)
    end
end)

SLASH_CHATCENSUS1 = "/ccensus"

SlashCmdList["CHATCENSUS"] = function(msg)
    msg = string.lower(msg or "")
    msg = Trim(msg)

    if not msg or msg == "" then
        Print("Usage:")
        Print("/ccensus world")
        Print("/ccensus debug world")
        return
    end

    debugMode = nil

    if string.sub(msg, 1, 6) == "debug " then
        debugMode = 1
        msg = Trim(string.sub(msg, 7))
    end

    if not msg or msg == "" then
        Print("Usage: /ccensus world")
        return
    end

    active = 1
    channelName = msg
    names = {}
    nameCount = 0
    idleTime = 0

    Print("Scanning channel: " .. channelName)

    CCensus:SetScript("OnUpdate", OnUpdate)

    -- Ask the server for the named channel list.
    -- This is effectively what we want from /chatlist world,
    -- but addon-controlled.
    ListChannelByName(channelName)
end