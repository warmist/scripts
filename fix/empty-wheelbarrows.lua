--checks all wheelbarrows on map for rocks stuck in them. If a wheelbarrow isn't in use for a job (hauling) then there should be no rocks in them
--rocks will occasionally get stuck in wheelbarrows, and accumulate if the wheelbarrow gets used.
--this script empties all wheelbarrows which have rocks stuck in them.

local args = {...}

local quiet = false
local dryrun = false
for i,arg in ipairs(args) do
    if (arg == "--quiet") then
        quiet = true
    end
    if (arg == "--dryrun") then
        dryrun = true
    end
end

local i_count = 0
local e_count = 0

for _,e in ipairs(df.global.world.items.other.TOOL) do
    -- wheelbarrow must be on ground and not in a job
    if ((not e.flags.in_job) and e.flags.on_ground and e:isWheelbarrow()) then
        local items = dfhack.items.getContainedItems(e)
        if #items > 0 then
            if (not quiet) then print('Emptying wheelbarrow: ' .. dfhack.items.getDescription(e, 0)) end
            e_count = e_count + 1
            for _,i in ipairs(items) do
                if (not quiet) then print('  ' .. dfhack.items.getDescription(i, 0)) end
                if (not dryrun) then dfhack.items.moveToGround(i, e.pos) end
                i_count = i_count + 1
            end
        end
    end
end

print("fix/empty-wheelbarrows - removed " .. i_count .. " items from " .. e_count .. " wheelbarrows.")
