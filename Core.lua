local addon, ns = ...
local L = ns.Text
local ownKey = ns.Key(addon)
ns.combatMessage = L("You can apply changes after combat.", "Применить правки можно после боя.")
local apiMembers = {
    "GetNumAddOns", "GetAddOnInfo", "GetAddOnMetadata", "GetAddOnDependencies",
    "GetAddOnEnableState", "EnableAddOn", "DisableAddOn", "SaveAddOns",
}

local function Copy(values)
    local result = {}
    for key, value in pairs(values) do result[key] = value end
    return result
end

function ns.Available()
    if not C_AddOns or type(ReloadUI) ~= "function" then return false end
    for _, name in ipairs(apiMembers) do
        if type(C_AddOns[name]) ~= "function" then return false end
    end
    return true
end

function ns.InitDB(saved)
    local db = type(saved) == "table" and saved or {}
    local profiles, collapsed = {}, {}
    if type(db.profiles) == "table" then
        for name, states in pairs(db.profiles) do
            if type(name) == "string" and name ~= "" and type(states) == "table" then
                local clean = {}
                for key, enabled in pairs(states) do
                    if type(key) == "string" and type(enabled) == "boolean" then clean[ns.Key(key)] = enabled end
                end
                profiles[name] = clean
            end
        end
    end
    if type(db.collapsed) == "table" then
        for key, value in pairs(db.collapsed) do
            if type(key) == "string" and value == true then collapsed[ns.Key(key)] = true end
        end
    end
    db.profiles, db.collapsed = profiles, collapsed
    ns.db = db
    return db
end

local function ReadState(id, guid)
    local state = C_AddOns.GetAddOnEnableState(id, guid)
    if (issecretvalue and issecretvalue(state)) or type(state) ~= "number" then
        error("Unreadable addon enable state")
    end
    return state > Enum.AddOnEnableState.None
end

