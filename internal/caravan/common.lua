--@ module = true

CH_UP = string.char(30)
CH_DN = string.char(31)
CH_MONEY = string.char(15)
CH_EXCEPTIONAL = string.char(240)

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

local function get_broker_skill()
    local broker = dfhack.units.getUnitByNobleRole('broker')
    if not broker then return 0 end
    for _,skill in ipairs(broker.status.current_soul.skills) do
        if skill.id == df.job_skill.APPRAISAL then
            return skill.rating
        end
    end
    return 0
end

local function get_threshold(broker_skill)
    if broker_skill <= df.skill_rating.Dabbling then return 0 end
    if broker_skill <= df.skill_rating.Novice then return 10 end
    if broker_skill <= df.skill_rating.Adequate then return 25 end
    if broker_skill <= df.skill_rating.Competent then return 50 end
    if broker_skill <= df.skill_rating.Skilled then return 100 end
    if broker_skill <= df.skill_rating.Proficient then return 200 end
    if broker_skill <= df.skill_rating.Talented then return 500 end
    if broker_skill <= df.skill_rating.Adept then return 1000 end
    if broker_skill <= df.skill_rating.Expert then return 1500 end
    if broker_skill <= df.skill_rating.Professional then return 2000 end
    if broker_skill <= df.skill_rating.Accomplished then return 2500 end
    if broker_skill <= df.skill_rating.Great then return 3000 end
    if broker_skill <= df.skill_rating.Master then return 4000 end
    if broker_skill <= df.skill_rating.HighMaster then return 5000 end
    if broker_skill <= df.skill_rating.GrandMaster then return 10000 end
    return math.huge
end

-- If the item's value is below the threshold, it gets shown exactly as-is.
-- Otherwise, if it's less than or equal to [threshold + 50], it will round to the nearest multiple of 10 as an Estimate
-- Otherwise, if it's less than or equal to [threshold + 50] * 3, it will round to the nearest multiple of 100
-- Otherwise, if it's less than or equal to [threshold + 50] * 30, it will round to the nearest multiple of 1000
-- Otherwise, it will display a guess equal to [threshold + 50] * 30 rounded up to the nearest multiple of 1000.
function obfuscate_value(value)
    local threshold = get_threshold(get_broker_skill())
    if value < threshold then return tostring(value) end
    threshold = threshold + 50
    if value <= threshold then return ('~%d'):format(((value+5)//10)*10) end
    if value <= threshold*3 then return ('~%d'):format(((value+50)//100)*100) end
    if value <= threshold*30 then return ('~%d'):format(((value+500)//1000)*1000) end
    return ('%d?'):format(((threshold*30 + 999)//1000)*1000)
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
function get_perceived_value(item, caravan_state, caravan_buying)
    local value = dfhack.items.getValue(item, caravan_state, caravan_buying)
    for _,contained_item in ipairs(dfhack.items.getContainedItems(item)) do
        value = value + dfhack.items.getValue(contained_item, caravan_state, caravan_buying)
        for _,contained_contained_item in ipairs(dfhack.items.getContainedItems(contained_item)) do
            value = value + dfhack.items.getValue(contained_contained_item, caravan_state, caravan_buying)
        end
    end
    return value
end
