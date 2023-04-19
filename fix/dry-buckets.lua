-- Removes water from buckets (for lye-making).
-- Can also be used to remove water (muddy or not) that is blocking well operations.
--[====[

fix/dry-buckets
===============
Removes water from all buckets in your fortress, allowing them
to be used for making lye. Skips buckets being carried, or currently used by a job.

]====]

local emptied = 0
local inBuilding = 0
local water_type = dfhack.matinfo.find('WATER').type

for _,item in ipairs(df.global.world.items.all) do
    local container = dfhack.items.getContainer(item)
    if container ~= nil
    and container:getType() == df.item_type.BUCKET
    and not (container.flags.in_job)
    and item:getMaterial() == water_type
    and item:getType() == df.item_type.LIQUID_MISC
    and not (item.flags.in_job) then
        if container.flags.in_building or item.flags.in_building then
            inBuilding = inBuilding + 1
        end        
        dfhack.items.remove(item)
        emptied = emptied + 1
    end
end

print('Emptied '..emptied..' buckets.')
if emptied > 0 then
    print(''..inBuilding..' of those were in a building.')    
end