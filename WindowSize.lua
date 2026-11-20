local _, ns = ...
local shared, colors = ns.Style.shared, ns.Style.palette
local size = {width = 740, height = 434, minWidth = 480, minHeight = 410, maxWidth = 1500, maxHeight = 1000}
local resizeKey = "manager"
local window
ns.WindowSize = size

if shared and shared.NewWindowPreferences and shared.RegisterGlobalWindowPreferences then
    size.prefs = shared:NewWindowPreferences(function() return ns.db end)
    shared:RegisterGlobalWindowPreferences(ns.title, size.prefs)
end

function size.CanMove()
    return not InCombatLockdown() and (not size.prefs or size.prefs:CanMove())
end

function size.FitStandalone()
    if not window or size.prefs or InCombatLockdown() then return end
    window:SetScale(math.max(.1, math.min(1, (UIParent:GetWidth() - 24) / window:GetWidth(),
        (UIParent:GetHeight() - 24) / window:GetHeight())))
end

local function Bound(value, lower, upper, default)
    if type(value) ~= "number" or value ~= value then return default end
    return math.max(lower, math.min(upper, value))
end

local function StandaloneStore()
    if type(ns.db.windowAppearance) ~= "table" then ns.db.windowAppearance = {} end
    local db = ns.db.windowAppearance
    if type(db.sizes) ~= "table" then db.sizes = {} end
    return db.sizes
end

function size.Reset()
    if size.prefs then size.prefs:ResetSize(); return end
    if InCombatLockdown() then return end
    StandaloneStore()[resizeKey] = nil
    if window then
        window:SetSize(size.width, size.height)
        size.FitStandalone()
    end
end

function size.Bind(frame)
    window = frame
    if size.prefs then
        size.prefs:Bind(frame, {
            resize = {
                key = resizeKey, width = size.width, height = size.height,
                minWidth = size.minWidth, minHeight = size.minHeight,
                maxWidth = size.maxWidth, maxHeight = size.maxHeight,
            },
        })
        return
    end

    local stored = StandaloneStore()[resizeKey]
    if type(stored) == "table" then
        frame:SetSize(Bound(stored.width, size.minWidth, size.maxWidth, size.width),
            Bound(stored.height, size.minHeight, size.maxHeight, size.height))
    end
    frame:SetResizable(true)
    frame:SetResizeBounds(size.minWidth, size.minHeight, size.maxWidth, size.maxHeight)
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(19, 19)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:RegisterForDrag("LeftButton")
    for index = 1, 3 do
        local stroke = grip:CreateTexture(nil, "ARTWORK")
        stroke:SetSize(3 + index * 3, 1.4)
        stroke:SetRotation(math.pi / 4)
        stroke:SetPoint("CENTER", grip, "BOTTOMRIGHT", -2 - index * 2, 2 + index * 2)
        ns.Style.Tint(stroke, "SetColorTexture", colors.muted)
    end
    local dragging
    local function Stop()
        if not dragging then return end
        dragging = nil
        frame:StopMovingOrSizing()
        StandaloneStore()[resizeKey] = {width = frame:GetWidth(), height = frame:GetHeight()}
        size.FitStandalone()
    end
    grip:SetScript("OnDragStart", function()
        if size.CanMove() then
            dragging = true
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    grip:SetScript("OnDragStop", Stop)
    frame:HookScript("OnHide", Stop)
    size.FitStandalone()
end
