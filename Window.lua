local _, ns = ...
local S, L = ns.Style, ns.Text
local T = S.palette
local size = ns.WindowSize
local window, popup, selected, quickProfile, category, notice
local filter = "disabled"
local page = "addons"
local Draw, SetPage, OpenProfileMenu
local ADDON_ROW_HEIGHT = 28
local ADDON_INDENT = 22

local function Anchor(region, left, right)
    region:SetPoint("LEFT", left, 0)
    region:SetPoint("RIGHT", right, 0)
    region:SetWordWrap(false)
end

local function Button(parent, label, width, action, primary)
    local button = S.Button(parent, label, action, primary)
    button:SetSize(width, 25)
    return button
end

local function Dropdown(parent, width, action)
    local button = Button(parent, "", width, action)
    local arrow
    if S.widgets and T.DisclosureArrow then
        arrow = T:DisclosureArrow(button, 10)
        arrow:SetExpanded(true)
    else
        arrow = CreateFrame("Frame", nil, button)
        arrow:SetSize(10, 7)
        for _, side in ipairs({-1, 1}) do
            local stroke = arrow:CreateTexture(nil, "ARTWORK")
            stroke:SetSize(5, 1)
            stroke:SetPoint("CENTER", arrow, "CENTER", side * 1.4, 0)
            stroke:SetRotation(side * math.pi / 4)
            S.Tint(stroke, "SetColorTexture", T.muted)
        end
    end
    arrow:SetPoint("RIGHT", -8, 0)
    button.text:ClearAllPoints()
    button.text:SetJustifyH("LEFT")
    Anchor(button.text, 8, -23)
    return button
end

local function OpenMenu(owner, build)
    S.HideTooltip(owner)
    if S.widgets and T.OpenMenu then T:OpenMenu(owner, build)
    elseif MenuUtil and MenuUtil.CreateContextMenu then MenuUtil.CreateContextMenu(owner, build) end
end