local function GroupAddons(catalog)
    local function ParentFor(row, key)
        local parent = catalog.entries[key]
        if not parent or parent.secure then return end
        local ancestor = parent
        while ancestor do
            if ancestor == row then return end
            ancestor = ancestor.parent
        end
        return parent
    end

    for _, row in ipairs(catalog.rows) do
        if not row.secure then
            local parent = ParentFor(row, row.group)
            if not parent then
                for _, dependency in ipairs(row.needs) do
                    parent = ParentFor(row, dependency.key)
                    if parent then break end
                end
            end
            if parent then
                row.parent = parent
                parent.children[#parent.children + 1] = row
            end
        end
    end
end

local function ReadCatalog(guid)
    local catalog = {rows = {}, entries = {}, states = {}, dependents = {}, categories = {}}
    for index = 1, C_AddOns.GetNumAddOns() do
        local id, title, _, _, _, security = C_AddOns.GetAddOnInfo(index)
        if ns.Readable(id) and id ~= "" then
            local key = ns.Key(id)
            local secure, banned = false, false
            if ns.Readable(security) then secure, banned = security == "SECURE", security == "BANNED" end
            local label = ns.Plain(title)
            local category = ns.Plain(C_AddOns.GetAddOnMetadata(index, "Category"))
            if category == "" then category = ns.Plain(C_AddOns.GetAddOnMetadata(index, "X-Category")) end
            local group = C_AddOns.GetAddOnMetadata(index, "Group")
            local row = {
                id = id, key = key, title = label ~= "" and label or id, category = category,
                group = ns.Readable(group) and ns.Key(ns.Trim(group)) or nil,
                secure = secure, banned = banned, locked = key == ownKey or secure or banned,
                needs = {}, children = {},
            }
            row.search = ns.Fold(row.title .. " " .. id)
            for _, dependency in ipairs({C_AddOns.GetAddOnDependencies(index)}) do
                if ns.Readable(dependency) and dependency ~= "" then
                    local dep = ns.Key(dependency)
                    row.needs[#row.needs + 1] = {key = dep, id = dependency}
                    local dependents = catalog.dependents[dep] or {}
                    dependents[#dependents + 1] = row
                    catalog.dependents[dep] = dependents
                end
            end
            catalog.entries[key] = row
            catalog.states[key] = ReadState(index, guid)
            catalog.rows[#catalog.rows + 1] = row
            if not secure and category ~= "" then catalog.categories[category] = true end
        end
    end
    table.sort(catalog.rows, function(a, b)
        local left, right = ns.Fold(a.title), ns.Fold(b.title)
        if left == right then return a.key < b.key end
        return left < right
    end)
    GroupAddons(catalog)
    return catalog
end

local function SameCatalog(a, b)
    if not a or #a.rows ~= #b.rows then return false end
    for key, row in pairs(a.entries) do
        local fresh = b.entries[key]
        if not fresh or a.states[key] ~= b.states[key] or row.locked ~= fresh.locked
            or #row.needs ~= #fresh.needs then return false end
        for index, dep in ipairs(row.needs) do
            if fresh.needs[index].key ~= dep.key then return false end
        end
    end
    return true
end

local function ReadCurrent()
    if not ns.Available() then
        return nil, L("Addon management is unavailable in this client.", "Управление аддонами недоступно в этом клиенте.")
    end
    local guid = UnitGUID("player")
    if not ns.Readable(guid) or guid == "" then
        return nil, L("The character is not ready yet.", "Дождитесь входа персонажа в игру.")
    end
    local ok, catalog = pcall(ReadCatalog, guid)
    if not ok then
        return nil, L("Couldn't read the addon list.", "Не удалось прочитать список аддонов.")
    end
    return catalog, nil, guid
end

function ns.Refresh()
    local fresh, message, guid = ReadCurrent()
    if not fresh then return false, message end
    local changed = ns.guid ~= guid or not SameCatalog(ns.catalog, fresh)
    ns.guid, ns.catalog = guid, fresh
    if changed then ns.draft = Copy(fresh.states) end
    ns.character = ns.Plain(UnitName("player"))
    return true, nil, changed
end

local function Locked(row)
    return L("%s can't be changed here.", "Состояние аддона %s здесь изменить нельзя."):format(row.title)
end

local function Enable(states, row, seen)
    if seen[row.key] then return true end
    seen[row.key] = true
    if row.banned or (row.locked and not states[row.key]) then return false, Locked(row) end
    for _, need in ipairs(row.needs) do
        local dep = ns.catalog.entries[need.key]
        if not dep then
            return false, L("%s requires %s, which is not installed.", "Для %s нужен аддон %s, которого нет в списке."):format(row.title, need.id)
        end
        local ok, message = Enable(states, dep, seen)
        if not ok then return false, message end
    end
    states[row.key] = true
    return true
end

local function Disable(states, row)
    if not states[row.key] then return true end
    if row.locked then return false, Locked(row) end
    states[row.key] = false
    for _, owner in ipairs(ns.catalog.dependents[row.key] or {}) do
        local ok, message = Disable(states, owner)
        if not ok then return false, message end
    end
    return true
end

function ns.SetEnabled(key, enabled)
    local row = ns.catalog.entries[key]
    if not row then return false end
    if row.locked then return false, Locked(row) end
    local states = Copy(ns.draft)
    local ok, message
    if enabled then ok, message = Enable(states, row, {})
    else ok, message = Disable(states, row) end
    if ok then ns.draft = states end
    return ok, message
end

local function CollectModules(row, modules)
    for _, child in ipairs(row.children) do
        modules[#modules + 1] = child
        CollectModules(child, modules)
    end
end

function ns.SetGroupEnabled(key, enabled)
    local parent = ns.catalog.entries[key]
    if not parent or #parent.children == 0 then return false end
    local states, seen, modules = Copy(ns.draft), {}, {}
    CollectModules(parent, modules)
    for _, row in ipairs(modules) do
        if not row.locked and (enabled or states[row.key]) then
            local ok, message
            if enabled then ok, message = Enable(states, row, seen)
            else ok, message = Disable(states, row) end
            if not ok then return false, message end
        end
    end
    ns.draft = states
    return true
end

function ns.ToggleGroup(key)
    local row = ns.catalog.entries[key]
    if not row or #row.children == 0 then return end
    ns.db.collapsed[key] = not ns.db.collapsed[key] or nil
end

function ns.Reset()
    ns.draft = Copy(ns.catalog.states)
end

function ns.Changes(base)
    local changes = {}
    for _, row in ipairs(ns.catalog.rows) do
        if not row.locked and ns.draft[row.key] ~= base[row.key] then changes[#changes + 1] = row end
    end
    return changes
end

function ns.ProfileNames()
    local names = {}
    for name in pairs(ns.db.profiles) do names[#names + 1] = name end
    table.sort(names, function(a, b)
        local left, right = ns.Fold(a), ns.Fold(b)
        if left == right then return a < b end
        return left < right
    end)
    return names
end

function ns.ProfileTarget(profile)
    local saved = ns.db.profiles[profile]
    if not saved then return end
    local states, seen = Copy(ns.catalog.states), {}
    for _, row in ipairs(ns.catalog.rows) do
        if not row.locked and saved[row.key] == false then
            local ok, message = Disable(states, row)
            if not ok then return nil, message end
        end
    end
    for _, row in ipairs(ns.catalog.rows) do
        if not row.locked and saved[row.key] == true and not states[row.key] then
            local ok, message = Enable(states, row, seen)
            if not ok then return nil, message end
        end
    end
    return states
end

function ns.LoadProfile(profile)
    local states, message = ns.ProfileTarget(profile)
    if not states then return false, message end
    ns.draft = states
    return true
end

function ns.SaveProfile(profile)
    local saved = Copy(ns.db.profiles[profile] or {})
    for _, row in ipairs(ns.catalog.rows) do
        if not row.locked then saved[row.key] = ns.draft[row.key] end
    end
    ns.db.profiles[profile] = saved
end

local function ProfileName(name, except)
    name = ns.Trim(name)
    if name == "" or #name > 120 or name:find("[|%z\1-\31\127]") then
        return nil, L("Enter a valid profile name.", "Введите допустимое название профиля.")
    end
    local folded = ns.Fold(name)
    for existing in pairs(ns.db.profiles) do
        if existing ~= except and ns.Fold(existing) == folded then
            return nil, L("A profile with that name already exists.", "Профиль с таким названием уже есть.")
        end
    end
    return name
end

function ns.NewProfile(name)
    local valid, message = ProfileName(name)
    if not valid then return nil, message end
    ns.SaveProfile(valid)
    return valid
end

function ns.DuplicateProfile(profile, name)
    local saved = ns.db.profiles[profile]
    if not saved then return nil, L("Profile not found.", "Профиль не найден.") end
    local valid, message = ProfileName(name)
    if not valid then return nil, message end
    ns.db.profiles[valid] = Copy(saved)
    return valid
end

function ns.RenameProfile(profile, name)
    local saved = ns.db.profiles[profile]
    if not saved then return nil, L("Profile not found.", "Профиль не найден.") end
    local valid, message = ProfileName(name, profile)
    if not valid then return nil, message end
    if valid ~= profile then
        ns.db.profiles[profile], ns.db.profiles[valid] = nil, saved
    end
    return valid
end

function ns.ApplyBlock()
    if InCombatLockdown() then
        return ns.combatMessage
    end
    if AddonList and AddonList:IsShown() then
        return L("Close the built-in AddOns window before applying.", "Перед применением закройте штатный список аддонов.")
    end
end

local function WriteState(row, guid, enabled)
    local setter = enabled and C_AddOns.EnableAddOn or C_AddOns.DisableAddOn
    local ok = pcall(setter, row.id, guid)
    local read, actual = pcall(ReadState, row.id, guid)
    return ok and read and actual == enabled
end

local function OrderChanges(changed)
    local affected, seen, ordered = {}, {}, {}
    for _, row in ipairs(changed) do affected[row.key] = row end
    local function Visit(row)
        if seen[row.key] then return end
        seen[row.key] = true
        local enabled = ns.draft[row.key]
        local neighbors = enabled and row.needs or ns.catalog.dependents[row.key] or {}
        for _, adjacent in ipairs(neighbors) do
            local other = affected[adjacent.key]
            if other and ns.draft[other.key] == enabled then Visit(other) end
        end
        ordered[#ordered + 1] = row
    end
    for _, row in ipairs(changed) do Visit(row) end
    return ordered
end

function ns.Apply()
    local blocked = ns.ApplyBlock()
    if blocked then return false, blocked end
    local fresh, message, guid = ReadCurrent()
    if not fresh then return false, message end
    if guid ~= ns.guid or not SameCatalog(ns.catalog, fresh) then
        ns.Refresh()
        return false, L("The addon list changed. Review it before applying again.", "Список аддонов изменился. Проверьте его перед применением.")
    end
    local changed = ns.Changes(fresh.states)
    if #changed == 0 then return false end
    local written, ok = {}, true
    for _, row in ipairs(OrderChanges(changed)) do
        written[#written + 1] = row
        if not WriteState(row, guid, ns.draft[row.key]) then
            ok = false
            break
        end
    end
    local attemptedSave = ok
    if ok then ok = pcall(C_AddOns.SaveAddOns) end
    if not ok then
        local restored = true
        for index = #written, 1, -1 do
            local row = written[index]
            if not WriteState(row, guid, fresh.states[row.key]) then restored = false end
        end
        if attemptedSave and not pcall(C_AddOns.SaveAddOns) then restored = false end
        if restored then
            return false, L("Couldn't apply changes. The previous state was restored.", "Не удалось применить правки. Прежнее состояние восстановлено.")
        end
        ns.Refresh()
        return false, L("Couldn't fully restore the addon state. Check the list before reloading.", "Не удалось полностью восстановить состояние аддонов. Проверьте список перед перезагрузкой.")
    end
    ns.catalog.states = Copy(ns.draft)
    if not pcall(ReloadUI) then
        return false, L("Changes were saved. Run /reload to finish.", "Правки сохранены. Выполните /reload, чтобы завершить применение.")
    end
    return true
end

local function AddBranch(output, row, depth, visible, matched, searching)
    if not visible[row.key] then return end
    local item = {row = row, depth = depth}
    output[#output + 1] = item
    if #row.children > 0 then
        local modules = {}
        CollectModules(row, modules)
        item.on, item.off = 0, 0
        for _, module in ipairs(modules) do
            if ns.draft[module.key] then item.on = item.on + 1
            else item.off = item.off + 1 end
        end
        for _, child in ipairs(row.children) do
            if visible[child.key] then item.hasChildren = true; break end
        end
        item.collapsed = not searching and ns.db.collapsed[row.key]
        item.searching = searching
    end
    if matched[row.key] then
        for _, need in ipairs(row.needs) do
            if not ns.catalog.entries[need.key] then
                output[#output + 1] = {row = need, depth = depth + 1, missing = true}
            end
        end
    end
    if item.collapsed then return end
    for _, child in ipairs(row.children) do AddBranch(output, child, depth + 1, visible, matched, searching) end
end

local function Reveal(row, visible)
    local ancestor = row
    while ancestor and not visible[ancestor.key] do
        visible[ancestor.key] = true
        ancestor = ancestor.parent
    end
end

function ns.VisibleRows(query, filter, category)
    local matched, visible, included, output = {}, {}, {}, {}
    query = ns.Fold(ns.Trim(query))
    for _, row in ipairs(ns.catalog.rows) do
        if not row.secure and (not category or row.category == category) and row.search:find(query, 1, true) then
            matched[row.key] = true
            Reveal(row, visible)
            if filter == "all" or (filter == "enabled") == ns.catalog.states[row.key] then
                Reveal(row, included)
            end
        end
    end
    for _, row in ipairs(ns.catalog.rows) do
        if not row.parent and included[row.key] then AddBranch(output, row, 0, visible, matched, query ~= "") end
    end
    return output
end
