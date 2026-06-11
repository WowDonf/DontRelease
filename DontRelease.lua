-- =====================================================================
-- DontRelease - Core
-- =====================================================================
-- Shows a movable warning frame when the raid wipes and the player is
-- dead, sitting on top of the default release dialog.
--
-- Wipe detection is threshold-based (count of dead raid members) plus
-- ENCOUNTER_END(success=0) as a hard signal. A solo death with the rest
-- of the raid alive will NOT trigger the warning.
-- =====================================================================

local addonName, ns = ...
ns.addonName = addonName

-- Chat helper: prefixes every addon-originated chat line with a red
-- [DontRelease] tag so the player can identify our messages at a glance.
-- Use for prefixed lines only; raw print() for indented continuation
-- lines (status dump, help text).
local function chatPrint(msg)
    print("|cffff3030[DontRelease]|r " .. msg)
end
ns.chatPrint = chatPrint

-- ---------------------------------------------------------------------
-- Saved variable defaults
-- ---------------------------------------------------------------------
local defaults = {
    enabled         = true,
    text            = "DO NOT RELEASE",
    subtitle        = "Wait for battle res or raid leader's call.",
    color           = { r = 1.0, g = 0.2, b = 0.2 },
    scale           = 1.0,
    wipeThreshold   = 3,    -- dead raid members required to count as a wipe
    useDeathCountTrigger = true,  -- if false, ignore wipeThreshold (only ENCOUNTER_END triggers)
    showInDungeons  = false,
    hideOnResRequest = true,
    suppressOnSelfRes = false,  -- if true, hide warning when player has self-res available
    locked          = true,
    modifiers       = { shift = true, ctrl = true, alt = true },
    holdToClose     = false,  -- if true, modifier must be HELD for holdDuration seconds
    holdDuration    = 1.5,    -- seconds to hold before frame dismisses
    sound = {
        enabled = false,
        file    = "Alarm1", -- matches a key in ns.SOUNDS
        channel = "Master",
    },
    position = nil,    -- { point, relativePoint, x, y }
}

-- Deep-merge defaults into the saved table without overwriting user values.
-- Also validates types: if a saved value's type doesn't match the default's
-- type, the value is replaced with the default (protects against corrupt SVs).
local function MergeDefaults(target, source)
    for k, v in pairs(source) do
        local defaultType = type(v)
        local savedType = type(target[k])
        if defaultType == "table" then
            if savedType ~= "table" then target[k] = {} end
            MergeDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        elseif savedType ~= defaultType then
            -- Corrupt SV: type mismatch. Restore default.
            target[k] = v
        end
    end
    return target
end

-- Saved-variable migration: handle schema changes between addon versions.
-- Each step must be idempotent (safe to run on already-migrated or
-- fresh-install data). Called once on ADDON_LOADED, after MergeDefaults
-- and before ValidateRanges.
local function MigrateSaved(db)
    -- pre-1.6.0 used Blizzard SOUNDKIT enum names directly as sound keys
    -- (e.g. "AuctionWindowOpen"). 1.6.0+ uses our own stable keys
    -- (Alarm1, Whomp1, Boop1, ...). Unknown keys drop to the default.
    if db.sound and db.sound.file then
        local known = false
        for _, entry in ipairs(ns.SOUNDS) do
            if db.sound.file == entry.key then known = true; break end
        end
        if not known then db.sound.file = "Alarm1" end
    end
end
ns.MigrateSaved = MigrateSaved

