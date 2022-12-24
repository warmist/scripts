--@ module = true
-- wip

local repeatUtil = require('repeat-util')

sources = sources or {}

local sourceId = "liquidSources"

function AddLiquidSource(position, amount, liquid)
    table.insert(sources, {
        liquid = liquid,
        amount = amount,
        position = position,
    })

    repeatUtil.scheduleEvery(sourceId, 12, 'ticks', function()
        if next(sources) == nil then
            repeatUtil.cancel(sourceId)
        else
            for _, v in pairs(sourceId) do
                -- get the tile and spawn the liquid
            end
        end
    end)
end

function DeleteLiquidSource(pos)
    for k, v in pairs(sources) do
        if v.pos == pos then sources[k] = nil end
        return
    end
end

function ClearLiquidSources()
    for k, _ in pairs(sources) do
        sources[k] = nil
    end
end

function ListLiquidSources()
    -- iterate the table and list the sources
end

function main(...)
    local command = ({...})[0]

    if command == 'list' then
        ListLiquidSources()
        return
    end

    if command == 'clear' then
        ClearLiquidSources()
    end

    if command == 'delete' then
        DeleteLiquidSource(df.global.cursor)
    end

    if command == 'add' then
        AddLiquidSource()
        return
    end

    print(dfhack.script_help())
end

if not dfhack_flags.module then
    main({...})
end
