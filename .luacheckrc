-- Luacheck configuration for DontRelease.
-- Run from repo root: luacheck *.lua

std = "lua51"

-- WoW addon UI strings often need to fit a single readable line.
max_line_length = 200

-- Globals the addon defines, owns, or writes to.
globals = {
    -- Saved variables (managed by WoW from the TOC's SavedVariables field)
    "DontReleaseDB",
    -- Slash command registration
    "SLASH_DONTRELEASE1",
    "SLASH_DONTRELEASE2",
    -- Addon compartment hooks (must be globals; referenced from the TOC's
    -- AddonCompartmentFunc* fields)
    "DontRelease_OnCompartmentClick",
    "DontRelease_OnCompartmentEnter",
    "DontRelease_OnCompartmentLeave",
    -- Blizzard tables we mutate
    "StaticPopupDialogs",  -- noKeys flip on the death popup
    "SlashCmdList",        -- /dnr handler registration
}

-- Blizzard / WoW API globals the addon only reads from.
read_globals = {
    -- Frame + UI infrastructure
    "CreateFrame", "UIParent",
    "Settings", "SettingsPanel", "HideUIPanel",
    "ColorPickerFrame",
    "GameTooltip",
    -- Sound
    "PlaySound", "PlaySoundFile", "SOUNDKIT",
    -- Timing
    "GetTime", "C_Timer",
    -- Modifier key state
    "IsShiftKeyDown", "IsControlKeyDown", "IsAltKeyDown",
    -- Group / instance state
    "IsInRaid", "IsInInstance", "GetNumGroupMembers",
    -- Unit state
    "UnitIsDeadOrGhost", "UnitExists", "UnitIsConnected", "UnitClass",
    -- Spells / self-res
    "C_SpellBook", "C_Spell", "HasSoulstone",
    -- UI control
    "ReloadUI",
}
