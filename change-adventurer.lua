local utils=require 'utils'

local args=utils.processArgs({...},{['unit-id']=true,['no-namesis']=true,safe=true})

function change_adv(unit,nemesis,safe)--same code in reincarnate.lua

    if safe==nil then
        safe=false
    end

    if nemesis==nil then
        nemesis=true --default value is nemesis switch too.
    end
    if unit==nil then
        unit=dfhack.gui.getSelectedUnit()--getCreatureAtPointer()
    end
    if unit==nil then
        error("Invalid unit!")
    end
    local other=df.global.world.units.active
    local unit_indx
    for k,v in pairs(other) do
        if v==unit then
            unit_indx=k
            break
        end
    end
    if unit_indx==nil then
        error("Unit not found in array?!") --should not happen
    end

    if not safe then
        other[unit_indx]=other[0]
        other[0]=unit
    end

    if nemesis then --basicly copied from advtools plugin...

        local nem=dfhack.units.getNemesis(unit)
        if safe and nem==nil then
            qerror("Current unit does not have nemesis record, further working not guaranteed")
        end

        local other_nem=dfhack.units.getNemesis(other[unit_indx])
        if other_nem then
            other_nem.flags[0]=false
            other_nem.flags[1]=true
        end

        if nem then
            nem.flags[0]=true
            nem.flags[2]=true
            for k,v in pairs(df.global.world.nemesis.all) do
                if v.id==nem.id then
                    df.global.ui_advmode.player_id=k
                end
            end
        else
            qerror("Current unit does not have nemesis record, further working not guaranteed")
        end
    end
    if safe then
        other[unit_indx]=other[0]
        other[0]=unit
    end
end

local unit
local nemesis=true
if args['unit-id'] then
    unit=df.unit.find(tonumber(args['unit-id']))
end
if args['no-namesis'] then
    nemesis=false
end
change_adv(unit,nemesis,args.safe)
