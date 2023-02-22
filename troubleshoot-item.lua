-- troubleshoot-item.lua
--@ module = true
--[====[

troubleshoot-item
=================
Print various properties of the selected item. Sometimes useful for
troubleshooting issues such as why dwarves won't pick up a certain item.

]====]

function find_specific_ref(object, type)
    for i, ref in pairs(object.specific_refs) do
        if ref.type == type then
            return ref
        end
    end
end

function coord_to_str(coord)
    local out = {}
    for k, v in pairs(coord) do
        -- handle 2D and 3D coordinates
        if k == 'x' then out[1] = v end
        if k == 'y' then out[2] = v end
        if k == 'z' then out[3] = v end
    end
    return '(' .. table.concat(out, ', ') .. ')'
end

function troubleshoot_item(item, out)
    local outstr = nil --as:string
    if out == nil then
        outstr = ''
        out = function(s) outstr = outstr .. s .. '\n' end
    end
    local function warn(s) out('WARNING: ' .. s) end
    assert(df.item:is_instance(item), 'not an item')
    if item.id < 0 then warn('Invalid ID: ' .. item.id) end
    if not df.item.find(item.id) then warn('Could not locate item in item lists') end
    if item.flags.forbid then out('Forbidden') end
    if item.flags.melt then out('Melt-designated') end
    if item.flags.dump then out('Dump-designated') end
    if item.flags.in_inventory then out('Is in an inventory') end
    local building_holder = dfhack.items.getGeneralRef(item, df.general_ref_type.BUILDING_HOLDER)
    if building_holder then
        if building_holder.building_id then
            local building = df.building.find(building_holder.building_id)
            if building then
                out('Inside building of type: ' .. df.building_type[building:getType()])
            else
                warn('Could not find building with building_id: ' .. building_holder.building_id)
            end
        else
            warn('Could not find building_id in building_holder')
        end
    end
    if item.flags.on_fire then out('On fire') end
    if item.flags.rotten then out('Rotten') end
    if item.flags.trader then out('Trade good') end
    if item.flags.owned then out('Owned') end
    if item.flags.foreign then out('Foreign') end
    if item.flags.encased then out('Encased in ice') end
    if item.flags.garbage_collect then warn('Marked for garbage collection') end
    if item.flags.construction then out('Used for construction') end
    if item.flags.in_building then out('Used for building') end
    if item.flags.hidden then out('Hidden') end
    if item.flags.artifact then
        out(item.flags.artifact_mood and "Artifact (from strange mood)" or "Artifact")
    end
    if item.flags.in_job then
        out('In job')
        local ref = find_specific_ref(item, df.specific_ref_type.JOB)
        if ref then
            out('Job type: ' .. df.job_type[ref.data.job.job_type])
            out('Job position: ' .. coord_to_str(ref.data.job.pos))
            local found_job_item = false
            for i, job_item_ref in pairs(ref.data.job.items) do
                if item == job_item_ref.item then found_job_item = true end
            end
            if not found_job_item then warn('Item not attached to job') end
        else
            warn('No job specific_ref found')
        end
    end

    for i, ref in pairs(item.specific_refs) do
        if ref.type ~= df.specific_ref_type.JOB then
            out('Unhandled specific_ref: ' .. df.specific_ref_type[ref.type])
        end
    end

    if outstr then return outstr end
end


function main(args)
    local item = dfhack.gui.getSelectedItem(true)
    if item then
        troubleshoot_item(item, print)
    else
        qerror('No item found')
    end
end

if not moduleMode then main({...}) end
