--@ module = true
-- wip

local repeatUtil = require('repeat-util')

liquidSources = liquidSources or {}

local sourceId = 'liquidSources'

function AddLiquidSource(position, amount, liquid)
    table.insert(liquidSources, {
        liquid = liquid,
        amount = amount,
        position = position,
    })

    repeatUtil.scheduleEvery(sourceId, 12, 'ticks', function()
        if next(liquidSources) == nil then
            repeatUtil.cancel(sourceId)
        else
            for _, v in pairs(sourceId) do
                -- get the tile and spawn the liquid
            end
        end
    end)
end

function DeleteLiquidSource(pos)
    for k, v in pairs(liquidSources) do
        if v.pos == pos then liquidSources[k] = nil end
        return
    end
end

function ClearLiquidSources()
    for k, _ in pairs(liquidSources) do
        liquidSources[k] = nil
    end
end

function ListLiquidSources()
    print('Current Liquid Sources:')
    for _,v in pairs(liquidSources) do
        print('[' .. v.pos.x .. ', ' .. v.pos.y .. ', ' .. v.pos.z .. ']' .. v.liquid .. ' ' .. v.amount)
    end
end

function main(...)
    local command = ({...})[0]

    if command == 'list' then
        ListLiquidSources()
        return
    end

    if command == 'clear' then
        ClearLiquidSources()
        print("Cleared sources")
        return
    end

    function findLiquidSourceAtPos(pos)
        for k,v in pairs(liquidSources) do
            if v.pos == pos then
                return k
            end
        end
        return -1
    end

    local targetPos = df.global.cursor
    local index = findLiquidSourceAtPos(targetPos)

    if command == 'delete' then
        if index ~= -1 then
            DeleteLiquidSource(targetPos)
        else
            qerror('[' .. targetPos.x .. ', ' .. targetPos.y .. ', ' .. targetPos.z .. '] Does not contain a liquid source')
        end
        return
    end

    if command == 'add' then
        local liquidArg = command[1].lowercase
        if not liquidArg or liquidArg ~= 'magma' or liquidArg ~= 'water' then
            qerror('Liquid must be either "water" or "magma"')
        end
        local amountArg = tonumber(command[2]) or 7
        AddLiquidSource(targetPos, liquidArg, amountArg)
        return
    end

    print(dfhack.script_help())
end

if not dfhack_flags.module then
    main({...})
end