-- Numeric/range validation for specific keys that can be set out-of-bounds
-- by direct DB edits, /reload mid-write, or future range tightening.
local function ValidateRanges(db)
    if type(db.scale) ~= "number" then db.scale = 1.0 end
    db.scale = math.max(0.5, math.min(3.0, db.scale))

    if type(db.wipeThreshold) ~= "number" then db.wipeThreshold = 3 end
    db.wipeThreshold = math.max(1, math.min(30, math.floor(db.wipeThreshold)))

    if type(db.useDeathCountTrigger) ~= "boolean" then db.useDeathCountTrigger = true end

    if type(db.holdToClose) ~= "boolean" then db.holdToClose = false end
    if type(db.holdDuration) ~= "number" then db.holdDuration = 1.5 end
    db.holdDuration = math.max(0.5, math.min(5.0, db.holdDuration))

    -- Color components must be [0,1] numbers
    local c = db.color
    if type(c) ~= "table" then
        db.color = { r = 1, g = 0.2, b = 0.2 }
    else
        c.r = (type(c.r) == "number") and math.max(0, math.min(1, c.r)) or 1
        c.g = (type(c.g) == "number") and math.max(0, math.min(1, c.g)) or 0.2
        c.b = (type(c.b) == "number") and math.max(0, math.min(1, c.b)) or 0.2
    end

    -- Sound channel must be one of the known channels
    local validChannel = false
    for _, ch in ipairs(ns.CHANNELS) do
        if db.sound.channel == ch then validChannel = true; break end
    end
    if not validChannel then db.sound.channel = "Master" end
end
ns.ValidateRanges = ValidateRanges

-- ---------------------------------------------------------------------
-- Bundled sound choices.
-- Each entry has either a `kit` (SOUNDKIT enum name) for built-in
-- Blizzard sounds, or a `file` (game-relative path) for sounds we ship
-- as .ogg under Sounds/. `key` is the stable identifier saved in DB.
-- ---------------------------------------------------------------------
ns.SOUNDS = {
    { key = "Alarm1", label = "Alarm 1", kit = "ALARM_CLOCK_WARNING_1" },
    { key = "Alarm2", label = "Alarm 2", kit = "ALARM_CLOCK_WARNING_2" },
    { key = "Alarm3", label = "Alarm 3", kit = "ALARM_CLOCK_WARNING_3" },
    { key = "Whomp1", label = "Womp",                file = "Interface\\AddOns\\DontRelease\\Sounds\\whomp1.ogg" },
    { key = "Whomp2", label = "Womp Womp",           file = "Interface\\AddOns\\DontRelease\\Sounds\\whomp2.ogg" },
    { key = "Whomp3", label = "Womp Womp Womp",      file = "Interface\\AddOns\\DontRelease\\Sounds\\whomp3.ogg" },
    { key = "Whomp4", label = "Womp Womp Womp Womp", file = "Interface\\AddOns\\DontRelease\\Sounds\\whomp4.ogg" },
    { key = "Boop1",  label = "Boop 1 (single high)",  file = "Interface\\AddOns\\DontRelease\\Sounds\\boop1.ogg" },
    { key = "Boop2",  label = "Boop 2 (double high)",  file = "Interface\\AddOns\\DontRelease\\Sounds\\boop2.ogg" },
    { key = "Boop3",  label = "Boop 3 (ascending)",    file = "Interface\\AddOns\\DontRelease\\Sounds\\boop3.ogg" },
    { key = "Defeat", label = "Defeat (somber theme)",  file = "Interface\\AddOns\\DontRelease\\Sounds\\defeat.ogg" },
}

-- Resolve a sound key to the actual playable identifier + how to play it.
-- Returns (playable, isFile) where:
--   playable = SOUNDKIT numeric ID, or string file path
--   isFile   = true if path-based, false if SOUNDKIT-based
local function ResolveSound(key)
    if not key then return nil, false end
    for _, entry in ipairs(ns.SOUNDS) do
        if entry.key == key then
            if entry.file then return entry.file, true end
            if entry.kit  then return SOUNDKIT[entry.kit], false end
            return nil, false
        end
    end
    return nil, false
end
ns.ResolveSound = ResolveSound

-- Single playback helper used by both the alert path and the test button.
local function PlaySoundEntry(key, channel)
    local playable, isFile = ResolveSound(key)
    if not playable then return false end
    if isFile then
        return (PlaySoundFile(playable, channel or "Master"))
    else
        return (PlaySound(playable, channel or "Master"))
    end
end
ns.PlaySoundEntry = PlaySoundEntry

ns.CHANNELS = { "Master", "SFX", "Music", "Ambience", "Dialog" }

-- ---------------------------------------------------------------------
-- Warning frame
-- ---------------------------------------------------------------------
local frame = CreateFrame("Frame", "DontReleaseFrame", UIParent, "BackdropTemplate")
ns.frame = frame

