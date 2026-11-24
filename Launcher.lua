local addon, ns = ...
local L = ns.Text
local hookedMenu, registeredSettings

local function Report(message)
    if message then print(ns.title .. ": " .. message) end
end

local function Open()
    local _, message = ns.Open()
    Report(message)
end

local function SettingsPage()
    if registeredSettings or not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then return end
    local style, size = ns.Style, ns.WindowSize
    local panel = CreateFrame("Frame")
    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("TOPLEFT", 18, -18)
    icon:SetTexture(style.icon)
    local heading = style.Label(panel, ns.title, 20)
    heading:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    local button = style.Button(panel, L("Open manager", "Открыть менеджер"), function()
        if not InCombatLockdown() and SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        Open()
    end, true)
    button:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -12)
    button:SetSize(188, 30)
    local previous = button
    if size.prefs and style.widgets.SliderRow then
        local slider = style.widgets:SliderRow(panel, L("Window scale", "Масштаб окна"), 50, 200, 5,
            function() return size.prefs:Get("scale") end, function(value) size.prefs:Set("scale", value) end, "%")
        slider:SetPoint("TOPLEFT", 18, -100)
        slider:SetPoint("TOPRIGHT", -18, -100)
        panel:HookScript("OnShow", function() slider:Refresh(false) end)
        previous = slider
    end
    local reset = style.Button(panel, L("Reset window size", "Сбросить размер окна"), size.Reset)
    reset:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -12)
    reset:SetSize(188, 28)
    registeredSettings = Settings.RegisterCanvasLayoutCategory(panel, ns.title)
    if registeredSettings then Settings.RegisterAddOnCategory(registeredSettings) end
end

local function GameMenu()
    local menu = GameMenuFrame
    if hookedMenu or not menu or type(menu.InitButtons) ~= "function" then return end
    hookedMenu = true
    hooksecurefunc(menu, "InitButtons", function(self)
        if InCombatLockdown() then return end
        for _, button in ipairs(self.buttons or {}) do
            if button:GetText() == ADDONS and button:IsEnabled() then
                local native = button:GetScript("OnClick")
                if not native then return end
                button:SetScript("OnClick", function(...)
                    if InCombatLockdown() or not ns.Open() then return native(...) end
                    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
                    HideUIPanel(self)
                end)
                return
            end
        end
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name == addon then
            Sintezza_ManagerDB = ns.InitDB(Sintezza_ManagerDB)
            SLASH_SINTEZZAMANAGER1 = "/smanager"
            SlashCmdList.SINTEZZAMANAGER = Open
        end
        if ns.db then
            SettingsPage()
            GameMenu()
            if registeredSettings and hookedMenu then self:UnregisterEvent("ADDON_LOADED") end
        end
    elseif event == "PLAYER_LOGIN" then
        SettingsPage()
        GameMenu()
        if registeredSettings and hookedMenu then self:UnregisterEvent("ADDON_LOADED") end
        self:UnregisterEvent("PLAYER_LOGIN")
    else
        if event ~= "PLAYER_REGEN_DISABLED" then ns.WindowSize.FitStandalone() end
        ns.Redraw()
    end
end)
