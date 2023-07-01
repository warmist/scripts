--@ module = true

CH_UP = string.char(30)
CH_DN = string.char(31)

local to_pen = dfhack.pen.parse
SOME_PEN = to_pen{ch=':', fg=COLOR_YELLOW}
ALL_PEN = to_pen{ch='+', fg=COLOR_LIGHTGREEN}

function make_search_key(str)
    local out = ''
    for c in str:gmatch("[%w%s]") do
        out = out .. c:lower()
    end
    return out
end

-- adapted from https://stackoverflow.com/a/50860705
local function sig_fig(num, figures)
    if num <= 0 then return 0 end
    local x = figures - math.ceil(math.log(num, 10))
    return math.floor(math.floor(num * 10^x + 0.5) * 10^-x)
end

function obfuscate_value(value)
    -- TODO: respect skill of broker
    local num_sig_figs = 1
    local str = tostring(sig_fig(value, num_sig_figs))
    if #str > num_sig_figs then str = '~' .. str end
    return str
end

local function to_title_case(str)
    str = str:gsub('(%a)([%w_]*)',
        function (first, rest) return first:upper()..rest:lower() end)
    str = str:gsub('_', ' ')
    return str
end

local function get_item_type_str(item)
    local str = to_title_case(df.item_type[item:getType()])
    if str == 'Trapparts' then
        str = 'Mechanism'
    end
    return str
end

function get_artifact_name(item)
    local gref = dfhack.items.getGeneralRef(item, df.general_ref_type.IS_ARTIFACT)
    if not gref then return end
    local artifact = df.artifact_record.find(gref.artifact_id)
    if not artifact then return end
    local name = dfhack.TranslateName(artifact.name)
    return ('%s (%s)'):format(name, get_item_type_str(item))
end

-- takes into account trade agreements
function get_perceived_value(item)
    -- TODO: take trade agreements into account
    local value = dfhack.items.getValue(item)
    for _,contained_item in ipairs(dfhack.items.getContainedItems(item)) do
        value = value + dfhack.items.getValue(contained_item)
        for _,contained_contained_item in ipairs(dfhack.items.getContainedItems(contained_item)) do
            value = value + dfhack.items.getValue(contained_contained_item)
        end
    end
    return value
end
