--@ module = true
local repeatUtil = require('repeat-util')
local json = require('json')
local persist = require('persist-table')

local GLOBAL_KEY = 'source' -- used for state change hooks and persistence

g_state = g_state or {}

local sourceId = 'liquidSources'

enabled = enabled or false

function isEnabled()
    return enabled
end

local function retrieve_state()
    return json.decode(persist.GlobalTable[GLOBAL_KEY] or '')
end

local function persist_state(liquidSources)
    persist.GlobalTable[GLOBAL_KEY] = json.encode(liquidSources)
end

local function formatPos(pos)
    return ('[%d, %d, %d]'):format(pos.x, pos.y, pos.z)
end

function IsFlowPassable(pos)
    local tiletype = dfhack.maps.getTileType(pos)
    local titletypeAttrs = df.tiletype.attrs[tiletype]
    local shape = titletypeAttrs.shape
    local tiletypeShapeAttrs = df.tiletype_shape.attrs[shape]
    return tiletypeShapeAttrs.passable_flow
end

function AddLiquidSource(pos, liquid, amount)
    print(("Adding %d %s to [%d, %d, %d]"):format(amount, liquid, pos.x, pos.y, pos.z))
    table.insert(g_state, {
        liquid = liquid,
        amount = amount,
        pos = copyall(pos),
    })

    LoadLiquidSources(g_state)
end

function LoadLiquidSources(liquidSources)
    repeatUtil.scheduleEvery(sourceId, 12, 'ticks', function()
        if next(g_state) == nil then
            repeatUtil.cancel(sourceId)
        else
            for _, v in pairs(g_state) do
                local block = dfhack.maps.getTileBlock(v.pos)
                local x = v.pos.x
                local y = v.pos.y
                if block and IsFlowPassable(v.pos) then
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
    persist_state(g_state)
end

function RemoveLiquidSource(pos)
    for _, v in pairs(g_state) do
        print(("Removing Source at [%d, %d, %d]"):format(pos.x, pos.y, pos.z))
        local block = dfhack.maps.getTileBlock(pos)
        if block then
            dfhack.maps.enableBlockUpdates(block, false)
        end
    end
end

function DeleteLiquidSource(pos)
    print(("Searching for Source to remove at [%d, %d, %d]"):format(pos.x, pos.y, pos.z))
    for k, v in pairs(g_state) do
        if same_xyz(pos, v.pos) then
            print("Source Found")
            RemoveLiquidSource(pos)
            g_state[k] = nil
        end
        return
    end
    LoadLiquidSources(g_state)
end

function ClearLiquidSources()
    print("Clearing all Sources")
    for _, v in pairs(g_state) do
        DeleteLiquidSource(v.pos)
    end
    LoadLiquidSources(g_state)
end

function ListLiquidSources()
    print('Current Liquid Sources:')
    for _,v in pairs(g_state) do
        print(('%s %s %d'):format(formatPos(v.pos), v.liquid, v.amount))
    end
end

function FindLiquidSourceAtPos(pos)
    print(("Searching for Source at [%d, %d, %d]"):format(pos.x, pos.y, pos.z))
    for k,v in pairs(g_state) do
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
        ListLiquidSources()
        return
    end

    if command == 'clear' then
        ClearLiquidSources()
        print("Cleared sources")
        return
    end

    local targetPos = copyall(df.global.cursor)
    local index = FindLiquidSourceAtPos(targetPos)

    if command == 'delete' then
        if targetPos.x < 0 then
            qerror("Please place the cursor where there is a source to delete")
        end
        if index then
            DeleteLiquidSource(targetPos)
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
        if not IsFlowPassable(targetPos) then
            qerror("Tile not flow passable: I'm afraid I can't let you do that, Dave.")
        end
        local amountArg = tonumber(args[3]) or 7
        AddLiquidSource(targetPos, liquidArg, amountArg)
        print(('Added %s %d at %s'):format(liquidArg, amountArg, formatPos(targetPos)))
        return
    end
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_MAP_UNLOADED then
        enabled = false
        return
    end

    if sc ~= SC_MAP_LOADED or df.global.gamemode ~= df.game_mode.DWARF then
        local g_state = retrieve_state()
        LoadLiquidSources(g_state)
        return
    end

    if sc == SC_WORLD_LOADED then
        local g_state = retrieve_state()
        LoadLiquidSources(g_state)
    end

    local state = json.decode(persist.GlobalTable[GLOBAL_KEY] or '')
    g_state = state or {}
end

if dfhack_flags.enable then
    if dfhack_flags.enable_state then
        start()
        enabled = true
    else
        stop()
        enabled = false
    end
end

if not dfhack_flags.module then
    main({...})
end

persist_state(liquidSources)
