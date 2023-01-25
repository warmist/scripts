-- Fixes job cancellation spam when trying to use unreachable items.

local count = 0
for _,item in pairs(df.global.world.items.all) do
    local pos = item.pos
    local block = dfhack.maps.getTileBlock(pos)

    if block then
        local walkable = block.walkable[pos.x%16][pos.y%16]

        if walkable == 0 and not item.flags.forbid then
            item.flags.forbid = true
            count = count + 1
        end
    end
end

print(("Forbid %d items"):format(count))