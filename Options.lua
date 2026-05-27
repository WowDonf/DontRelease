-- =====================================================================
-- DontRelease - Options panel (Scrollable canvas)
-- =====================================================================
-- Canvas categories DO NOT clip or scroll their content. A ScrollFrame
-- inside the canvas does. Pattern mirrors OutOfRange/Options.lua.
-- =====================================================================
local _, ns = ...

-- ---------------------------------------------------------------------
-- Panel + scroll container
-- ---------------------------------------------------------------------
local panel = CreateFrame("Frame", "DontReleaseOptionsPanel")
panel.name = "DontRelease"

local scroll = CreateFrame("ScrollFrame", "DontReleaseOptionsScroll", panel, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 10, -10)
scroll:SetPoint("BOTTOMRIGHT", -30, 10)

local content = CreateFrame("Frame", nil, scroll)
content:SetSize(580, 100)
scroll:SetScrollChild(content)
scroll:SetScript("OnSizeChanged", function(_, w)
    if w and w > 0 then content:SetWidth(w) end
end)

-- ---------------------------------------------------------------------
-- Layout helpers (running y cursor pattern)
-- ---------------------------------------------------------------------
local LEFT = 18
local y = -14
local widgets = {}

local function AddHeader(text)
    y = y - 8
    local fs = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", LEFT, y)
    fs:SetText(text)
    fs:SetTextColor(1, 0.82, 0)
    y = y - 22
    local line = content:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 0.12)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", LEFT, y)
    line:SetPoint("TOPRIGHT", -18, y)
    y = y - 12
end

local function AddDescription(text)
    local fs = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    fs:SetPoint("TOPLEFT", LEFT, y)
    fs:SetWidth(520)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    y = y - (fs:GetStringHeight() + 10)
end

