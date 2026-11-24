local M = Mock
local toc = assert(io.open(ADDON_ROOT .. "/Sintezza_Manager.toc", "r"))
local version = assert(toc:read("*a"):match("## Version:%s*([^%s]+)"))
toc:close()
local methods = getmetatable(UIParent).__index
function methods:SetEnabled(enabled) if enabled then self:Enable() else self:Disable() end end
function methods:SetCheckedTexture(texture) self.checkTexture = texture end
function methods:SetDesaturated(value) self.desaturated = value end
local missingIcon = "Interface\\AddOns\\Missing\\Icon"
local knownAtlas = "gmchat-icon-blizz"
function methods:SetTexture(texture)
    if texture == missingIcon then return false end
    self.texture, self.atlas = texture, nil
    return texture ~= nil
end
function methods:SetAtlas(atlas, useAtlasSize)
    assert(atlas == knownAtlas and not useAtlasSize)
    self.texture, self.atlas = nil, atlas
    self:SetTexCoord(.2, .3, .4, .5)
end
C_Texture = {GetAtlasInfo = function(atlas) if atlas == knownAtlas then return {} end end}
function methods:SetMaxLines(lines) self.maxLines = lines end
function methods:UpdateScrollChildRect() end
function methods:EnableMouseMotion() end
function methods:Raise() end
function methods:GetEffectiveScale() return self:GetScale() end
function methods:GetNumPoints() return #self.points end
function methods:GetPoint(index) return unpack(self.points[index]) end
function methods:GetLeft() return self == UIParent and 0 or 250 end
function methods:GetTop() return self == UIParent and 1080 or 800 end
function methods:GetBottom() return self:GetTop() - self:GetHeight() end
function methods:SetResizable(value) self.resizable = value end
function methods:SetResizeBounds(...) self.resizeBounds = {...} end
function methods:SetHitRectInsets(...) self.hitInsets = {...} end
function methods:StartSizing(point)
    assert(self.resizable and not InCombatLockdown())
    self.sizing = point
end
local cursorX, cursorY = 1000, 300
function GetCursorPosition() return cursorX, cursorY end
function GetScreenWidth() return 1920 end
function GetScreenHeight() return 1080 end
function GetBuildInfo() return "1.60.1", "70959", "", 16001 end
function GetRealmName() return "Forever" end
function HideUIPanel(frame) frame:Hide() end
function hooksecurefunc(frame, key, after)
    local original = frame[key]
    frame[key] = function(...)
        local result = original(...)
        after(...)
        return result
    end
end

local russian = (THEME_LOCALE or TEST_LOCALE) == "ruRU"
local menuEntries, menuScrollLimit
MenuUtil = {
    CreateContextMenu = function(owner, build)
        menuEntries = {}
        local root = {}
        function root:CreateTitle(title) self.title = title end
        function root:CreateButton(label, action) menuEntries[label] = action end
        function root:SetScrollMode(limit) menuScrollLimit = limit end
        function root:CreateRadio(label, _, action, value) menuEntries[label] = function() action(value) end end
        build(owner, root)
        return root
    end,
}
if THEME_LOCALE then
    M.installTheme()
    local shared = Sintezza_Theme
    shared.Settings.panelHover = shared.Settings.panel
    shared.Settings.dim = shared.Settings.muted
    function shared.Settings:SkinCheckButton(button, markSize)
        button.themeCheckbox = true
        button.themeMarkSize = markSize
        self:Backdrop(button, self.input, self.lineSoft)
    end
    function shared.Settings:DisclosureArrow(owner, size, palette)
        local arrow = self:Glyph(owner, "chevron", size, palette)
        function arrow:SetExpanded(expanded) self.expanded = expanded end
        return arrow
    end
    function shared.Settings:RowBand(row)
        local band = row:CreateTexture(nil, "BACKGROUND")
        band:SetAllPoints()
        band:SetColorTexture(.85, .63, .45, .04)
        return band
    end
    function shared.Settings:MenuHighlight(row)
        local hover = row:CreateTexture(nil, "BACKGROUND")
        hover:SetAllPoints()
        hover:SetColorTexture(unpack(self.accentDim))
        hover:Hide()
        row.themeHover = hover
        return hover
    end
    function shared.Settings:Glow() end
    function shared.Settings:MenuBackdrop(picker) self:Backdrop(picker, self.bg, self.line) end
    function shared:GetLocale() return THEME_LOCALE end
    local create = shared.CreateWidgets
    function shared:CreateWidgets(...)
        local widgets = create(self, ...)
        if not widgets.originalScroll then
            widgets.originalScroll = widgets.ScrollFrame
            function widgets:ScrollFrame(parent, body, step)
                return self:originalScroll(parent, body or CreateFrame("Frame"), step)
            end
            local header = widgets.WindowHeader
            function widgets:WindowHeader(parent, options)
                local frame = header(self, parent, options)
                if options.version then
                    frame.version = self:Label(frame, "v" .. options.version, 9, shared.Settings.muted)
                    frame.version:SetPoint("LEFT", frame.title, "RIGHT", 10, -1)
                end
                return frame
            end
        end
        return widgets
    end
    Sintezza_ThemeDB = {windowDefaults = {}}
    assert(loadfile(ADDON_ROOT .. "/../Sintezza_Theme/WindowOptions.lua"))("Sintezza_Theme", shared)
    assert(loadfile(ADDON_ROOT .. "/../Sintezza_Theme/Picker.lua"))("Sintezza_Theme", shared)