-- Default frame size used when there's no death popup to measure against
-- (test mode, fallback). The frame is dynamically resized in TryShow to
-- match the popup's actual dimensions + a margin so it always fully covers
-- the popup, regardless of whether self-res buttons (Soulstone,
-- Reincarnation) widen or tallen it.
local DEFAULT_W, DEFAULT_H = 380, 200
local POPUP_MARGIN_W, POPUP_MARGIN_H = 40, 30
frame:SetSize(DEFAULT_W, DEFAULT_H)
frame:SetFrameStrata("FULLSCREEN_DIALOG")
frame:SetFrameLevel(200)
frame:SetClampedToScreen(true)
frame:Hide()

frame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile     = true, tileSize = 32, edgeSize = 32,
    insets   = { left = 11, right = 12, top = 12, bottom = 11 },
})
frame:SetBackdropColor(0.45, 0, 0, 0.95)
frame:SetBackdropBorderColor(1, 0.1, 0.1, 1)

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
frame.title:SetPoint("TOP", frame, "TOP", 0, -20)

frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.subtitle:SetPoint("TOP", frame.title, "BOTTOM", 0, -10)
frame.subtitle:SetTextColor(1, 1, 1)
frame.subtitle:SetWidth(320)
frame.subtitle:SetJustifyH("CENTER")
frame.subtitle:SetWordWrap(true)

frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
frame.hint:SetPoint("BOTTOM", frame, "BOTTOM", 0, 14)
frame.hint:SetTextColor(0.75, 0.75, 0.75)

frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self)
    if not DontReleaseDB.locked then self:StartMoving() end
end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint()
    DontReleaseDB.position = {
        point = point, relativePoint = relativePoint, x = x, y = y,
    }
end)

-- Close X button
frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
frame.closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
frame.closeBtn:SetScript("OnClick", function()
    if ns.testMode then
        -- Test/unlock mode: clicking X re-locks and reopens options
        ns.testMode = false
        DontReleaseDB.locked = true
        frame:Hide()
        ns.OpenOptions()
    else
        frame:Hide()
    end
end)

-- Modifier-key close (only triggers on a NEW press; ignores modifiers
-- that were already held at show)
local modifierWasHeldOnShow = false
local function AnyEnabledModifierDown()
    local m = DontReleaseDB and DontReleaseDB.modifiers
    if not m then return false end
    return (m.shift and IsShiftKeyDown())
        or (m.ctrl  and IsControlKeyDown())
        or (m.alt   and IsAltKeyDown())
end

-- Hold-to-close progress bar (thin gold bar at the bottom of the frame)
frame.holdBar = CreateFrame("StatusBar", nil, frame)
frame.holdBar:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  10, 4)
frame.holdBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 4)
frame.holdBar:SetHeight(4)
frame.holdBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
frame.holdBar:SetStatusBarColor(1, 0.82, 0, 0.95)
frame.holdBar:SetMinMaxValues(0, 1)
frame.holdBar:SetValue(0)
frame.holdBar:Hide()
local holdBarBg = frame.holdBar:CreateTexture(nil, "BACKGROUND")
holdBarBg:SetAllPoints()
holdBarBg:SetColorTexture(0, 0, 0, 0.55)

frame:SetScript("OnShow", function()
    modifierWasHeldOnShow = AnyEnabledModifierDown()
end)

-- holdStart is the timestamp the current continuous hold began, or nil
local holdStart = nil

local function ResetHold()
    holdStart = nil
    frame.holdBar:SetValue(0)
    frame.holdBar:Hide()
end

frame:HookScript("OnHide", ResetHold)

-- Block the death popup's Enter-to-release shortcut while the warning is up.
-- StaticPopupDialogs["DEATH"].noKeys = true makes StaticPopup_OnKeyDown ignore
-- Enter/Space so the player can't reflexively dismiss the popup underneath
-- without first acknowledging the warning.
frame:HookScript("OnShow", function()
    StaticPopupDialogs["DEATH"].noKeys = true
end)
frame:HookScript("OnHide", function()
    StaticPopupDialogs["DEATH"].noKeys = nil
end)