local function AddCheckbox(label, getter, setter)
    local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", LEFT, y)
    cb:SetSize(26, 26)
    local fs = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    fs:SetText(label)
    cb:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false) end)
    cb.Refresh = function() cb:SetChecked(getter() and true or false) end
    widgets[#widgets + 1] = cb
    y = y - 30
    return cb
end

local function AddSlider(label, minV, maxV, step, fmt, getter, setter)
    y = y - 4
    local title = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("TOPLEFT", LEFT, y)
    title:SetText(label)
    local valFS = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    y = y - 18

    local s = CreateFrame("Slider", nil, content)
    s:SetPoint("TOPLEFT", LEFT + 4, y)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(360, 18)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local thumb = s:GetThumbTexture()
    if thumb then thumb:SetSize(20, 20) end
    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0, 0, 0, 0.45)
    track:SetHeight(6)
    track:SetPoint("LEFT", 4, 0)
    track:SetPoint("RIGHT", -4, 0)
    valFS:SetPoint("LEFT", s, "RIGHT", 14, 0)
    s:SetScript("OnValueChanged", function(_, v)
        local stepped = math.floor((v / step) + 0.5) * step
        valFS:SetText(fmt and string.format(fmt, stepped) or tostring(stepped))
        setter(stepped)
    end)
    s.Refresh = function()
        local v = getter() or minV
        s:SetValue(v)
        valFS:SetText(fmt and string.format(fmt, v) or tostring(v))
    end
    widgets[#widgets + 1] = s
    y = y - 32
    return s
end

local function AddEditBox(label, width, getter, setter)
    local title = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("TOPLEFT", LEFT, y)
    title:SetText(label)
    y = y - 20

    local eb = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    eb:SetPoint("TOPLEFT", LEFT + 6, y)
    eb:SetSize(width or 320, 22)
    eb:SetAutoFocus(false)
    eb:SetFontObject("ChatFontNormal")
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus(); setter(self:GetText()) end)
    eb:SetScript("OnEditFocusLost", function(self) setter(self:GetText()) end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus(); if self.Refresh then self.Refresh() end end)
    eb.Refresh = function() eb:SetText(getter() or ""); eb:SetCursorPosition(0) end
    widgets[#widgets + 1] = eb
    y = y - 32
    return eb
end

local function AddDropdown(label, width)
    local title = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("TOPLEFT", LEFT, y)
    title:SetText(label)
    y = y - 22
    local dd = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
    dd:SetPoint("TOPLEFT", LEFT + 6, y)
    dd:SetSize(width or 280, 30)
    y = y - 40
    return dd
end

local function AddButton(label, width, onClick)
    local b = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    b:SetPoint("TOPLEFT", LEFT + 6, y)
    b:SetSize(width or 160, 24)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    y = y - 32
    return b
end

local function AddSideBySideButtons(...)
    local args = {...}
    local count = #args / 2
    local x = LEFT + 6
    for i = 1, count do
        local label = args[(i - 1) * 2 + 1]
        local onClick = args[(i - 1) * 2 + 2]
        local b = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        b:SetPoint("TOPLEFT", x, y)
        b:SetSize(180, 24)
        b:SetText(label)
        b:SetScript("OnClick", onClick)
        x = x + 188
    end
    y = y - 32
end

local function AddGap(px)
    y = y - (px or 10)
end

-- ---------------------------------------------------------------------
-- Title / subtitle
-- ---------------------------------------------------------------------
local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
title:SetPoint("TOPLEFT", LEFT, y)
title:SetText("DontRelease")
y = y - 22

local subtitle = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", LEFT, y)
subtitle:SetText("Warning overlay for raid wipes.")
y = y - 14

-- ---------------------------------------------------------------------
-- General
-- ---------------------------------------------------------------------
AddHeader("General")

AddCheckbox("Enable DontRelease",
    function() return DontReleaseDB.enabled end,
    function(v) DontReleaseDB.enabled = v end)
AddCheckbox("Also show in 5-man dungeons",
    function() return DontReleaseDB.showInDungeons end,
    function(v) DontReleaseDB.showInDungeons = v end)
AddCheckbox("Hide on battle res request",
    function() return DontReleaseDB.hideOnResRequest end,
    function(v) DontReleaseDB.hideOnResRequest = v end)
AddCheckbox("Hide when self-res is available (Soulstone, Reincarnation)",
    function() return DontReleaseDB.suppressOnSelfRes end,
    function(v) DontReleaseDB.suppressOnSelfRes = v end)

-- Forward-declare so the checkbox setter (defined just below) can toggle
-- the slider's enabled state when the user flips the checkbox.
local thresholdSlider

AddCheckbox("Trigger when enough raid members are dead",
    function() return DontReleaseDB.useDeathCountTrigger end,
    function(v)
        DontReleaseDB.useDeathCountTrigger = v
        if thresholdSlider then thresholdSlider:SetEnabled(v) end
    end)
AddDescription("If disabled, the warning only fires on boss-encounter wipes (ENCOUNTER_END). " ..
    "Useful if you only want notifications on actual boss attempt failures and not on cascading deaths during trash or progression pulls.")

thresholdSlider = AddSlider("Wipe threshold (dead raid members)", 1, 30, 1, "%d dead",
    function() return DontReleaseDB.wipeThreshold end,
    function(v) DontReleaseDB.wipeThreshold = v end)

-- Wrap the slider's Refresh so that opening the Settings panel also
-- syncs the slider's enabled state with the checkbox.
local origThresholdRefresh = thresholdSlider.Refresh
thresholdSlider.Refresh = function()
    origThresholdRefresh()
    thresholdSlider:SetEnabled(DontReleaseDB.useDeathCountTrigger)
end

-- ---------------------------------------------------------------------
-- Appearance
-- ---------------------------------------------------------------------
AddHeader("Appearance")

local titleBox = AddEditBox("Title text", 320,
    function() return DontReleaseDB.text end,
    function(v) DontReleaseDB.text = v; ns.ApplyFrameSettings() end)

-- Color button on the same line as Title text input
local colorBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
colorBtn:SetPoint("LEFT", titleBox, "RIGHT", 12, 0)
colorBtn:SetSize(100, 22)
colorBtn:SetText("Color...")

local swatch = colorBtn:CreateTexture(nil, "OVERLAY")
swatch:SetSize(14, 14)
swatch:SetPoint("LEFT", colorBtn, "LEFT", 8, 0)
colorBtn.swatch = swatch

-- Anchor the button text to the right of the swatch so they can't overlap.
-- UIPanelButtonTemplate centers in the full button width by default, which
-- pushes the left edge of the text under the swatch.
local colorBtnText = colorBtn:GetFontString()
if colorBtnText then
    colorBtnText:ClearAllPoints()
    colorBtnText:SetPoint("LEFT", swatch, "RIGHT", 4, 0)
    colorBtnText:SetPoint("RIGHT", colorBtn, "RIGHT", -8, 0)
end

colorBtn:SetScript("OnClick", function()
    local r, g, b = DontReleaseDB.color.r, DontReleaseDB.color.g, DontReleaseDB.color.b
    local function apply(prev)
        local nr, ng, nb
        if prev then
            nr = prev.r or prev[1]
            ng = prev.g or prev[2]
            nb = prev.b or prev[3]
        else
            nr, ng, nb = ColorPickerFrame:GetColorRGB()
        end
        if not (nr and ng and nb) then return end
        DontReleaseDB.color.r, DontReleaseDB.color.g, DontReleaseDB.color.b = nr, ng, nb
        swatch:SetColorTexture(nr, ng, nb)
        ns.ApplyFrameSettings()
    end
    ColorPickerFrame:SetupColorPickerAndShow({
        r = r, g = g, b = b,
        swatchFunc = function() apply() end,
        cancelFunc = function(prev) apply(prev) end,
        hasOpacity = false,
    })
end)
colorBtn.Refresh = function()
    swatch:SetColorTexture(DontReleaseDB.color.r, DontReleaseDB.color.g, DontReleaseDB.color.b)
end
widgets[#widgets + 1] = colorBtn

AddEditBox("Subtitle text", 440,
    function() return DontReleaseDB.subtitle end,
    function(v) DontReleaseDB.subtitle = v; ns.ApplyFrameSettings() end)

AddSlider("Frame scale", 0.5, 3.0, 0.05, "%.2fx",
    function() return DontReleaseDB.scale end,
    function(v) DontReleaseDB.scale = v; ns.ApplyFrameSettings() end)

AddSideBySideButtons(
    "Test / Reposition frame", function()
        DontReleaseDB.locked = false
        ns.testMode = true
        ns.RestorePosition()
        ns.ApplyFrameSettings()
        ns.frame:Show()
        ns.frame:Raise()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    end,
    "Reset position", function()
        DontReleaseDB.position = nil
        ns.RestorePosition()
    end)

-- ---------------------------------------------------------------------
-- Close behavior
-- ---------------------------------------------------------------------
AddHeader("Close behavior")
AddDescription("Pressing one of these modifiers (after the frame appears) will dismiss it. Enable hold-to-close below to require a deliberate hold instead of a single press.")

AddCheckbox("Shift",
    function() return DontReleaseDB.modifiers.shift end,
    function(v) DontReleaseDB.modifiers.shift = v; ns.ApplyFrameSettings() end)
AddCheckbox("Ctrl",
    function() return DontReleaseDB.modifiers.ctrl end,
    function(v) DontReleaseDB.modifiers.ctrl = v; ns.ApplyFrameSettings() end)
AddCheckbox("Alt",
    function() return DontReleaseDB.modifiers.alt end,
    function(v) DontReleaseDB.modifiers.alt = v; ns.ApplyFrameSettings() end)

AddCheckbox("Require holding the modifier (prevents accidental dismissal)",
    function() return DontReleaseDB.holdToClose end,
    function(v) DontReleaseDB.holdToClose = v; ns.ApplyFrameSettings() end)

AddSlider("Hold duration", 0.5, 5.0, 0.1, "%.1fs",
    function() return DontReleaseDB.holdDuration end,
    function(v) DontReleaseDB.holdDuration = v; ns.ApplyFrameSettings() end)

-- ---------------------------------------------------------------------
-- Sound
-- ---------------------------------------------------------------------
AddHeader("Sound")

AddCheckbox("Play sound when warning appears",
    function() return DontReleaseDB.sound.enabled end,
    function(v) DontReleaseDB.sound.enabled = v end)

local soundDropdown = AddDropdown("Sound", 280)
soundDropdown:SetDefaultText("Choose a sound")
soundDropdown:SetupMenu(function(_, root)
    for _, item in ipairs(ns.SOUNDS) do
        local key = item.key
        root:CreateRadio(item.label,
            function() return DontReleaseDB and DontReleaseDB.sound and DontReleaseDB.sound.file == key end,
            function()
                if not (DontReleaseDB and DontReleaseDB.sound) then return end
                DontReleaseDB.sound.file = key
                ns.PlaySoundEntry(key, DontReleaseDB.sound.channel)
                C_Timer.After(0, function() soundDropdown:GenerateMenu() end)
            end)
    end
end)
soundDropdown.Refresh = function() soundDropdown:GenerateMenu() end
widgets[#widgets + 1] = soundDropdown

local channelDropdown = AddDropdown("Audio channel", 200)
channelDropdown:SetDefaultText("Choose a channel")
channelDropdown:SetupMenu(function(_, root)
    for _, c in ipairs(ns.CHANNELS) do
        local key = c
        root:CreateRadio(key,
            function() return DontReleaseDB and DontReleaseDB.sound and DontReleaseDB.sound.channel == key end,
            function()
                if not (DontReleaseDB and DontReleaseDB.sound) then return end
                DontReleaseDB.sound.channel = key
                C_Timer.After(0, function() channelDropdown:GenerateMenu() end)
            end)
    end
end)
channelDropdown.Refresh = function() channelDropdown:GenerateMenu() end
widgets[#widgets + 1] = channelDropdown

AddButton("Play test sound", 160, function()
    local snd = DontReleaseDB and DontReleaseDB.sound
    if not snd then return end
    ns.PlaySoundEntry(snd.file, snd.channel)
end)

AddGap(16)

-- Lock the content height so the scrollbar appears when content overflows.
content:SetHeight(-y + 20)

-- ---------------------------------------------------------------------
-- Refresh + show hooks
-- ---------------------------------------------------------------------
local function RefreshAll()
    if not DontReleaseDB then return end
    for _, w in ipairs(widgets) do
        if w.Refresh then w.Refresh() end
    end
end
ns.RefreshOptions = RefreshAll

panel:SetScript("OnShow", RefreshAll)

-- ---------------------------------------------------------------------
-- Register with Settings
-- ---------------------------------------------------------------------
local category
if Settings and Settings.RegisterCanvasLayoutCategory then
    category = Settings.RegisterCanvasLayoutCategory(panel, "DontRelease")
    Settings.RegisterAddOnCategory(category)
end

function ns.InitOptions() RefreshAll() end

function ns.OpenOptions()
    if not category then return end
    RefreshAll()
    C_Timer.After(0, function()
        Settings.OpenToCategory(category:GetID())
    end)
end