end

local fixtures = {
    {id = "Sintezza_Manager", title = "Sintezza Addons Manager"},
    {id = "Sintezza_Theme", title = "Sintezza Theme"},
    {id = "A_LittleWigs", title = "LittleWigs", needs = {"Z_BigWigs"}, category = "Combat"},
    {id = "Z_BigWigs", title = "BigWigs", category = "Combat"},
    {id = "Vendor", title = "|cffffffffТорговец|r", needs = {"Sintezza_Theme"}, category = "Trade"},
    {id = "Disenchant", title = "Disenchant", needs = {"Sintezza_Theme"}, category = "Trade"},
    {id = "Broken", title = "Missing dependency", needs = {"Absent"}},
    {id = "NewAddon", title = "New Addon"},
    {id = "Blizzard_Sample", title = "Blizzard Sample", security = "SECURE"},
    {id = "EllesmereUI", title = "EllesmereUI"},
    {id = "EllesmereUIActionBars", title = "EllesmereUI Action Bars", group = "EllesmereUI", needs = {"EllesmereUI"}, category = "EllesmereUI"},
    {id = "EllesmereUIBags", title = "EllesmereUI Bags", group = "EllesmereUI", needs = {"EllesmereUI"}, category = "EllesmereUI"},
    {id = "EllesmereUIChat", title = "EllesmereUI Chat", group = "EllesmereUI", needs = {"EllesmereUI"}, category = "EllesmereUI"},
    {id = "EllesmereUIOptions", title = "EllesmereUI Options", group = "EllesmereUI", needs = {"EllesmereUI"}, category = "Utilities"},
    {id = "EllesmereUIRaidFrames", title = "EllesmereUI Raid & Party Frames", needs = {"EllesmereUI"}, category = "EllesmereUI"},
}
local indexed = {}
for _, row in ipairs(fixtures) do indexed[row.id] = row end
local groupIcon = "Interface\\AddOns\\EllesmereUI\\media\\eg-logo.tga"
indexed.EllesmereUI.IconTexture = groupIcon
indexed.EllesmereUIBags.IconAtlas = " " .. knownAtlas .. " "
indexed.EllesmereUIActionBars.IconTexture = "133742"
indexed.EllesmereUIActionBars.IconAtlas = knownAtlas
indexed.EllesmereUIRaidFrames.IconTexture = missingIcon
indexed.EllesmereUIRaidFrames.IconAtlas = knownAtlas
indexed.EllesmereUIChat.IconAtlas = "MissingAtlas"
indexed.NewAddon.IconTexture = " "
local function Addon(value) return assert(fixtures[value] or indexed[value]) end
local function Initial()
    return {
        Sintezza_Manager = true, Sintezza_Theme = true, Blizzard_Sample = true, NewAddon = true,
        EllesmereUI = true, EllesmereUIActionBars = true, EllesmereUIOptions = true,
    }
