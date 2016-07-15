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
function Reincarnate(trg_unit,swap_soul) --only for adventurer i guess
    if swap_soul==nil then
        swap_soul=true
    end
    local adv=trg_unit or df.global.world.units.active[0]
    if adv.flags1.dead==false then
        qerror("You are not dead (yet)!")
    end
    local hist_fig=dfhack.units.getNemesis(adv).figure
    if hist_fig==nil then
        qerror("No historical figure for adventurer...")
    end
    local events=df.global.world.history.events
    local trg_hist_fig
    for i=#events-1,0,-1 do -- reverse search because almost always it will be last entry
        if df.history_event_hist_figure_diedst:is_instance(events[i]) then
            --print("is instance:"..i)
            if events[i].victim_hf==hist_fig.id then
                --print("Is same id:"..i)
                trg_hist_fig=events[i].slayer_hf
                if trg_hist_fig then
                    trg_hist_fig=df.historical_figure.find(trg_hist_fig)
                end
                break
            end
        end
    end
    if trg_hist_fig ==nil then
        qerror("Slayer not found")
    end

    local trg_unit=trg_hist_fig.unit_id
    if trg_unit==nil then
        qerror("Unit id not found!")
    end
    local trg_unit_final=df.unit.find(trg_unit)

    change_adv(trg_unit_final)
    if swap_soul then --actually add a soul...
        t_soul=adv.status.current_soul
        adv.status.current_soul=df.NULL
        adv.status.souls:resize(0)
        trg_unit_final.status.current_soul=t_soul
        trg_unit_final.status.souls:insert(#trg_unit_final.status.souls,t_soul)
    end
end
Reincarnate()