frame:SetScript("OnUpdate", function(self)
    if ns.testMode then return end -- don't auto-close in test mode
    local down = AnyEnabledModifierDown()

    -- "Was held on show" guard: applies to both modes. The user must
    -- release the modifier at least once before any new press/hold counts.
    if modifierWasHeldOnShow then
        if not down then modifierWasHeldOnShow = false end
        return
    end

    if DontReleaseDB.holdToClose then
        -- Hold mode: continuous hold for holdDuration dismisses the frame
        if down then
            if not holdStart then
                holdStart = GetTime()
                self.holdBar:Show()
            end
            local needed  = DontReleaseDB.holdDuration or 1.5
            local elapsed = GetTime() - holdStart
            local pct     = math.min(elapsed / needed, 1)
            self.holdBar:SetValue(pct)
            if elapsed >= needed then
                ResetHold()
                self:Hide()
            end
        else
            -- Released before completion; reset
            if holdStart then ResetHold() end
        end
    else
        -- Instant mode (original behavior): any new press dismisses
        if down then self:Hide() end
    end
end)

-- ---------------------------------------------------------------------
-- Public: apply settings to the visible frame
-- ---------------------------------------------------------------------
function ns.ApplyFrameSettings()
    local db = DontReleaseDB
    frame.title:SetText(db.text or defaults.text)
    frame.title:SetTextColor(db.color.r, db.color.g, db.color.b)
    frame.subtitle:SetText(db.subtitle or defaults.subtitle)

    -- Build hint string from enabled modifiers
    local mods = {}
    if db.modifiers.shift then table.insert(mods, "|cffffd200Shift|r") end
    if db.modifiers.ctrl  then table.insert(mods, "|cffffd200Ctrl|r")  end
    if db.modifiers.alt   then table.insert(mods, "|cffffd200Alt|r")   end
    local hint
    if #mods > 0 then
        if db.holdToClose then
            local secs = string.format("%.1fs", db.holdDuration or 1.5)
            hint = "Click |cffffd200X|r or hold " .. table.concat(mods, " / ")
                   .. " for |cffffd200" .. secs .. "|r to dismiss"
        else
            hint = "Click |cffffd200X|r or press " .. table.concat(mods, " / ") .. " to dismiss"
        end
    else
        hint = "Click |cffffd200X|r to dismiss"
    end
    frame.hint:SetText(hint)

    frame:SetScale(db.scale or 1.0)
end

-- Find the visible StaticPopup currently hosting the "DEATH" dialog, if any.
-- WoW reuses 4 popup slots, so the DEATH dialog can land at any index
-- depending on what other popups are queued.
local function FindDeathPopup()
    for i = 1, 4 do
        local popup = _G["StaticPopup" .. i]
        if popup and popup:IsShown() and popup.which == "DEATH" then
            return popup
        end
    end
    return nil
end

-- Size the warning frame to fully cover the death popup, with a margin so
-- the popup's edges don't peek out. The popup grows when Soulstone or
-- Reincarnation buttons are present, so a fixed size doesn't work.
local function ResizeToPopup(popup)
    if popup then
        local pw, ph = popup:GetWidth(), popup:GetHeight()
        if pw and ph and pw > 0 and ph > 0 then
            frame:SetSize(math.max(pw + POPUP_MARGIN_W, DEFAULT_W),
                          math.max(ph + POPUP_MARGIN_H, DEFAULT_H))
            return
        end
    end
    frame:SetSize(DEFAULT_W, DEFAULT_H)
end

local function RestorePosition(popup)
    frame:ClearAllPoints()
    local pos = DontReleaseDB.position
    if pos and pos.point then
        frame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x or 0, pos.y or 0)
        return
    end
    -- No user-saved position: anchor centered on the death popup if it's up,
    -- so the warning fully covers the "Release Spirit" dialog regardless of
    -- resolution / UI scale. Falls back to where StaticPopups typically
    -- appear (top-center) if the popup hasn't been built yet.
    popup = popup or FindDeathPopup()
    if popup then
        frame:SetPoint("CENTER", popup, "CENTER", 0, 0)
    else
        frame:SetPoint("TOP", UIParent, "TOP", 0, -100)
    end
end
ns.RestorePosition = RestorePosition