end
local states = {Mira = Initial(), Alden = Initial(), Unlinked = Initial()}
local who = "Mira"
function UnitGUID() return who end
function UnitName() return who end
Enum = {AddOnEnableState = {None = 0, Some = 1, All = 2}}
local writes, saves, reloads = {}, 0, 0
local failWrite, failSave
local versionCheck, versionWrites, failVersionWrite = true, 0, false
local function Write(id, guid, enabled)
    assert(guid == who and not InCombatLockdown(), "write must be for the current character and outside combat")
    assert(id ~= "Sintezza_Manager" and id ~= "Blizzard_Sample", "manager and native addons are protected")
    writes[#writes + 1] = id
    if failWrite == id then failWrite = nil; error("failed setter") end
    states[guid][id] = enabled
end
C_AddOns = {
    GetNumAddOns = function() return #fixtures end,
    GetAddOnInfo = function(index)
        local row = Addon(index)
        local reason = versionCheck and row.interface == 16000 and "INTERFACE_VERSION" or nil
        return row.id, row.title, nil, reason == nil, reason, row.security or "INSECURE"
    end,
    GetAddOnInterfaceVersion = function(index) return Addon(index).interface or 16001 end,
    IsAddonVersionCheckEnabled = function() return versionCheck end,
    SetAddonVersionCheck = function(checked)
        assert(not InCombatLockdown() and type(checked) == "boolean")
        versionWrites = versionWrites + 1
        versionCheck = checked
        if failVersionWrite then failVersionWrite = false; error("partial version change") end
    end,
    GetAddOnMetadata = function(index, key)
        if key == "Version" and index == "Sintezza_Manager" then return version end
        local row = Addon(index)
        if key == "Category" then return row.category end
        if key == "Group" then return row.group end
        return row[key]
    end,
    GetAddOnDependencies = function(index) return unpack(Addon(index).needs or {}) end,
    GetAddOnEnableState = function(id, guid)
        assert(guid == who, "reads must be for the current character")
        return states[guid][Addon(id).id] and 2 or 0
    end,
    EnableAddOn = function(id, guid) Write(id, guid, true) end,
    DisableAddOn = function(id, guid) Write(id, guid, false) end,
    SaveAddOns = function()
        saves = saves + 1
        if failSave then failSave = nil; error("save failed") end
    end,
}
function ReloadUI() reloads = reloads + 1 end

ADDONS = TEST_LOCALE == "ruRU" and "Модификации" or "AddOns"
SOUNDKIT = {IG_MAINMENU_OPTION = 1}
function PlaySound() end
GameMenuFrame = CreateFrame("Frame")
local menuButtons = {}
function GameMenuFrame:AddButton(text, action)
    local index = #self.buttons + 1
    local button = menuButtons[index] or CreateFrame("Button", nil, self)
    menuButtons[index] = button
    button:SetText(text)
    button:SetScript("OnClick", action)
    button:Enable()
    self.buttons[index] = button
    button.layoutIndex = index
    return button
end
function GameMenuFrame:InitButtons()
    self.buttons = {}
    self:AddButton("Options", function() end)
    self:AddButton(ADDONS, function() self.nativeClicked = true end)
    self.buttons[2]:SetEnabled(not self.lockAddons)
    self:AddButton("Return", function() end)
end
AddonList = CreateFrame("Frame")
AddonList:Hide()
local categories, added = 0, 0
Settings = {
    RegisterCanvasLayoutCategory = function(panel, title)
        categories = categories + 1
        return {panel = panel, title = title}
    end,
    RegisterAddOnCategory = function(record)
        assert(record.title == "Sintezza Addons Manager")
        added = added + 1
    end,
}
local ns = {}
local addonAPI, fallback = C_AddOns, {}
C_AddOns = nil
assert(loadfile(ADDON_ROOT .. "/Locale.lua"))("Sintezza_Manager", fallback)
C_AddOns = addonAPI
assert(fallback.version == version)
for _, file in ipairs({"Locale.lua", "Core.lua", "Style.lua", "WindowSize.lua", "Window.lua", "Launcher.lua"}) do
    assert(loadfile(ADDON_ROOT .. "/" .. file))("Sintezza_Manager", ns)
end
Sintezza_ManagerDB = {
    profiles = {
        Shared = {A_LittleWigs = false, Z_BigWigs = false, Uninstalled = true, Invalid = "bad"},
        ZLegacy = {Vendor = true},
    },
    links = {
        Mira = {profile = "ZLegacy", name = "Mira — Forever"},
        Alden = {profile = "ZLegacy", name = "Alden — Forever"},
    },
}
M.event("ADDON_LOADED", "Sintezza_Manager")
M.event("ADDON_LOADED", "AnythingElse")
M.event("PLAYER_LOGIN")
assert(categories == 1 and added == 1)
assert(ns.ru == russian and ns.Fold("ТОРГОВЕЦ") == "торговец")
assert(ns.db.profiles.Shared.a_littlewigs == false and ns.db.profiles.Shared.invalid == nil)
assert(ns.db.links.Mira.profile == "ZLegacy" and not states.Mira.Vendor and #writes == 0)

GameMenuFrame:InitButtons()
GameMenuFrame:InitButtons()
assert(#GameMenuFrame.buttons == 3)
assert(GameMenuFrame.buttons[2]:GetText() == ADDONS and GameMenuFrame.buttons[2].layoutIndex == 2)
C_AddOns = nil
GameMenuFrame.buttons[2]:Click()
assert(GameMenuFrame.nativeClicked and not SintezzaManagerWindow)
C_AddOns = addonAPI
GameMenuFrame.nativeClicked = nil
M.combat = true
GameMenuFrame.buttons[2]:Click()
assert(GameMenuFrame.nativeClicked and not SintezzaManagerWindow)
GameMenuFrame.nativeClicked = nil
GameMenuFrame:InitButtons()
GameMenuFrame.buttons[2]:Click()
assert(GameMenuFrame.nativeClicked and not SintezzaManagerWindow)
M.combat = false
GameMenuFrame.nativeClicked = nil
GameMenuFrame.lockAddons = true
GameMenuFrame:InitButtons()
GameMenuFrame.buttons[2]:Click()
assert(not GameMenuFrame.nativeClicked and not SintezzaManagerWindow)
GameMenuFrame.lockAddons = false
GameMenuFrame:InitButtons()
GameMenuFrame:Show()
GameMenuFrame.buttons[2]:Click()
assert(not GameMenuFrame.nativeClicked and not GameMenuFrame:IsShown() and SintezzaManagerWindow:IsShown())
M.layout()
local frame = SintezzaManagerWindow
assert(frame.search ~= nil and frame.apply.text:GetText() == (russian and "Применить" or "Apply"))
assert(frame.cancel.text:GetText() == (russian and "Отменить" or "Cancel"))
assert(not frame.apply:IsShown() and not frame.cancel:IsShown())
assert(not not frame.themeSurface == not not THEME_LOCALE)
assert(frame.header.title:GetText() == "Sintezza Addons Manager")
assert(frame.header.version:GetText() == "v" .. version)
assert(frame.header.version.points[1][2] == frame.header.title)
assert(not THEME_LOCALE or frame.profiles.details.themeSurface == "sidebar")
assert(frame.quick:IsVisible() and frame.addonPage:IsVisible() and not frame.profiles:IsVisible())
assert(frame.profilePicker.text:GetText() == "Shared")
assert(frame:GetWidth() == 740 and frame:GetHeight() == 434)
assert(#ns.Changes(ns.catalog.states) == 0 and not ns.draft.vendor)
for i = 1, 15 do ns.catalog.categories[("Sample %02d"):format(i)] = true end
frame.category:Click()
if THEME_LOCALE then
    local picker = Sintezza_ThemePicker
    assert(picker:IsShown() and picker.owner == frame.category)
    assert(picker.rows[1].check:IsShown() and picker:GetHeight() <= 274)
    for _, row in ipairs(picker.rows) do
        if row.value == "EllesmereUI" then row:Click(); break end
    end
    assert(not picker:IsShown())
else
    assert(menuScrollLimit == 250)
    menuEntries.EllesmereUI()
end
assert(frame.category.text:GetText() == "EllesmereUI")
assert(frame.addons.data[1].row.id == "EllesmereUI")
frame.category:Click()
if THEME_LOCALE then Sintezza_ThemePicker.rows[1]:Click()
else menuEntries[russian and "Все категории" or "All categories"]() end
assert(frame.category.text:GetText() == (russian and "Все категории" or "All categories"))
assert(frame.addons.rows[1]:GetHeight() == 28)
local status = {}
for _, item in ipairs(frame.addons.rows) do
    if item:IsShown() then status[item.item.row.id] = item.state:GetText() end
end
assert(status.EllesmereUI == (russian and "ВКЛ" or "ON"))
assert(status.EllesmereUIBags == (russian and "ВЫКЛ" or "OFF"))
local firstCheckbox = frame.addons.rows[1].box
assert(firstCheckbox:GetWidth() == 20 and firstCheckbox:GetHeight() == 20)
assert(THEME_LOCALE and firstCheckbox.themeCheckbox or firstCheckbox.checkTexture.desaturated)
if THEME_LOCALE then
    assert(firstCheckbox.themeMarkSize == 18)
    assert(frame.addons.rows[1].band and not frame.addons.rows[1].band:IsShown())
    assert(frame.addons.rows[2].band:IsShown())
end
if CaptureManager then CaptureManager("disabled", frame) end
local function FindAddon(id)
    for _, row in ipairs(frame.addons.rows) do
        if row:IsShown() and row.item.row.id == id then return row end
    end
end
frame.search:SetText("EllesmereUI Bags")
local suiteIcon = assert(FindAddon("EllesmereUI")).icon
assert(suiteIcon:IsShown() and suiteIcon.texture == groupIcon and suiteIcon:GetWidth() == 18)
local moduleIcon = assert(FindAddon("EllesmereUIBags")).icon
assert(moduleIcon:IsShown() and moduleIcon.atlas == knownAtlas)
frame.search:SetText("EllesmereUI Action Bars")
assert(FindAddon("EllesmereUIActionBars").icon == moduleIcon)
assert(moduleIcon:IsShown() and moduleIcon.texture == 133742 and not moduleIcon.atlas)
assert(table.concat(moduleIcon.texCoord, ",") == "0,1,0,1")
frame.search:SetText("EllesmereUI Raid")
assert(FindAddon("EllesmereUIRaidFrames").icon == moduleIcon and moduleIcon.atlas == knownAtlas)
frame.search:SetText("EllesmereUI Chat")
assert(FindAddon("EllesmereUIChat").icon == moduleIcon and not moduleIcon:IsShown() and not moduleIcon.atlas)
frame.search:SetText("Missing dependency")
assert(FindAddon("Absent").icon == moduleIcon and not moduleIcon:IsShown())
frame.search:SetText("NewAddon")
local enabledRow = assert(FindAddon("NewAddon"), "the default filter must include enabled standalone addons")
assert(enabledRow.icon == suiteIcon and not suiteIcon:IsShown() and not suiteIcon.texture)
assert(enabledRow.box:GetChecked())
enabledRow.box:Click()
assert(not enabledRow.box:GetChecked() and enabledRow.changeArrow:IsShown())
assert(states.Mira.NewAddon and #writes == 0)
enabledRow.box:Click()
assert(enabledRow.box:GetChecked() and not enabledRow.changeArrow:IsShown())
frame.search:SetText("")
local group = assert(FindAddon("EllesmereUI"))
assert(group.disclosure:IsShown() and group.count:GetText() == (russian and "3/5 выкл." or "3/5 off"))
assert(group.disclosure:GetWidth() == 23 and group.disclosure:GetHeight() == 28)
if THEME_LOCALE then
    assert(group.disclosure.arrow:GetWidth() == 16)
    group.scripts.OnEnter(group)
    assert(group.themeHover:IsShown())
    group.scripts.OnLeave(group)
    assert(not group.themeHover:IsShown())
end
assert(FindAddon("EllesmereUIActionBars") and FindAddon("EllesmereUIOptions"))
group.disclosure:Click()
assert(ns.db.collapsed.ellesmereui and not FindAddon("EllesmereUIBags"))
ns.InitDB(ns.db)
assert(ns.db.collapsed.ellesmereui)
frame.search:SetText("EllesmereUI Bags")
assert(FindAddon("EllesmereUIBags") and not FindAddon("EllesmereUI").disclosure:IsEnabled())
assert(not FindAddon("EllesmereUIActionBars"))
frame.search:SetText("")
assert(not FindAddon("EllesmereUIBags") and ns.db.collapsed.ellesmereui)
group = assert(FindAddon("EllesmereUI"))
group.scripts.OnClick(group, "RightButton")
menuEntries[russian and "Включить все модули" or "Enable all modules"]()
assert(ns.draft.ellesmereuibags and ns.draft.ellesmereuichat and ns.draft.ellesmereuiraidframes)
assert(#writes == 0 and saves == 0)
FindAddon("EllesmereUI").disclosure:Click()
assert(FindAddon("EllesmereUIBags").box:GetChecked())
local bags = FindAddon("EllesmereUIBags")
assert(bags.state:GetText() == (russian and "ВЫКЛ" or "OFF"))
assert(bags.changeArrow:IsShown() and bags.nextState:IsShown())
assert(bags.nextState:GetText() == (russian and "ВКЛ" or "ON"))
if THEME_LOCALE then
    assert(bags.changeArrow:GetWidth() == 10 and bags.changeArrow.expanded == false)
else
    assert(bags.changeArrow:GetText() == ">")
end
group = assert(FindAddon("EllesmereUI"))
assert(group.count:GetText() == (russian and "5 вкл." or "5 on"))
group.scripts.OnClick(group, "RightButton")
menuEntries[russian and "Отключить все модули" or "Disable all modules"]()
assert(ns.draft.ellesmereui and not ns.draft.ellesmereuibags and not ns.draft.ellesmereuichat
    and not ns.draft.ellesmereuiraidframes and #writes == 0)
assert(not ns.draft.ellesmereuiactionbars and not ns.draft.ellesmereuioptions)
assert(not FindAddon("EllesmereUIActionBars").box:GetChecked())
local bars = FindAddon("EllesmereUIActionBars")
assert(bars.state:GetText() == (russian and "ВКЛ" or "ON"))
assert(bars.changeArrow:IsShown() and bars.nextState:IsShown())
assert(bars.nextState:GetText() == (russian and "ВЫКЛ" or "OFF"))
assert(FindAddon("EllesmereUI").count:GetText() == (russian and "5/5 выкл." or "5/5 off"))
assert(FindAddon("EllesmereUIBags") and not ns.db.collapsed.ellesmereui)
ns.Reset()
ns.Redraw()
assert(not FindAddon("EllesmereUIActionBars").changeArrow:IsShown())
assert(not FindAddon("EllesmereUIActionBars").nextState:IsShown())
local visible = ns.VisibleRows("LittleWigs", "disabled")
assert(#visible == 2 and visible[1].depth == 0 and visible[1].row.id == "Z_BigWigs"
    and visible[2].depth == 1 and visible[2].row.id == "A_LittleWigs")
visible = ns.VisibleRows("ТОРГОВЕЦ", "disabled", "Trade")
assert(#visible == 2 and visible[1].row.id == "Sintezza_Theme" and visible[2].row.id == "Vendor")
local themeRows = 0
for _, item in ipairs(ns.VisibleRows("", "disabled")) do
    if item.row.id == "Sintezza_Theme" then themeRows = themeRows + 1 end
end
assert(themeRows == 1)
visible = ns.VisibleRows("", "disabled", "EllesmereUI")
assert(#visible == 5 and visible[1].row.id == "EllesmereUI" and visible[1].depth == 0)
assert(visible[2].row.id == "EllesmereUIActionBars" and visible[2].depth == 1)
assert(visible[3].row.id == "EllesmereUIBags" and visible[3].depth == 1)
assert(visible[4].row.id == "EllesmereUIChat" and visible[4].depth == 1)
assert(visible[5].row.id == "EllesmereUIRaidFrames" and visible[5].depth == 1)
visible = ns.VisibleRows("EllesmereUI", "disabled")
assert(#visible == 6 and visible[1].off == 3 and visible[1].on == 2)
visible = ns.VisibleRows("EllesmereUI", "enabled")
assert(#visible == 6 and visible[1].row.id == "EllesmereUI")
assert(#ns.VisibleRows("EllesmereUI Bags", "enabled") == 0)
assert(#ns.VisibleRows("NewAddon", "disabled") == 0)
assert(not ns.SetEnabled("broken", true) and not ns.draft.broken)
assert(not ns.SetEnabled("sintezza_manager", false))
assert(ns.SetEnabled("vendor", true) and ns.SetEnabled("disenchant", true))
assert(ns.SetEnabled("sintezza_theme", false) and not ns.draft.vendor and not ns.draft.disenchant)
ns.Reset()
local row = frame.addons.rows[1]
assert(row and row.box and row.item)
for _, item in ipairs(frame.addons.rows) do
    if item:IsShown() and item.item.row.id == "A_LittleWigs" then item.box:Click(); break end
end
assert(ns.draft.a_littlewigs and ns.draft.z_bigwigs)
assert(frame.cancel:IsShown() and frame.apply:IsShown() and #writes == 0)
frame.save:Click()
assert(SintezzaManagerDialog:IsShown() and SintezzaManagerDialog.hint:GetText():find("Shared", 1, true))
SintezzaManagerDialog.accept:Click()
assert(frame.apply:IsShown() and ns.db.profiles.Shared.uninstalled and ns.db.profiles.Shared.a_littlewigs)
assert(not states.Mira.A_LittleWigs and #writes == 0)
frame.apply:Click()
assert(SintezzaManagerDialog:IsShown() and #SintezzaManagerDialog.preview.data == 2)
if CaptureManager then CaptureManager("confirm", SintezzaManagerDialog) end
M.combat = true
SintezzaManagerDialog.accept:Click()
assert(#writes == 0 and saves == 0 and reloads == 0)
M.combat = false
ns.Redraw()
AddonList:Show()
assert(not ns.Apply() and #writes == 0)
AddonList:Hide()
ns.Redraw()
frame.apply:Click()
SintezzaManagerDialog.accept:Click()
assert(writes[1] == "Z_BigWigs" and states.Mira.Z_BigWigs and states.Mira.A_LittleWigs)
assert(not states.Alden.A_LittleWigs and reloads == 1 and saves == 1 and not frame.apply:IsShown())

who = "Alden"
fixtures[#fixtures + 1] = {id = "JustInstalled", title = "Just installed"}
indexed.JustInstalled = fixtures[#fixtures]
states.Alden.JustInstalled = true
assert(ns.Open())
assert(#ns.Changes(ns.catalog.states) == 0 and not ns.draft.vendor)
frame.load:Click()
assert(not SintezzaManagerDialog:IsShown())
assert(#ns.Changes(ns.catalog.states) == 2 and ns.draft.justinstalled)
assert(frame.filters[3].filter == "all" and not states.Alden.A_LittleWigs)
frame.profilePicker:Click()
menuEntries.ZLegacy()
frame.load:Click()
assert(SintezzaManagerDialog:IsShown())
SintezzaManagerDialog:Hide()
assert(ns.draft.a_littlewigs and not ns.draft.vendor)
frame.load:Click()
SintezzaManagerDialog.accept:Click()
assert(ns.draft.vendor and not ns.draft.a_littlewigs and not states.Alden.Vendor)
frame.profilePicker:Click()
menuEntries.Shared()
frame.load:Click()
assert(SintezzaManagerDialog:IsShown())
SintezzaManagerDialog.accept:Click()
assert(ns.draft.a_littlewigs and not ns.draft.vendor)
failWrite = "A_LittleWigs"
assert(not ns.Apply() and not states.Alden.A_LittleWigs and not states.Alden.Z_BigWigs and reloads == 1)
failSave = true
assert(not ns.Apply() and not states.Alden.A_LittleWigs and not states.Alden.Z_BigWigs and reloads == 1)
assert(ns.Apply() and states.Alden.A_LittleWigs and reloads == 2)
assert(ns.SetEnabled("z_bigwigs", false))
local previous = #writes
states.Alden.NewAddon = false
assert(not ns.Apply() and #writes == previous and not ns.draft.newaddon)

who = "Unlinked"
assert(ns.Refresh() and ns.LoadProfile("Shared"))
assert(ns.draft.a_littlewigs and not states.Unlinked.A_LittleWigs)
local name = ns.NewProfile("Alt")
assert(name == "Alt" and ns.NewProfile(" alt ") == nil)
frame.profilePicker:Click()
menuEntries[russian and "Новый профиль…" or "New profile…"]()
assert(not frame.load:IsEnabled())
frame.save:Click()
SintezzaManagerDialog.edit:SetText("Draft copy")
SintezzaManagerDialog.accept:Click()
assert(ns.db.profiles["Draft copy"].a_littlewigs and frame.profilePicker.text:GetText() == "Draft copy")
frame:Hide()
SlashCmdList.SINTEZZAMANAGER()
assert(frame:IsShown())
frame.profilesTab:Click()
assert(frame.profiles:IsVisible() and not frame.addonPage:IsVisible() and not frame.quick:IsVisible())
local sharedRow
for _, profile in ipairs(frame.profiles.list.rows) do
    if profile.profile == "Shared" then sharedRow = profile; break end
end
assert(sharedRow)
sharedRow:Click()
local savedLittleWigs
for _, item in ipairs(frame.profiles.contents.data) do
    if item.title == "LittleWigs" then savedLittleWigs = item.on end
end
assert(savedLittleWigs)
if CaptureManager then CaptureManager("profiles", frame) end
sharedRow.scripts.OnClick(sharedRow, "RightButton")
menuEntries[russian and "Переименовать" or "Rename"]()
assert(SintezzaManagerDialog.edit:GetText() == "Shared")
SintezzaManagerDialog.edit:SetText("Alt")
SintezzaManagerDialog.accept:Click()
assert(SintezzaManagerDialog:IsShown() and ns.db.profiles.Shared)
SintezzaManagerDialog.edit:SetText("Everyday")
SintezzaManagerDialog.accept:Click()
assert(not SintezzaManagerDialog:IsShown() and not ns.db.profiles.Shared)
assert(ns.db.links.Mira.profile == "ZLegacy")
frame.profiles.duplicate:Click()
SintezzaManagerDialog.edit:SetText("Raid Copy")
SintezzaManagerDialog.accept:Click()
assert(ns.db.profiles["Raid Copy"].uninstalled and ns.db.profiles["Raid Copy"].a_littlewigs)
ns.db.profiles["Raid Copy"].a_littlewigs = false
assert(ns.db.profiles.Everyday.a_littlewigs == true)
frame.addonsTab:Click()
assert(frame.profilePicker.text:GetText() == "Raid Copy" and frame.quick:IsVisible())

local size = ns.WindowSize
if THEME_LOCALE then
    local prefs = size.prefs
    local grip = prefs.windows[frame].resize.grip
    grip.scripts.OnMouseDown(grip, "LeftButton")
    cursorX, cursorY = cursorX - 280, cursorY + 190
    grip.scripts.OnMouseUp(grip, "LeftButton")
    assert(frame:GetWidth() == size.minWidth and frame:GetHeight() == size.minHeight)
    assert(ns.db.windowAppearance.sizes.manager.width == size.minWidth)
    assert(Sintezza_Theme:ApplyGlobalWindowOptions({scale = 115, opacity = 80, layer = "HIGH"}))
    assert(frame:GetScale() == 1.15 and frame:GetAlpha() == .8 and frame:GetFrameStrata() == "HIGH")
    prefs:Set("scale", 85)
    assert(frame:GetScale() == .85)
    prefs:Set("locked", true)
    assert(not grip:IsShown() and not size.CanMove())
    prefs:Set("locked", false)
    assert(grip:IsShown())
else
    assert(frame.resizable and frame.resizeBounds[1] == size.minWidth)
    local grip
    for _, object in ipairs(M.objects) do
        if object.parent == frame and object.kind == "Button" and object.scripts.OnDragStart then grip = object; break end
    end
    assert(grip)
    grip.scripts.OnDragStart(grip)
    assert(frame.sizing == "BOTTOMRIGHT")
    frame:SetSize(size.minWidth, size.minHeight)
    grip.scripts.OnDragStop(grip)
    assert(ns.db.windowAppearance.sizes.manager.width == size.minWidth)
end
assert(frame:GetWidth() == size.minWidth and frame:GetHeight() == size.minHeight)
assert(size.minWidth == 480)
M.layout()
ns.Redraw()
assert(frame.compact and frame.profilePicker:GetWidth() == 110 and frame.search:GetWidth() >= 160)
assert(frame.filters[1].text:GetText() == (russian and "Откл." or "Off"))
assert(frame.category.text:GetText() == (russian and "Категории" or "Categories"))
local boxes = {}
for _, item in ipairs(M.snapshot(frame)) do boxes[item.id] = item end
local tabBox, profileBox = boxes[frame.profilesTab.id], boxes[frame.profileLabel.id]
assert(tabBox.x + tabBox.width < profileBox.x, "tabs and profile toolbar must fit in a single row")
local searchBox, filterBox = boxes[frame.search.id], boxes[frame.category.id]
assert(searchBox.x + searchBox.width < filterBox.x, "search and category controls must not overlap")
assert(searchBox.y == filterBox.y, "search and category controls must share a row")
assert(boxes[frame.filters[1].id].y > searchBox.y + searchBox.height, "status filters must be below search")
local lastFilter, forceLoad, forceLoadLabel = boxes[frame.filters[3].id], boxes[frame.allowOutdated.id], boxes[frame.allowOutdated.label.id]
assert(lastFilter.x + lastFilter.width < forceLoad.x and forceLoad.x + forceLoad.width < forceLoadLabel.x)
assert(forceLoad.y >= lastFilter.y and forceLoad.y + forceLoad.height <= lastFilter.y + lastFilter.height)
local pendingRow = assert(FindAddon("A_LittleWigs"))
local currentBox, arrowBox, nextBox = boxes[pendingRow.state.id], boxes[pendingRow.changeArrow.id], boxes[pendingRow.nextState.id]
assert(currentBox.x + currentBox.width < arrowBox.x and arrowBox.x + arrowBox.width < nextBox.x)
assert(nextBox.x + nextBox.width < boxes[pendingRow.id].x + boxes[pendingRow.id].width)
if CaptureManager then CaptureManager("minimum", frame) end
frame.profilesTab:Click()
assert(frame.profiles.heading:GetText() == (russian and "Профили" or "Profiles"))
if CaptureManager then CaptureManager("minimum-profiles", frame) end
frame.addonsTab:Click()
frame.apply:Click()
assert(SintezzaManagerDialog:IsShown() and SintezzaManagerDialog:GetWidth() == 456)
if CaptureManager then CaptureManager("minimum-confirm", SintezzaManagerDialog) end
SintezzaManagerDialog:Hide()
size.Reset()
M.layout()
assert(frame:GetWidth() == size.width and frame:GetHeight() == size.height)
assert(not frame.compact and frame.profilePicker:GetWidth() == 139)
assert(frame.filters[1].text:GetText() == (russian and "Отключенные" or "Disabled"))
assert(not ns.db.windowAppearance.sizes or not ns.db.windowAppearance.sizes.manager)

fixtures[#fixtures + 1] = {id = "ZZBrokenModule", title = "ZZ Broken module", group = "EllesmereUI", needs = {"Absent"}}
indexed.ZZBrokenModule = fixtures[#fixtures]
assert(ns.Refresh())
local beforeGroup = ns.draft
assert(not ns.SetGroupEnabled("ellesmereui", true))
assert(ns.draft == beforeGroup and not ns.draft.ellesmereuibags and not ns.draft.ellesmereuichat)

local old = {id = "OldAddon", title = "Old addon", interface = 16000}
fixtures[#fixtures + 1], indexed[old.id] = old, old
assert(ns.Open())
frame.search:SetText(old.id)
local oldRow = assert(FindAddon(old.id))
assert(oldRow.outdated:IsShown() and oldRow.box:IsEnabled() and not oldRow.box:GetChecked())
assert(frame.allowOutdated:IsShown() and not frame.allowOutdated:GetChecked())
oldRow.box:Click()
frame.allowOutdated:Click()
assert(oldRow.box:GetChecked() and frame.allowOutdated:GetChecked())
assert(versionCheck and versionWrites == 0 and not states[who][old.id])
assert(ns.Refresh() and ns.draft.oldaddon and ns.allowOutdated)
frame.apply:Click()
assert(SintezzaManagerDialog.preview.data[1].key == "oldaddon")
assert(SintezzaManagerDialog.hint:GetText():find(russian and "для всех персонажей" or "for all characters", 1, true))
M.combat = true
SintezzaManagerDialog.accept:Click()
assert(versionCheck and versionWrites == 0 and not states[who][old.id])
M.combat = false
ns.Redraw()
failVersionWrite = true
assert(not ns.Apply() and versionCheck and versionWrites == 2 and not states[who][old.id])
failSave = true
assert(not ns.Apply() and versionCheck and versionWrites == 4 and not states[who][old.id])
assert(ns.Apply() and not versionCheck and versionWrites == 5 and states[who][old.id] and not states.Mira[old.id])
assert(ns.Open() and FindAddon(old.id).outdated:IsShown())
local oldChecked = FindAddon(old.id).box:GetChecked()
frame.allowOutdated:Click()
assert(frame.apply:IsShown() and oldChecked and FindAddon(old.id).box:GetChecked())
frame.cancel:Click()
assert(frame.allowOutdated:GetChecked() and not frame.apply:IsShown() and versionWrites == 5)
frame.allowOutdated:Click()
frame.apply:Click()
assert(#SintezzaManagerDialog.preview.data == 0)
SintezzaManagerDialog.accept:Click()
assert(versionCheck and versionWrites == 6 and states[who][old.id])
oldRow.box:Click()
assert(ns.Apply() and versionCheck and not states[who][old.id])
frame.allowOutdated:Click()
versionCheck = false
assert(not ns.Apply() and versionWrites == 6 and ns.allowOutdated)
ns.Redraw()
assert(frame.allowOutdated:GetChecked() and not frame.cancel:IsShown())
C_AddOns.SetAddonVersionCheck = nil
assert(ns.Open() and not frame.allowOutdated:IsShown() and FindAddon(old.id).box:IsEnabled())