local function List(parent, lineHeight, create, paint)
    local scroll, body = S.Scroll(parent, lineHeight * 2)
    local list = {scroll = scroll, body = body, data = {}, rows = {}}
    function list:Paint()
        local offset = math.floor(self.scroll:GetVerticalScroll() / lineHeight)
        local needed = math.max(0, math.min(#self.data - offset, math.ceil(self.scroll:GetHeight() / lineHeight) + 1))
        for i = 1, needed do
            local row = self.rows[i]
            if not row then
                row = create(self.body)
                row:SetHeight(lineHeight)
                self.rows[i] = row
            end
            local index = offset + i
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -(index - 1) * lineHeight)
            row:SetPoint("TOPRIGHT", 0, -(index - 1) * lineHeight)
            paint(row, self.data[index], index)
            row:Show()
        end
        for i = needed + 1, #self.rows do self.rows[i]:Hide() end
    end
    function list:Size()
        local range = math.max(0, #self.data * lineHeight - self.scroll:GetHeight())
        self.body:SetWidth(math.max(1, self.scroll:GetWidth()))
        self.body:SetHeight(math.max(1, #self.data * lineHeight))
        self.scroll:UpdateScrollChildRect()
        if self.scroll.RefreshRange then self.scroll:RefreshRange() end
        if self.scroll:GetVerticalScroll() > range then self.scroll:SetVerticalScroll(range) end
        self:Paint()
    end
    function list:Set(rows, top)
        self.data = rows
        if top then self.scroll:SetVerticalScroll(0) end
        self:Size()
    end
    scroll:HookScript("OnVerticalScroll", function() list:Paint() end)
    scroll:HookScript("OnSizeChanged", function() list:Size() end)
    return list
end

local function AddonRow(parent)
    local row = CreateFrame("Button", nil, parent)
    if S.widgets and T.RowBand then row.band = T:RowBand(row) end
    if S.widgets and T.MenuHighlight then
        local hover = T:MenuHighlight(row)
        row:HookScript("OnEnter", function() hover:Show() end)
        row:HookScript("OnLeave", function() hover:Hide() end)
        row:HookScript("OnHide", function() hover:Hide() end)
    else
        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        S.Tint(highlight, "SetColorTexture", T.panelHover)
        highlight:SetAlpha(.32)
    end
    row.branch = row:CreateTexture(nil, "ARTWORK")
    row.branch:SetSize(1, ADDON_ROW_HEIGHT / 2)
    S.Tint(row.branch, "SetColorTexture", T.lineSoft)
    row.elbow = row:CreateTexture(nil, "ARTWORK")
    row.elbow:SetPoint("BOTTOMLEFT", row.branch, "BOTTOMLEFT")
    row.elbow:SetSize(9, 1)
    S.Tint(row.elbow, "SetColorTexture", T.lineSoft)

    row.disclosure = CreateFrame("Button", nil, row)
    row.disclosure:SetSize(23, ADDON_ROW_HEIGHT)
    if S.widgets and T.DisclosureArrow then
        row.disclosure.arrow = T:DisclosureArrow(row.disclosure, 16, T.brass or T.accent)
    else
        local arrow = S.Label(row.disclosure, "", 17, T.muted)
        function arrow:SetExpanded(expanded) self:SetText(expanded and "−" or "+") end
        row.disclosure.arrow = arrow
    end
    row.disclosure.arrow:SetPoint("CENTER")
    row.disclosure:SetScript("OnClick", function()
        local item = row.item
        if item.hasChildren and not item.searching then
            ns.ToggleGroup(item.row.key)
            Draw()
        end
    end)
    row.box = S.CheckButton(row)
    row.name = S.Label(row, "", 13, T.text)
    row.name:SetWordWrap(false)
    row.count = S.Label(row, "", 12, T.muted)
    row.count:SetPoint("RIGHT", -113, 0)
    row.state = S.Label(row, "", 12, T.muted)
    row.state:SetPoint("LEFT", row, "RIGHT", -104, 0)
    row.state:SetWordWrap(false)
    if S.widgets and T.DisclosureArrow then
        row.changeArrow = T:DisclosureArrow(row, 10, T.muted)
        row.changeArrow:SetExpanded(false)
    else row.changeArrow = S.Label(row, ">", 11, T.muted) end
    row.changeArrow:SetPoint("LEFT", row.state, "RIGHT", 4, 0)
    row.nextState = S.Label(row, "", 12, T.accent)
    row.nextState:SetPoint("LEFT", row.changeArrow, "RIGHT", 4, 0)
    row.nextState:SetWordWrap(false)
    local function Toggle()
        local item = row.item
        if not item or item.missing or item.row.locked then return end
        local _, message = ns.SetEnabled(item.row.key, not ns.draft[item.row.key])
        notice = message
        Draw()
    end
    local function GroupMenu(owner, item)
        local key = item.row.key
        local function Change(enabled)
            local _, message = ns.SetGroupEnabled(key, enabled)
            notice = message
            Draw()
        end
        OpenMenu(owner, function(_, root)
            root:CreateTitle(item.row.title)
            root:CreateButton(L("Enable all modules", "Включить все модули"), function() Change(true) end)
            root:CreateButton(L("Disable all modules", "Отключить все модули"), function() Change(false) end)
        end)
    end
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            if self.item and self.item.on then GroupMenu(self, self.item) end
        else Toggle() end
    end)
    row.box:SetScript("OnClick", Toggle)
    local function Help(owner)
        local item = row.item
        if not item then return end
        local data = item.row
        if item.missing then
            S.Tooltip(owner, data.id, L("Required addon is missing.", "Обязательная зависимость не установлена."))
            return
        end
        local requirements = {}
        for _, need in ipairs(data.needs) do
            local dep = ns.catalog.entries[need.key]
            requirements[#requirements + 1] = dep and dep.title or need.id
        end
        local hint = data.id
        if #requirements > 0 then
            hint = hint .. "\n" .. L("Requires: %s", "Требуются: %s"):format(table.concat(requirements, ", "))
        end
        if item.on then
            hint = hint .. "\n" .. L("Modules: %d on, %d off", "Модули: %d вкл., %d выкл."):format(item.on, item.off)
                .. "\n" .. L("Right-click for group actions.", "ПКМ открывает действия для группы.")
        end
        if owner == row.box then
            hint = hint .. "\n" .. L("The checkmark shows the current state.", "Галочка показывает текущее состояние.")
        end
        S.Tooltip(owner, data.title, hint)
    end
    for _, target in ipairs({row, row.box}) do
        target:HookScript("OnEnter", Help)
        target:HookScript("OnLeave", S.HideTooltip)
        target:HookScript("OnHide", S.HideTooltip)
    end
    return row
end

local function PaintAddon(row, item, index)
    row.item = item
    if row.band then row.band:SetShown(index % 2 == 0) end
    local data = item.row
    local enabled = ns.draft[data.key]
    local applied = ns.catalog.states[data.key]
    local pending = enabled ~= applied
    local inset = math.min(5, item.depth) * ADDON_INDENT
    row.disclosure:ClearAllPoints()
    row.disclosure:SetPoint("LEFT", 2 + inset, 0)
    row.disclosure:SetShown(item.hasChildren == true)
    row.disclosure:SetEnabled(not item.searching)
    row.disclosure.arrow:SetExpanded(not item.collapsed)
    row.box:ClearAllPoints()
    row.box:SetPoint("LEFT", 28 + inset, 0)
    row.box:SetChecked(applied and not item.missing)
    row.box:SetEnabled(not data.locked and not item.missing)
    row.box:SetAlpha((data.locked or item.missing) and .45 or 1)
    local group = item.off ~= nil
    row.count:SetShown(group)
    if group then
        row.count:SetText(item.off > 0 and L("%d/%d off", "%d/%d выкл."):format(item.off, item.on + item.off)
            or L("%d on", "%d вкл."):format(item.on))
    end
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", row.box, "RIGHT", 7, 0)
    row.name:SetPoint("RIGHT", -116 - (group and row.count:GetStringWidth() + 7 or 0), 0)
    row.name:SetText(data.title or data.id)
    S.Tint(row.name, "SetTextColor", item.depth > 0 and T.muted or T.text)
    row.branch:ClearAllPoints()
    row.branch:SetPoint("TOPLEFT", row, "TOPLEFT", inset - 9, 0)
    row.branch:SetShown(item.depth > 0)
    row.elbow:SetShown(item.depth > 0)
    local state, nextState
    if item.missing then state = L("Missing", "Не установлен")
    elseif data.banned then state = L("Blocked", "Заблокирован")
    else
        local on, off = L("ON", "ВКЛ"), L("OFF", "ВЫКЛ")
        state = applied and on or off
        if pending then nextState = enabled and on or off end
    end
    row.state:SetText(state)
    S.Tint(row.state, "SetTextColor", (applied or item.missing or data.banned) and T.accent or T.muted)
    row.changeArrow:SetShown(nextState ~= nil)
    row.nextState:SetText(nextState or "")
    row.nextState:SetShown(nextState ~= nil)
end

local function ProfileRow(parent)
    local row = S.Button(parent, "", function(self, button)
        if button == "RightButton" then OpenProfileMenu(self, self.profile); return end
        selected, quickProfile = self.profile, self.profile
        notice = nil
        Draw()
    end)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.text:SetJustifyH("LEFT")
    row.text:ClearAllPoints()
    Anchor(row.text, 9, -64)
    row.count = S.Label(row, "", 12, T.muted)
    row.count:SetPoint("RIGHT", -9, 0)
    row:HookScript("OnEnter", function(self)
        if self.profile then S.Tooltip(self, self.profile, "") end
    end)
    row:HookScript("OnLeave", S.HideTooltip)
    row:HookScript("OnHide", S.HideTooltip)
    return row
end

local function ProfileCounts(profile)
    local enabled, disabled = 0, 0
    for _, state in pairs(ns.db.profiles[profile] or {}) do
        if state then enabled = enabled + 1
        else disabled = disabled + 1 end
    end
    return enabled, disabled
end

local function PaintProfile(row, profile)
    row.profile = profile
    row.text:SetText(profile)
    local enabled = ProfileCounts(profile)
    row.count:SetText(L("%d on", "%d вкл."):format(enabled))
    S.Selected(row, profile == selected)
end

local function MakePopup()
    local shade = CreateFrame("Frame", nil, window)
    shade:SetAllPoints()
    shade:SetFrameLevel(window:GetFrameLevel() + 50)
    shade:EnableMouse(true)
    local dim = shade:CreateTexture(nil, "BACKGROUND")
    dim:SetAllPoints()
    dim:SetColorTexture(0, 0, 0, .64)
    shade:Hide()
    local frame = S.Surface(shade, "SintezzaManagerDialog", "window")
    frame:SetSize(500, 300)
    frame:SetPoint("CENTER")
    frame:SetFrameLevel(shade:GetFrameLevel() + 1)
    frame:EnableMouse(true)
    frame:Hide()
    table.insert(UISpecialFrames, 1, frame:GetName())
    local header = S.Header(frame, "", function() frame:Hide() end)
    frame.title = header.title
    frame.hint = S.Label(frame, "", 13, T.muted)
    frame.hint:SetPoint("TOPLEFT", 15, -55)
    frame.hint:SetPoint("TOPRIGHT", -15, -55)
    frame.hint:SetMaxLines(3)
    frame.hint:SetWordWrap(true)
    local function NewDiff(parent)
        local row = CreateFrame("Frame", nil, parent)
        row.name = S.Label(row, "", 13)
        Anchor(row.name, 4, -180)
        row.state = S.Label(row, "", 13, T.accent)
        row.state:SetPoint("RIGHT", -5, 0)
        return row
    end
    frame.preview = List(frame, 25, NewDiff, function(row, data)
        row.name:SetText(data.title)
        row.state:SetText(ns.draft[data.key] and L("Enable", "Включить") or L("Disable", "Отключить"))
    end)
    frame.preview.scroll:SetPoint("TOPLEFT", frame.hint, "BOTTOMLEFT", 0, -10)
    frame.preview.scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -29, 57)
    frame.edit = S.Input(frame, L("Profile name", "Название профиля"))
    frame.edit:SetPoint("TOPLEFT", frame.hint, "BOTTOMLEFT", 0, -14)
    frame.edit:SetPoint("TOPRIGHT", frame.hint, "BOTTOMRIGHT", 0, -14)
    frame.edit:SetMaxLetters(40)
    frame.error = S.Label(frame, "", 13, T.accent)
    frame.error:SetPoint("TOPLEFT", frame.edit, "BOTTOMLEFT", 0, -10)
    frame.error:SetPoint("TOPRIGHT", frame.edit, "BOTTOMRIGHT", 0, -10)
    frame.edit:HookScript("OnTextChanged", function() frame.error:SetText("") end)
    frame.accept = Button(frame, "", 228, function()
        local ok, message = frame.commit(frame.edit:GetText())
        if ok then frame:Hide()
        elseif frame.edit:IsShown() then frame.error:SetText(message or "")
        else frame:Hide(); notice = message end
        Draw()
    end, true)
    frame.accept:SetPoint("BOTTOMRIGHT", -15, 12)
    frame.edit:SetScript("OnEnterPressed", function() frame.accept:Click() end)
    frame.edit:SetScript("OnEscapePressed", function() frame:Hide() end)
    local back = Button(frame, L("Back", "Назад"), 96, function() frame:Hide() end)
    back:SetPoint("RIGHT", frame.accept, "LEFT", -8, 0)
    frame:SetScript("OnHide", function()
        frame.edit:ClearFocus()
        frame.commit = nil
        shade:Hide()
    end)
    frame.shade = shade
    return frame
end

local function Confirm(title, hint, label, rows, edit, commit, initial)
    if not popup then popup = MakePopup() end
    popup:SetSize(math.min(500, window:GetWidth() - 24), edit and 192 or math.min(300, 156 + #rows * 23))
    popup.title:SetText(title)
    popup.hint:SetText(hint)
    popup.accept.text:SetText(label)
    popup.commit = commit
    popup.edit:SetText(initial or "")
    popup.edit:SetShown(edit)
    popup.error:SetShown(edit)
    popup.preview.scroll:SetShown(not edit)
    popup.shade:Show()
    popup:Show()
    if edit then popup.edit:SetFocus(); popup.edit:HighlightText()
    else popup.preview:Set(rows, true) end
end

local function NewProfile()
    Confirm(L("New profile", "Новый профиль"),
        L("Save the addon set shown in the list, including your changes.", "В профиль войдет набор из списка с текущими правками."),
        L("Create profile", "Создать профиль"), {}, true, function(value)
            local name, message = ns.NewProfile(value)
            if not name then return false, message end
            selected, quickProfile = name, name
            notice = L("Profile saved.", "Профиль сохранен.")
            return true
        end)
end

local function RenameProfile(profile)
    Confirm(L("Rename profile", "Переименовать профиль"),
        L("Enter a new name for the saved set.", "Введите новое название сохраненного набора."),
        L("Rename", "Переименовать"), {}, true, function(value)
            local name, message = ns.RenameProfile(profile, value)
            if not name then return false, message end
            selected, quickProfile = name, name
            notice = L("Profile renamed.", "Профиль переименован.")
            return true
        end, profile)
end

local function DuplicateProfile(profile)
    Confirm(L("Duplicate profile", "Дублировать профиль"),
        L("Copy the saved addon set from %s.", "Создать копию сохраненного набора «%s»."):format(profile),
        L("Create copy", "Создать копию"), {}, true, function(value)
            local name, message = ns.DuplicateProfile(profile, value)
            if not name then return false, message end
            selected, quickProfile = name, name
            notice = L("Profile copied.", "Создана копия профиля.")
            return true
        end)
end

OpenProfileMenu = function(owner, profile)
    if not profile then return end
    OpenMenu(owner, function(_, root)
        root:CreateTitle(profile)
        root:CreateButton(L("Rename", "Переименовать"), function() RenameProfile(profile) end)
        root:CreateButton(L("Duplicate", "Дублировать"), function() DuplicateProfile(profile) end)
    end)
end

local function PickProfile(name)
    quickProfile = name ~= "" and name or false
    if quickProfile then selected = quickProfile end
    Draw()
end

local function OpenProfilePicker(owner)
    OpenMenu(owner, function(_, menu)
        local function IsSelected(name) return (quickProfile or "") == name end
        menu:SetScrollMode(250)
        for _, name in ipairs(ns.ProfileNames()) do
            menu:CreateRadio(name, IsSelected, PickProfile, name)
        end
        menu:CreateRadio(L("New profile…", "Новый профиль…"), IsSelected, PickProfile, "")
    end)
end

local function LoadSelected()
    local name = quickProfile
    if not name then return end
    local target, message = ns.ProfileTarget(name)
    if not target then notice = message; Draw(); return end

    local function Load()
        local ok, why = ns.LoadProfile(name)
        if not ok then return false, why end
        selected = name
        notice = L("Loaded %s into the list.", "Набор «%s» загружен в список."):format(name)
        category, filter = nil, "all"
        window.search:SetText("")
        Draw(true)
        return true
    end

    if #ns.Changes(ns.catalog.states) > 0 and #ns.Changes(target) > 0 then
        Confirm(L("Load profile", "Загрузить профиль"),
            L("Replace the pending changes with %s?", "В списке есть непримененные правки. Загрузить «%s» вместо них?"):format(name),
            L("Load", "Загрузить"), {}, false, Load)
    else
        local ok, why = Load()
        if not ok then notice = why; Draw() end
    end
end

local function SaveSelected()
    local name = quickProfile
    if not name then NewProfile(); return end
    Confirm(L("Save profile", "Сохранить профиль"),
        L("Update %s for anyone who loads it?", "Обновить сохраненный набор «%s»? Он будет доступен всем персонажам."):format(name),
        L("Save", "Сохранить"), ns.Changes(ns.db.profiles[name]), false, function()
            ns.SaveProfile(name)
            notice = L("Profile saved.", "Профиль сохранен.")
            return true
        end)
end

local function SelectCategory(value)
    category = value or nil
    Draw(true)
end

local function OpenCategories(owner)
    local names = {}
    for name in pairs(ns.catalog.categories) do names[#names + 1] = name end
    table.sort(names)
    if S.widgets and T.OpenPicker then
        local choices = {{value = false, label = L("All categories", "Все категории")}}
        for _, name in ipairs(names) do choices[#choices + 1] = {value = name, label = name} end
        S.HideTooltip(owner)
        T:OpenPicker(owner, choices, category or false, SelectCategory)
    elseif MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner, function(_, menu)
            local function IsSelected(value) return value == category end
            menu:SetScrollMode(250)
            menu:CreateRadio(L("All categories", "Все категории"), IsSelected, SelectCategory)
            for _, name in ipairs(names) do menu:CreateRadio(name, IsSelected, SelectCategory, name) end
        end)
    else
        for i, name in ipairs(names) do
            if name == category then SelectCategory(names[i + 1]); return end
        end
        SelectCategory(names[1])
    end
end

local function ProfileContentsRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.state = S.Label(row, "", 11, T.muted)
    row.state:SetPoint("RIGHT", -3, 0)
    row.name = S.Label(row, "", 12)
    row.name:SetPoint("LEFT", 2, 0)
    row.name:SetPoint("RIGHT", row.state, "LEFT", -7, 0)
    row.name:SetWordWrap(false)
    row:EnableMouseMotion(true)
    row:HookScript("OnEnter", function(self) S.Tooltip(self, self.name:GetText(), "") end)
    row:HookScript("OnLeave", S.HideTooltip)
    row:HookScript("OnHide", S.HideTooltip)
    return row
end

local function PaintContents(row, data)
    row.name:SetText(data.title)
    local state = data.on and L("ON", "ВКЛ") or L("OFF", "ВЫКЛ")
    if data.missing then state = state .. " · " .. L("missing", "нет") end
    row.state:SetText(state)
    S.Tint(row.state, "SetTextColor", data.on and not data.missing and T.accent or T.muted)
end

local function ProfilePanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    local details = S.Surface(panel, nil, "sidebar")
    details:SetPoint("TOPLEFT", panel, "TOP", -26, 0)
    details:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT")
    panel.details = details
    panel.heading = S.Label(panel, "", 15, T.text, "display")
    panel.heading:SetPoint("TOPLEFT", 0, -3)
    local new = Button(panel, L("New…", "Новый…"), 72, NewProfile)
    new:SetPoint("TOPRIGHT", details, "TOPLEFT", -10, 0)
    panel.heading:SetPoint("TOPRIGHT", new, "TOPLEFT", -5, -3)
    panel.heading:SetWordWrap(false)

    panel.list = List(panel, 26, ProfileRow, PaintProfile)
    panel.list.scroll:SetPoint("TOPLEFT", 0, -32)
    panel.list.scroll:SetPoint("BOTTOMRIGHT", details, "BOTTOMLEFT", -27, 0)
    panel.empty = S.Label(panel, L("No saved profiles", "Нет сохраненных профилей"), 13, T.muted)
    panel.empty:SetPoint("TOPLEFT", panel.list.scroll, "TOPLEFT", 5, -8)

    panel.title = S.Label(details, "", 16, T.text, "display")
    panel.title:SetPoint("TOPLEFT", 10, -10)
    panel.title:SetPoint("TOPRIGHT", -10, -10)
    panel.title:SetWordWrap(false)
    panel.totals = S.Label(details, "", 12, T.muted)
    panel.totals:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -5)
    panel.rename = Button(details, L("Rename…", "Переименовать…"), 117, function() RenameProfile(selected) end)
    panel.rename:SetPoint("TOPLEFT", panel.totals, "BOTTOMLEFT", 0, -8)
    panel.duplicate = Button(details, L("Duplicate…", "Дублировать…"), 105, function() DuplicateProfile(selected) end)
    panel.duplicate:SetPoint("LEFT", panel.rename, "RIGHT", 5, 0)
    panel.contents = List(details, 21, ProfileContentsRow, PaintContents)
    panel.contents.scroll:SetPoint("TOPLEFT", panel.rename, "BOTTOMLEFT", 0, -8)
    panel.contents.scroll:SetPoint("BOTTOMRIGHT", -25, 8)
    return panel
end

local function PaintProfiles(names)
    local panel = window.profiles
    panel.empty:SetShown(#names == 0)
    panel.list:Set(names)
    panel.details:SetShown(selected ~= nil)
    if not selected then return end

    local saved = ns.db.profiles[selected]
    local enabled, disabled = ProfileCounts(selected)
    panel.title:SetText(selected)
    panel.totals:SetText(L("%d on · %d off", "%d вкл. · %d выкл."):format(enabled, disabled))
    local rows, missing = {}, {}
    for _, row in ipairs(ns.catalog.rows) do
        if saved[row.key] ~= nil then rows[#rows + 1] = {title = row.title, on = saved[row.key]} end
    end
    for key in pairs(saved) do
        if not ns.catalog.entries[key] then missing[#missing + 1] = key end
    end
    table.sort(missing)
    for _, key in ipairs(missing) do
        rows[#rows + 1] = {title = key, on = saved[key], missing = true}
    end
    local switched = panel.lastSelected ~= selected
    panel.lastSelected = selected
    panel.contents:Set(rows, switched)
end

SetPage = function(nextPage)
    page = nextPage
    if page ~= "addons" then window.search:ClearFocus() end
    window.addonPage:SetShown(page == "addons")
    window.quick:SetShown(page == "addons")
    window.profiles:SetShown(page == "profiles")
    S.Selected(window.addonsTab, page == "addons")
    S.Selected(window.profilesTab, page == "profiles")
    Draw()
end
Draw = function(top)
    if not window or not window:IsShown() then return end
    local names = ns.ProfileNames()
    if not selected or not ns.db.profiles[selected] then selected = names[1] end
    if quickProfile == nil or (quickProfile and not ns.db.profiles[quickProfile]) then quickProfile = selected or false end
    if page == "addons" then
        window.profilePicker.text:SetText(quickProfile or L("New profile…", "Новый профиль…"))
        window.load:SetEnabled(quickProfile ~= false)
        window.category.text:SetText(category or (window.compact and L("Categories", "Категории")
            or L("All categories", "Все категории")))
        for _, button in ipairs(window.filters) do S.Selected(button, button.filter == filter) end
        local query = window.search:GetText()
        local rows = ns.VisibleRows(query, filter, category)
        window.addons:Set(rows, top)
        window.empty:SetShown(#rows == 0)
        window.empty:SetText(filter == "disabled" and ns.Trim(query) == "" and not category
            and L("No disabled addons. Choose All to see the list.", "Нет отключенных аддонов. Нажмите «Все», чтобы увидеть список.")
            or L("No matching addons.", "Аддоны не найдены."))
    else
        PaintProfiles(names)
    end

    local changes = ns.Changes(ns.catalog.states)
    local blocked = ns.ApplyBlock()
    if notice == ns.combatMessage and blocked ~= notice then notice = nil end
    local counts, enabled = {}, 0
    for _, row in ipairs(changes) do if ns.draft[row.key] then enabled = enabled + 1 end end
    if enabled > 0 then counts[#counts + 1] = L("enable %d", "включить %d"):format(enabled) end
    if #changes > enabled then counts[#counts + 1] = L("disable %d", "отключить %d"):format(#changes - enabled) end
    local message = notice or (#changes > 0 and blocked)
    local summary = #counts > 0 and L("Pending: %s", "К применению: %s"):format(table.concat(counts, " · "))
        or L("No changes", "Нет изменений")
    window.summary:SetText(message and (#changes > 0 and (message .. "\n" .. summary) or message) or summary)
    window.cancel:SetShown(#changes > 0)
    window.apply:SetShown(#changes > 0 and not blocked)
end

local function LayoutWidth(frame, width)
    if popup and popup:IsShown() then popup:SetWidth(math.min(500, width - 24)) end
    local compact = width < 575
    if frame.compact == compact then return end
    frame.compact = compact
    frame.character:SetWidth(compact and 83 or 160)
    frame.addonsTab:SetWidth(compact and 63 or 72)
    frame.profilesTab:SetWidth(compact and 66 or 76)
    frame.profilePicker:SetWidth(compact and 110 or 139)
    frame.load:SetWidth(compact and 70 or 76)
    frame.save:SetWidth(compact and 72 or 76)
    local padding = compact and 4 or (S.widgets and 6 or 7)
    for _, button in ipairs({frame.addonsTab, frame.profilesTab, frame.load, frame.save}) do
        button.text:ClearAllPoints()
        Anchor(button.text, padding, -padding)
    end
    frame.category:SetWidth(compact and 110 or 134)
    frame.category.text:SetText(category or (compact and L("Categories", "Категории")
        or L("All categories", "Все категории")))
    for _, button in ipairs(frame.filters) do
        button:SetWidth(compact and button.compactWidth or button.fullWidth)
        button.text:SetText(compact and button.shortLabel or button.fullLabel)
    end
    frame.profiles.details:SetPoint("TOPLEFT", frame.profiles, "TOP", compact and -42 or -26, 0)
    frame.profiles.heading:SetText(compact and L("Profiles", "Профили") or L("Saved profiles", "Сохраненные профили"))
    frame.statusHeading:SetText(compact and L("State", "Состояние") or L("Now / after", "Сейчас / после"))
end

local function Build()
    local frame = S.Surface(UIParent, "SintezzaManagerWindow", "window")
    frame:Hide()
    frame:SetSize(size.width, size.height)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    table.insert(UISpecialFrames, frame:GetName())
    local header = S.Header(frame, ns.title, function() frame:Hide() end, ns.version)
    frame.header = header
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        if size.CanMove() then frame:StartMoving() end
    end)
    header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    frame.character = S.Label(header, "", 13, T.muted)
    frame.character:SetPoint("RIGHT", -45, 0)
    frame.character:SetWidth(160)
    frame.character:SetJustifyH("RIGHT")
    frame.character:SetWordWrap(false)
    frame.addonsTab = Button(frame, L("AddOns", "Аддоны"), 72, function() SetPage("addons") end)
    frame.addonsTab:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 10, -6)
    frame.profilesTab = Button(frame, L("Profiles", "Профили"), 76, function() SetPage("profiles") end)
    frame.profilesTab:SetPoint("LEFT", frame.addonsTab, "RIGHT", 5, 0)
    S.Selected(frame.addonsTab, page == "addons")
    S.Selected(frame.profilesTab, page == "profiles")

    frame.quick = CreateFrame("Frame", nil, frame)
    frame.quick:SetSize(362, 25)
    frame.quick:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -10, -6)
    frame.save = Button(frame.quick, L("Save", "Сохранить"), 76, SaveSelected)
    frame.save:SetPoint("RIGHT")
    frame.load = Button(frame.quick, L("Load", "Загрузить"), 76, LoadSelected)
    frame.load:SetPoint("RIGHT", frame.save, "LEFT", -5, 0)
    frame.profilePicker = Dropdown(frame.quick, 139, OpenProfilePicker)
    frame.profilePicker:SetPoint("RIGHT", frame.load, "LEFT", -5, 0)
    local profileLabel = S.Label(frame.quick, L("Profile", "Профиль"), 12, T.muted)
    profileLabel:SetPoint("RIGHT", frame.profilePicker, "LEFT", -7, 0)
    profileLabel:SetWidth(52)
    profileLabel:SetJustifyH("RIGHT")
    profileLabel:SetWordWrap(false)
    frame.profileLabel = profileLabel

    frame.addonPage = CreateFrame("Frame", nil, frame)
    frame.addonPage:SetPoint("TOPLEFT", frame.addonsTab, "BOTTOMLEFT", 0, -6)
    frame.addonPage:SetPoint("BOTTOMRIGHT", -10, 43)
    frame.profiles = ProfilePanel(frame)
    frame.profiles:SetPoint("TOPLEFT", frame.addonPage, "TOPLEFT")
    frame.profiles:SetPoint("BOTTOMRIGHT", frame.addonPage, "BOTTOMRIGHT")
    frame.profiles:SetShown(page == "profiles")
    frame.addonPage:SetShown(page == "addons")
    frame.quick:SetShown(page == "addons")

    local filters = {
        {id = "disabled", label = L("Disabled", "Отключенные"), short = L("Off", "Откл."), width = 99, narrow = 57},
        {id = "enabled", label = L("Enabled", "Включенные"), short = L("On", "Вкл."), width = 99, narrow = 51},
        {id = "all", label = L("All", "Все"), short = L("All", "Все"), width = 42, narrow = 38},
    }
    local buttons = {}
    frame.filters = buttons
    for index, data in ipairs(filters) do
        local button = Button(frame.addonPage, data.label, data.width, function(self)
            filter = self.filter
            Draw(true)
        end)
        button.filter = data.id
        button.fullWidth, button.compactWidth = data.width, data.narrow
        button.fullLabel, button.shortLabel = data.label, data.short
        buttons[index] = button
    end
    frame.category = Dropdown(frame.addonPage, 134, OpenCategories)
    frame.category:SetPoint("TOPRIGHT")
    frame.search = S.Input(frame.addonPage, L("Find addon…", "Найти аддон…"))
    frame.search:SetPoint("TOPLEFT")
    frame.search:SetPoint("RIGHT", frame.category, "LEFT", -5, 0)
    frame.search:HookScript("OnTextChanged", function() Draw(true) end)
    buttons[1]:SetPoint("TOPLEFT", frame.search, "BOTTOMLEFT", 0, -5)
    buttons[2]:SetPoint("LEFT", buttons[1], "RIGHT", 4, 0)
    buttons[3]:SetPoint("LEFT", buttons[2], "RIGHT", 4, 0)

    local listPanel = CreateFrame("Frame", nil, frame.addonPage)
    listPanel:SetPoint("TOPLEFT", buttons[1], "BOTTOMLEFT", 0, -4)
    listPanel:SetPoint("BOTTOMRIGHT")
    local columns = S.Label(listPanel, L("Addon and modules", "Аддон и модули"), 12, T.muted)
    columns:SetPoint("TOPLEFT", 55, -6)
    frame.statusHeading = S.Label(listPanel, "", 11, T.muted)
    frame.statusHeading:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", -126, -6)
    local divider = listPanel:CreateTexture(nil, "ARTWORK")
    S.Tint(divider, "SetColorTexture", T.lineSoft)
    divider:SetPoint("TOPLEFT", 0, -21)
    divider:SetPoint("TOPRIGHT", 0, -21)
    divider:SetHeight(1)
    frame.addons = List(listPanel, ADDON_ROW_HEIGHT, AddonRow, PaintAddon)
    frame.addons.scroll:SetPoint("TOPLEFT", 1, -22)
    frame.addons.scroll:SetPoint("BOTTOMRIGHT", -22, 1)
    frame.empty = S.Label(listPanel, "", 13, T.muted)
    frame.empty:SetPoint("TOPLEFT", frame.addons.scroll, "TOPLEFT", 12, -12)

    frame.summary = S.Label(frame, "", 12, T.muted)
    frame.summary:SetPoint("BOTTOMLEFT", 12, 8)
    frame.summary:SetPoint("BOTTOMRIGHT", -230, 8)
    frame.summary:SetHeight(31)
    frame.summary:SetWordWrap(true)
    frame.apply = Button(frame, L("Apply", "Применить"), 106, function()
        local blocked = ns.ApplyBlock()
        if blocked then notice = blocked; Draw(); return end
        Confirm(L("Before reloading", "Перед перезагрузкой"),
            L("These addon changes apply to %s after reloading the interface.",
                "Правки вступят в силу для персонажа %s после перезагрузки интерфейса."):format(ns.character),
            L("Apply and reload", "Применить и перезагрузить"),
            ns.Changes(ns.catalog.states), false, ns.Apply)
    end, true)
    frame.apply:SetPoint("BOTTOMRIGHT", -25, 10)
    frame.cancel = Button(frame, L("Cancel", "Отменить"), 106, function()
        ns.Reset()
        notice = nil
        Draw()
    end)
    frame.cancel:SetPoint("RIGHT", frame.apply, "LEFT", -7, 0)
    frame:SetScript("OnHide", function()
        frame.search:ClearFocus()
        if popup then popup:Hide() end
    end)
    frame:HookScript("OnSizeChanged", LayoutWidth)
    size.Bind(frame)
    LayoutWidth(frame, frame:GetWidth())
    return frame
end

function ns.Open()
    local ok, message, changed = ns.Refresh()
    if not ok then return false, message end
    if changed then notice = nil end
    if not window then window = Build() end
    size.FitStandalone()
    window.character:SetText(ns.character)
    window:Show()
    window:Raise()
    Draw()
    return true
end

function ns.Redraw()
    Draw()
end
