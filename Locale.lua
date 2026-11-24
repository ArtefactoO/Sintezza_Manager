local addon, ns = ...
ns.title = "Sintezza Addons Manager"
local theme = Sintezza_Theme
local locale = theme and type(theme.GetLocale) == "function" and theme:GetLocale() or GetLocale()
ns.ru = locale == "ruRU"

function ns.Text(english, russian)
    return ns.ru and russian or english
end

function ns.Trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

function ns.Key(value)
    return (value:gsub("[A-Z]", string.lower))
end

function ns.Fold(value)
    return (ns.Key(value):gsub("\208[\144-\175]", function(letter)
        local byte = letter:byte(2)
        if byte < 160 then return string.char(208, byte + 32) end
        return string.char(209, byte - 32)
    end):gsub("Ё", "е"):gsub("ё", "е"))
end

function ns.Readable(value)
    return (not issecretvalue or not issecretvalue(value)) and type(value) == "string"
end

function ns.Plain(value)
    if not ns.Readable(value) then return "" end
    return ns.Trim((value:gsub("|[cC]%x%x%x%x%x%x%x%x", ""):gsub("|[rR]", "")
        :gsub("|[Tt].-|[Tt]", ""):gsub("|[Aa].-|[Aa]", ""):gsub("|", ""):gsub("[%z\1-\31\127]", " ")))
end

local metadata = C_AddOns and C_AddOns.GetAddOnMetadata
local version = metadata and metadata(addon, "Version")
ns.version = ns.Readable(version) and version:match("^%d") and version or "0.2.0"