-- ---------------------------------------------------------------------
-- Wipe detection
-- ---------------------------------------------------------------------
local encounterFailed = false

local function CountDeadRaiders()
    if not IsInRaid() then
        -- In a 5-man party? Use party units. (Threshold-1 effectively.)
        local count = 0
        if UnitIsDeadOrGhost("player") then count = count + 1 end
        for i = 1, GetNumGroupMembers() - 1 do
            local unit = "party" .. i
            if UnitExists(unit) and UnitIsDeadOrGhost(unit) and UnitIsConnected(unit) then
                count = count + 1
            end
        end
        return count
    end
    local count = 0
    for i = 1, GetNumGroupMembers() do
        local unit = "raid" .. i
        if UnitExists(unit) and UnitIsDeadOrGhost(unit) and UnitIsConnected(unit) then
            count = count + 1
        end
    end
    return count
end

local function IsValidInstance()
    local _, instanceType = IsInInstance()
    if instanceType == "raid" then return true end
    if instanceType == "party" and DontReleaseDB.showInDungeons then return true end
    return false
end

-- ---------------------------------------------------------------------
-- Self-resurrection detection
-- ---------------------------------------------------------------------
local REINCARNATION_SPELL_ID = 20608

local function HasSoulstoneAvailable()
    if HasSoulstone then
        return HasSoulstone() and true or false
    end
    return false
end

local function HasReincarnationReady()
    local _, class = UnitClass("player")
    if class ~= "SHAMAN" then return false end

    if not C_SpellBook.IsSpellInSpellBook(REINCARNATION_SPELL_ID) then
        return false
    end

    local info = C_Spell.GetSpellCooldown(REINCARNATION_SPELL_ID)
    -- nil info means "could not query" — treat as not-ready rather than
    -- silently claiming ready and accidentally suppressing the warning.
    -- duration > 1.5 filters the GCD; anything longer is a real cooldown.
    if not info then return false end
    return not info.duration or info.duration <= 1.5
end

local function HasSelfResAvailable()
    if HasSoulstoneAvailable() then return true end
    if HasReincarnationReady() then return true end
    return false
end
ns.HasSelfResAvailable = HasSelfResAvailable

local function IsWipe()
    if not DontReleaseDB.enabled then return false end
    if not IsValidInstance() then return false end
    if not UnitIsDeadOrGhost("player") then return false end
    if DontReleaseDB.suppressOnSelfRes and HasSelfResAvailable() then return false end
    -- ENCOUNTER_END(success=0) is always honored — even if the user has
    -- turned off death-count triggers, a real boss wipe should warn.
    if encounterFailed then return true end
    if not DontReleaseDB.useDeathCountTrigger then return false end
    return CountDeadRaiders() >= (DontReleaseDB.wipeThreshold or 3)
end
ns.IsWipe = IsWipe

local function PlayAlertSound()
    local s = DontReleaseDB.sound
    if not s or not s.enabled then return end
    PlaySoundEntry(s.file, s.channel)
end
ns.PlayAlertSound = PlayAlertSound

local function TryShow()
    if not IsWipe() then return end
    local wasShown = frame:IsShown()
    local popup = FindDeathPopup()
    ResizeToPopup(popup)
    RestorePosition(popup)
    ns.ApplyFrameSettings()
    frame:Show()
    frame:Raise()
    if not wasShown then PlayAlertSound() end
end
ns.TryShow = TryShow

local function ScheduleWipeChecks()
    -- Immediate check: closes the Enter-to-release window when the raid was
    -- already wiped before the player's own death.
    TryShow()
    -- 0.3s re-check covers the sub-second window before the 1Hz poll's first
    -- tick, for raids that cascade just after the player's own death.
    C_Timer.After(0.3, TryShow)
end

-- 1Hz poll while the player is dead. Picks up where the 0.3s cascade tick
-- leaves off, so slow-cascading wipes (and trash-pull wipes that have no
-- ENCOUNTER_END to backstop) still trigger the warning. Self-cancels as
-- soon as the player is alive or the warning is already showing.
local wipePollTicker = nil

local function StopWipePoll()
    if wipePollTicker then
        wipePollTicker:Cancel()
        wipePollTicker = nil
    end
end

