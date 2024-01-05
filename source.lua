--@ module = true
local repeatUtil = require('repeat-util')
local json = require('json')
local persist = require('persist-table')

local GLOBAL_KEY = 'source' -- used for state change hooks and persistence

local sourceId = 'liquidSources'

g_sources_list = g_sources_list or {}
local function retrieve_state()
    return g_sources_list
end

local function has_elements(collection)
    for _,_ in pairs(collection) do return true end
    return false
end

function isEnabled()
    return has_elements(retrieve_state())
end


local function persist_state(liquidSources)
    persist.GlobalTable[GLOBAL_KEY] = json.encode(liquidSources)
end

local function formatPos(pos)
    return ('[%d, %d, %d]'):format(pos.x, pos.y, pos.z)
end

function is_flow_passable(pos)
    local tiletype = dfhack.maps.getTileType(pos)
    local titletypeAttrs = df.tiletype.attrs[tiletype]
    local shape = titletypeAttrs.shape
    local tiletypeShapeAttrs = df.tiletype_shape.attrs[shape]
    return tiletypeShapeAttrs.passable_flow
end

function add_liquid_source(pos, liquid, amount)
    local sources = retrieve_state()
    print(("Adding %d %s to [%d, %d, %d]"):format(amount, liquid, pos.x, pos.y, pos.z))
    table.insert(sources, {
        liquid = liquid,
        amount = amount,
        pos = copyall(pos),
    })

    load_liquid_source(sources)
end

function load_liquid_source(sources)
    repeatUtil.scheduleEvery(sourceId, 12, 'ticks', function()
        if next(sources) == nil then
            repeatUtil.cancel(sourceId)
        else
            for _, v in pairs(sources) do
                local block = dfhack.maps.getTileBlock(v.pos)
                local x = v.pos.x
                local y = v.pos.y
                if block and is_flow_passable(v.pos) then
                    local isMagma = v.liquid == 'magma'

                    local flags = dfhack.maps.getTileFlags(v.pos)
                    local flow = flags.flow_size

                    if flow ~= v.amount then
                        local target = flow + 1
                        if flow > v.amount then
                            target = flow - 1
                        end

                        flags.liquid_type = isMagma
                        flags.flow_size = target
                        flags.flow_forbid = (isMagma or target >= 4)

                        dfhack.maps.enableBlockUpdates(block, true)
                    end
                end
            end
        end
    end)
    persist_state(sources)
end

function delete_liquid_source(pos)
    local sources = retrieve_state()
    print(("Searching for Source to remove at [%d, %d, %d]"):format(pos.x, pos.y, pos.z))
    for k, v in pairs(sources) do
        if same_xyz(pos, v.pos) then
            print("Source Found")
            local block = dfhack.maps.getTileBlock(pos)
            if block and is_flow_passable(pos) then
                local flags = dfhack.maps.getTileFlags(pos)
                flags.flow_size = 0
                flags.flow_forbid = true
                dfhack.maps.enableBlockUpdates(block, true)
            end
            sources[k] = nil
        end
        return
    end
    load_liquid_source(sources)
end

function clear_liquid_source()
    local sources = retrieve_state()
    print("Clearing all Sources")
    for _, v in pairs(sources) do
        delete_liquid_source(v.pos)
    end
    load_liquid_source(sources)
end

function list_liquid_sources()
    print('Current Liquid Sources:')
    for _,v in pairs(retrieve_state()) do
        print(('%s %s %d'):format(formatPos(v.pos), v.liquid, v.amount))
    end
end

function find_liquid_source_at_pos(pos)
    print(("Searching for Source at [%d, %d, %d]"):format(pos.x, pos.y, pos.z))
    for k,v in pairs(retrieve_state()) do
        if same_xyz(v.pos, pos) then
            print("Source Found")
            return k
        end
    end
    return nil
end

function main(args)
    local command = args[1]

    if command == 'list' then
        list_liquid_sources()
        return
    end

    if command == 'clear' then
        clear_liquid_source()
        print("Cleared sources")
        return
    end

    local targetPos = copyall(df.global.cursor)
    local index = find_liquid_source_at_pos(targetPos)

    if command == 'delete' then
        if targetPos.x < 0 then
            qerror("Please place the cursor where there is a source to delete")
        end
        if index then
            delete_liquid_source(targetPos)
            print(('Deleted source at %s'):format(formatPos(targetPos)))
        else
            qerror(('%s Does not contain a liquid source'):format(formatPos(targetPos)))
        end
        return
    end

    if command == 'add' then
        if targetPos.x < 0 then
            qerror('Please place the cursor where you would like a source')
        end
        local liquidArg = args[2]
        if not liquidArg then
            qerror('You must specify a liquid to add a source for')
        end
        liquidArg = liquidArg:lower()
        if not (liquidArg == 'magma' or liquidArg == 'water') then
            qerror('Liquid must be either "water" or "magma"')
        end
        if not is_flow_passable(targetPos) then
            qerror("Tile not flow passable: I'm afraid I can't let you do that, Dave.")
        end
        local amountArg = tonumber(args[3]) or 7
        add_liquid_source(targetPos, liquidArg, amountArg)
        print(('Added %s %d at %s'):format(liquidArg, amountArg, formatPos(targetPos)))
        return
    end
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc ~= SC_MAP_LOADED or df.global.gamemode ~= df.game_mode.DWARF then
        return
    end
    local persisted_data = json.decode(persist.GlobalTable[GLOBAL_KEY] or '') or {}
    -- sometimes the keys come back as strings; fix that up
    for k,v in pairs(persisted_data) do
        if type(k) == 'string' then
            persisted_data[tonumber(k)] = v
            persisted_data[k] = nil
        end
    end
    g_sources_list = persisted_data
    load_liquid_source(g_sources_list)
end

if dfhack.internal.IN_TEST then
    unit_test_hooks = {
        clear_watched_job_matchers=clear_watched_job_matchers,
        on_new_job=on_new_job,
        status=status,
        boost=boost,
        boost_and_watch=boost_and_watch,
        remove_watch=remove_watch,
        print_current_jobs=print_current_jobs,
        print_registry=print_registry,
        parse_commandline=parse_commandline,
    }
end

if dfhack_flags.module then
    return
end

if not dfhack_flags.module then
    main({...})
end

persist_state(g_sources_list)
