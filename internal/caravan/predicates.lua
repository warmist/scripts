--@ module = true

local scriptmanager = require('script-manager')

local function to_item_type_str(item_type)
    return string.lower(df.item_type[item_type]):gsub('_', ' ')
end

local PREDICATE_LIBRARY = {
    {name='weapons-grade metal', match=function(item)
        if item.mat_type ~= 0 then return false end
        local flags = df.global.world.raws.inorganics[item.mat_index].material.flags
        return flags.IS_METAL and
            (flags.ITEMS_METAL or flags.ITEMS_WEAPON or flags.ITEMS_WEAPON_RANGED or flags.ITEMS_AMMO or flags.ITEMS_ARMOR)
    end},
}
for _,item_type in ipairs(df.item_type) do
    table.insert(PREDICATE_LIBRARY, {
        name=to_item_type_str(item_type),
        group='item type',
        match=function(item) return item_type == item:getType() end,
    })
end

local PREDICATES_VAR = 'ITEM_PREDICATES'

local function get_user_predicates()
    local user_predicates = {}
    local load_user_predicates = function(env_name, env)
        local predicates = env[PREDICATES_VAR]
        if not predicates then return end
        if type(predicates) ~= 'table' then
            dfhack.printerr(
                    ('error loading predicates from "%s": %s map is malformed')
                    :format(env_name, PREDICATES_VAR))
            return
        end
        for i,predicate in ipairs(predicates) do
            if type(predicate) ~= 'table' then
                dfhack.printerr(('error loading predicate %s:%d (must be a table)'):format(env_name, i))
                goto continue
            end
            if type(predicate.name) ~= 'string' or #predicate.name == 0 then
                dfhack.printerr(('error loading predicate %s:%d (must have a string "name" field)'):format(env_name, i))
                goto continue
            end
            if type(predicate.match) ~= 'function' then
                dfhack.printerr(('error loading predicate %s:%d (must have a function "match" field)'):format(env_name, i))
                goto continue
            end
            table.insert(user_predicates, {id=('%s:%s'):format(env_name, predicate.name), name=predicate.name, match=predicate.match})
            ::continue::
        end
    end
    scriptmanager.foreach_module_script(load_user_predicates)
    return user_predicates
end

function customize_predicates(context, on_close)
    local user_predicates = get_user_predicates()
    local predicate = nil
    if #user_predicates > 0 then
        predicate = user_predicates[1]
    else
        predicate = PREDICATE_LIBRARY[1]
    end
    context.predicates[predicate.name] = {match=predicate.match, show=true}
    on_close()
end

function make_predicate_str(context)
    local preset, names = nil, {}
    for name, predicate in pairs(context.predicates) do
        if not preset then
            preset = predicate.preset or ''
        end
        if #preset > 0 and preset ~= predicate.preset then
            preset = ''
        end
        table.insert(names, name)
    end
    if preset and #preset > 0 then
        return preset
    end
    if #names > 0 then
        return table.concat(names, ', ')
    end
    return 'All'
end

function init_context_predicates(context)
    -- TODO: init according to context.name
    context.predicates = {}
end

function pass_predicates(context, item)
    local has_show = false
    for _,predicate in pairs(context.predicates) do
        local ok, matches = safecall(predicate.match, item)
        if not ok then goto continue end
        has_show = has_show or predicate.show
        if matches and predicate.show then return true end
        if not matches and predicate.hide then return false end
        ::continue::
    end
    return not has_show
end
