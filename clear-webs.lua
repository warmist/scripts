-- Removes webs and frees webbed units.
-- author: Atomic Chicken

--[====[

clear-webs
==========
This script removes all webs that are currently on the map,
and also frees any creatures who have been caught in one.

Note that it does not affect sprayed webs until
they settle on the ground.

Usable in both fortress and adventurer mode.

]====]

local webCount = 0
for i = #df.global.world.items.other.ANY_WEBS-1, 0, -1 do
  dfhack.items.remove(df.global.world.items.other.ANY_WEBS[i])
  count = count + 1
end

for _, unit in ipairs(df.global.world.units.all) do
  unit.counters.webbed = 0
end

if count == 0 then
  print("No webs detected!")
else
  print("Removed " .. count .. " web" .. (count == 1 and "" or "s") .. "!")
end