local function StartWipePoll()
    if wipePollTicker then return end
    if not UnitIsDeadOrGhost("player") then return end
    wipePollTicker = C_Timer.NewTicker(1.0, function()
        if not UnitIsDeadOrGhost("player") or frame:IsShown() then
            StopWipePoll()
            return
        end
        TryShow()
    end)
end

-- ---------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_DEAD")
eventFrame:RegisterEvent("PLAYER_ALIVE")
eventFrame:RegisterEvent("PLAYER_UNGHOST")
eventFrame:RegisterEvent("RESURRECT_REQUEST")
eventFrame:RegisterEvent("ENCOUNTER_START")
eventFrame:RegisterEvent("ENCOUNTER_END")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= addonName then return end
        DontReleaseDB = DontReleaseDB or {}
        MergeDefaults(DontReleaseDB, defaults)
        MigrateSaved(DontReleaseDB)
        ValidateRanges(DontReleaseDB)
        RestorePosition()
        ns.ApplyFrameSettings()
        ns.InitOptions()
        chatPrint("loaded. Type |cffffd200/dnr|r for commands.")

    elseif event == "PLAYER_DEAD" then
        ScheduleWipeChecks()
        StartWipePoll()

    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        ns.testMode = false
        encounterFailed = false
        StopWipePoll()
        frame:Hide()

    elseif event == "RESURRECT_REQUEST" then
        if DontReleaseDB.hideOnResRequest then
            frame:Hide()
        end

    elseif event == "ENCOUNTER_START" then
        encounterFailed = false

    elseif event == "ENCOUNTER_END" then
        local _, _, _, _, success = ...
        if success == 0 then
            encounterFailed = true
            C_Timer.After(0.3, TryShow)
            -- encounterFailed stays true until next ENCOUNTER_START,
            -- PLAYER_ALIVE, PLAYER_UNGHOST, or PLAYER_ENTERING_WORLD
        else
            encounterFailed = false
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- /reload while dead in a raid should restore the warning
        encounterFailed = false
        C_Timer.After(0.5, TryShow)
        StartWipePoll()  -- no-op if player isn't dead
    end
end)

-- ---------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------
SLASH_DONTRELEASE1 = "/dnr"
SLASH_DONTRELEASE2 = "/dontrelease"

