local addon, ns = ...
local shared = Sintezza_Theme
local themed = shared and type(shared.ForAddon) == "function" and type(shared.CreateWidgets) == "function"
local fallback = {
    bg = {.098, .071, .055, 1}, panel = {.135, .090, .071, 1},
    input = {.106, .075, .059, 1}, line = {.55, .37, .26, 1},
    lineSoft = {.35, .23, .18, 1}, text = {.98, .91, .85, 1},
    muted = {.82, .71, .64, 1}, accent = {.91, .65, .48, 1},
    accentDim = {.30, .18, .12, 1}, panelHover = {.23, .155, .104, 1},
}
local T = themed and shared:ForAddon() or fallback
local W = themed and shared:CreateWidgets(T)
local S = {palette = T, shared = themed and shared, widgets = W}
local white = "Interface\\Buttons\\WHITE8X8"
S.icon = "Interface\\AddOns\\" .. addon .. "\\Media\\Icon"
ns.Style = S

function S.Tint(target, method, color)
    if W then shared:Tint(target, method, color)
    else target[method](target, unpack(color)) end
end

function S.Backdrop(frame, fill, line)
    if W then T:Backdrop(frame, fill, line)
    else
        frame:SetBackdrop({bgFile = white, edgeFile = white, edgeSize = 1})
        frame:SetBackdropColor(unpack(fill))
        frame:SetBackdropBorderColor(unpack(line))
    end
end

function S.Surface(parent, name, role)
    if W then return W:Surface(parent, name, role) end
    local frame = CreateFrame("Frame", name, parent, "BackdropTemplate")
    if role == "window" then S.Backdrop(frame, T.bg, T.line)
    else S.Backdrop(frame, role == "sidebar" and T.input or T.panel, T.lineSoft) end
    return frame
end

function S.Label(parent, text, size, color, role)
    if W then return W:Label(parent, text, size, color or T.text, role) end
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local font = label:GetFont()
    if font then label:SetFont(font, size, "") end
    label:SetText(text or "")
    label:SetTextColor(unpack(color or T.text))
    label:SetJustifyH("LEFT")
    return label
end

function S.Button(parent, label, action, primary)
    if W then return W:Button(parent, label, action, primary) end
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    S.Backdrop(button, T.panel, T.lineSoft)
    button.text = S.Label(button, label, 12)
    button.text:SetPoint("LEFT", 7, 0)
    button.text:SetPoint("RIGHT", -7, 0)
    button.text:SetJustifyH("CENTER")
    button.text:SetWordWrap(false)
    local function Paint()
        local enabled = button:IsEnabled()
        local selected = primary or button.selected
        local fill = enabled and (button.hover and T.panelHover or selected and T.accentDim) or nil
        button:SetBackdropColor(unpack(fill or T.panel))
        button:SetBackdropBorderColor(unpack(enabled and (selected and T.line or T.lineSoft) or T.lineSoft))
        button.text:SetAlpha(enabled and 1 or .55)
    end
    button.paintSelection = Paint
    button:SetScript("OnEnter", function() button.hover = true; Paint() end)
    button:SetScript("OnLeave", function() button.hover = false; Paint() end)
    button:SetScript("OnEnable", Paint)
    button:SetScript("OnDisable", Paint)
    button:SetScript("OnClick", action)
    Paint()
    return button
end

function S.Selected(button, selected)
    if W then T:PaintButton(button, selected)
    else
        button.selected = selected
        button.paintSelection()
    end
end

function S.Input(parent, placeholder)
    local edit
    if W then
        edit = W:EditBox(parent, placeholder, function() end)
    else
        edit = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
        edit:SetAutoFocus(false)
        edit:SetFontObject(GameFontHighlightSmall)
        edit:SetTextInsets(9, 9, 0, 0)
        S.Backdrop(edit, T.input, T.lineSoft)
        local hint = S.Label(edit, placeholder, 12, T.muted)
        hint:SetPoint("LEFT", 9, 0)
        edit:SetScript("OnTextChanged", function(self) hint:SetShown(self:GetText() == "") end)
        edit:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(unpack(T.accent)) end)
        edit:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(unpack(T.lineSoft)) end)
    end
    edit:SetHeight(25)
    edit:SetScript("OnEnterPressed", edit.ClearFocus)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    return edit
end

function S.CheckButton(parent)
    local button = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
    local size = 20
    button:SetSize(size, size)
    if W and T.SkinCheckButton then
        T:SkinCheckButton(button, size - 2)
    else
        S.Backdrop(button, T.input, T.lineSoft)
        local mark = button:CreateTexture(nil, "ARTWORK")
        mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        mark:SetDesaturated(true)
        mark:SetAllPoints()
        S.Tint(mark, "SetVertexColor", T.accent)
        button:SetCheckedTexture(mark)
    end
    return button
end

function S.Header(window, title, close, version)
    if W then
        return W:WindowHeader(window, {
            title = title, version = version, icon = S.icon, onClose = close, close = close ~= nil, height = 43, titleSize = 19,
        })
    end
    local header = S.Surface(window, nil, "panel")
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(43)
    local icon = header:CreateTexture(nil, "ARTWORK")
    icon:SetSize(22, 22)
    icon:SetPoint("LEFT", 13, 0)
    icon:SetTexture(S.icon)
    local label = S.Label(header, title, 20)
    label:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    header.title = label
    if version then
        header.version = S.Label(header, "v" .. version, 9, T.muted)
        header.version:SetPoint("LEFT", label, "RIGHT", 10, -1)
    end
    if close then
        header.close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
        header.close:SetPoint("RIGHT", -5, 0)
        header.close:SetScript("OnClick", close)
    end
    return header
end

function S.Scroll(parent, step)
    if W then
        local scroll, body, bar = W:ScrollFrame(parent, nil, step)
        bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 3, 0)
        bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 3, 0)
        return scroll, body
    end
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    local body = CreateFrame("Frame", nil, scroll)
    body:SetSize(1, 1)
    scroll:SetScrollChild(body)
    return scroll, body
end

function S.Tooltip(owner, title, text)
    if W and W.Tooltip then W:Tooltip(owner, title, text)
    else
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetText(title)
        if text and text ~= "" then GameTooltip:AddLine(text, 1, 1, 1, true) end
        GameTooltip:Show()
    end
end

function S.HideTooltip(owner)
    if W and shared.HideTooltip then shared:HideTooltip(owner)
    elseif GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
end
