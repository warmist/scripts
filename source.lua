--@ module = true
-- wip

local repeatUtil = require('repeat-util')

liquidSources = liquidSources or {}

local sourceId = 'liquidSources'

function isFlowPassable(pos)
    local tiletype = dfhack.maps.getTileType(pos.x, pos.y, pos.z)
    local titletypeAttrs = df.tiletype.attrs[tiletype]
    local shape = titletypeAttrs.shape
    local tiletypeShapeAttrs = df.tiletype_shape.attrs[shape]
    return tiletypeShapeAttrs.passable_flow
end

function AddLiquidSource(pos, liquid, amount)
    table.insert(liquidSources, {
        liquid = liquid,
        amount = amount,
        pos = {
            x = pos.x,
            y = pos.y,
            z = pos.z,
        },
    })

    repeatUtil.scheduleEvery(sourceId, 12, 'ticks', function()
        if next(liquidSources) == nil then
            repeatUtil.cancel(sourceId)
        else
            for _, v in pairs(liquidSources) do
                local block = dfhack.maps.getTileBlock(v.pos.x, v.pos.y, v.pos.z)
                local x = v.pos.x
                local y = v.pos.y
                if block and isFlowPassable(v.pos) then
                    local isMagma = v.liquid == 'magma'

                    local flow = block.designation[x%16][y%16].flow_size

                    if flow ~= v.amount then
                        local target = flow + 1
                        if flow > v.amount then
                            target = flow - 1
                        end

                        block.designation[x%16][y%16].liquid_type = isMagma
                        block.designation[x%16][y%16].flow_size = target
                        block.designation[x%16][y%16].flow_forbid = (isMagma or target >= 4)

                        dfhack.maps.enableBlockUpdates(block, true)
                    end
                end
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
        print('[' .. v.pos.x .. ', ' .. v.pos.y .. ', ' .. v.pos.z .. '] ' .. v.liquid .. ' ' .. v.amount)
    end
end

function main(...)
    local command = ({...})[1]

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
        if targetPos.x < 0 then
            qerror("Please place the cursor where there is a source to delete")
        end
        if index ~= -1 then
            DeleteLiquidSource(targetPos)
            print("Deleted source at [" .. targetPos.x .. ", " .. targetPos.y .. ", " .. targetPos.z .. "]")
        else
            qerror('[' .. targetPos.x .. ', ' .. targetPos.y .. ', ' .. targetPos.z .. '] Does not contain a liquid source')
        end
        return
    end

    if command == 'add' then
        if targetPos.x < 0 then
            qerror('Please place the cursor where you would like a source')
        end
        local liquidArg = ({...})[2]
        if not liquidArg then
            qerror('You must specify a liquid to add a source for')
        end
        liquidArg = liquidArg:lower()
        if not (liquidArg == 'magma' or liquidArg == 'water') then
            qerror('Liquid must be either "water" or "magma"')
        end
        if not isFlowPassable(targetPos) then
            qerror('Tile not flow passable: I\'m afriad I can\'t let you do that, Dave.')
        end
        local amountArg = tonumber(({...})[3]) or 7
        AddLiquidSource(targetPos, liquidArg, amountArg)
        print("Added " .. liquidArg .. " " .. amountArg .. " at [" .. targetPos.x .. ", " .. targetPos.y .. ", " .. targetPos.z .. "]")
        return
    end

    print(dfhack.script_help())
end

if not dfhack_flags.module then
    main(...)
end