SlashCmdList["DONTRELEASE"] = function(msg)
    local ok, err = pcall(function()
        msg = (msg or ""):lower():trim()
        local cmd, rest = msg:match("^(%S+)%s*(.-)$")
        cmd = cmd or ""

        if cmd == "" or cmd == "config" or cmd == "options" then
            ns.OpenOptions()

        elseif cmd == "test" then
            DontReleaseDB.locked = false
            ns.testMode = true
            encounterFailed = true
            RestorePosition()
            ns.ApplyFrameSettings()
            frame:Show()
            frame:Raise()
            chatPrint("test mode - drag to reposition, click |cffffd200X|r to lock.")

        elseif cmd == "toggle" then
            DontReleaseDB.enabled = not DontReleaseDB.enabled
            chatPrint(DontReleaseDB.enabled and "|cff00ff00enabled|r" or "|cffff0000disabled|r")
            ns.RefreshOptions()

        elseif cmd == "lock" then
            DontReleaseDB.locked = true
            ns.testMode = false
            chatPrint("frame |cffff0000locked|r.")

        elseif cmd == "unlock" then
            DontReleaseDB.locked = false
            chatPrint("frame |cff00ff00unlocked|r - drag to move.")

        elseif cmd == "reset" then
            if rest == "all" then
                DontReleaseDB = nil
                ReloadUI()
            else
                DontReleaseDB.position = nil
                RestorePosition()
                chatPrint("position reset.")
            end

        elseif cmd == "scale" then
            local v = tonumber(rest)
            if v and v >= 0.5 and v <= 3 then
                DontReleaseDB.scale = v
                ns.ApplyFrameSettings()
                chatPrint("scale set to " .. v)
            else
                chatPrint("scale must be 0.5 - 3.0")
            end

        elseif cmd == "threshold" then
            local v = tonumber(rest)
            if v and v >= 1 and v <= 30 then
                DontReleaseDB.wipeThreshold = math.floor(v)
                chatPrint("wipe threshold: " .. math.floor(v) .. " dead raiders.")
                ns.RefreshOptions()
            else
                chatPrint("threshold must be 1 - 30")
            end

        elseif cmd == "sound" then
            DontReleaseDB.sound.enabled = not DontReleaseDB.sound.enabled
            chatPrint("sound " ..
                      (DontReleaseDB.sound.enabled and "|cff00ff00on|r" or "|cffff0000off|r"))

        elseif cmd == "hide" then
            frame:Hide()

        elseif cmd == "status" then
            chatPrint("status:")
            print("  enabled:         " .. tostring(DontReleaseDB.enabled))
            print("  death-count trigger: " .. tostring(DontReleaseDB.useDeathCountTrigger))
            print("  threshold:       " .. DontReleaseDB.wipeThreshold .. " dead raiders")
            print("  show in 5-man:   " .. tostring(DontReleaseDB.showInDungeons))
            print("  suppress on res: " .. tostring(DontReleaseDB.suppressOnSelfRes))
            print("  scale:           " .. DontReleaseDB.scale)
            print("  sound:           " .. tostring(DontReleaseDB.sound.enabled))
            local _, t = IsInInstance()
            print("  current zone:    " .. tostring(t))
            print("  dead raiders:    " .. CountDeadRaiders())
            print("  self-res avail:  " .. tostring(HasSelfResAvailable()) ..
                  " (soulstone=" .. tostring(HasSoulstoneAvailable()) ..
                  ", reincarnate=" .. tostring(HasReincarnationReady()) .. ")")

        else
            chatPrint("commands:")
            print("  |cffffd200/dnr|r              open options")
            print("  |cffffd200/dnr test|r         preview & reposition")
            print("  |cffffd200/dnr toggle|r       enable/disable")
            print("  |cffffd200/dnr lock|r / |cffffd200unlock|r  lock/unlock the frame")
            print("  |cffffd200/dnr scale 1.5|r    set frame scale (0.5-3.0)")
            print("  |cffffd200/dnr threshold 3|r  set dead-raider threshold")
            print("  |cffffd200/dnr sound|r        toggle sound")
            print("  |cffffd200/dnr reset|r        reset position")
            print("  |cffffd200/dnr reset all|r    wipe ALL settings")
            print("  |cffffd200/dnr status|r       print current settings")
        end
    end)
    if not ok then
        chatPrint("slash error: " .. tostring(err))
        chatPrint("please report this in chat or as a bug.")
    end
end

-- ---------------------------------------------------------------------
-- Addon compartment hooks (the dropdown next to the minimap that lists
-- installed addons). Wired up via the AddonCompartmentFunc* TOC fields.
--
-- Known harmless quirk: when DontRelease is DISABLED, the client never
-- loads this file, so these globals are never defined -- yet the client
-- still builds a compartment entry from the TOC metadata. Hovering that
-- entry then looks up _G["DontRelease_OnCompartmentEnter"], finds nil,
-- and (on 12.0 beta builds) throws "attempt to call a nil value" in
-- Blizzard_Minimap/AddonCompartment.lua instead of nil-checking first.
-- This is a client-side bug, NOT ours: nothing here can guard against it
-- because none of this Lua runs while the addon is disabled. With the
-- addon enabled (its normal state) the handlers exist and hovering works.
-- ---------------------------------------------------------------------
function DontRelease_OnCompartmentClick(_, button)
    if button == "RightButton" then
        DontReleaseDB.enabled = not DontReleaseDB.enabled
        chatPrint(DontReleaseDB.enabled and "|cff00ff00enabled|r" or "|cffff0000disabled|r")
    else
        ns.OpenOptions()
    end
end

function DontRelease_OnCompartmentEnter(_, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText("DontRelease", 1, 0.2, 0.2)
    GameTooltip:AddLine(DontReleaseDB.enabled and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r", 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffffd200Left-click:|r options", 1, 1, 1)
    GameTooltip:AddLine("|cffffd200Right-click:|r toggle enabled", 1, 1, 1)
    GameTooltip:Show()
end

function DontRelease_OnCompartmentLeave()
    GameTooltip:Hide()
end
