--Dynamically limit the next immigration wave
--By Loci, modified by Fleeting Frames and Tachytaenius
--[====[

max-wave
========
Limit the number of migrants that can arrive in the next wave by overriding the population cap value in data/init/d_init.txt (not safe with gui/settings-manager)
Use with the `repeat` command to set a rolling immigration limit.

Syntax::

    max-wave <wave_size> [max_pop]

Examples::

    max-wave 5
    repeat -time 1 -timeUnits months -command [ max-wave 10 200 ]

The first example ensures the next migration wave has 5 or fewer
dwarves. The second example ensures all future seasons have a
maximum of 10 immigrants per wave, up to a total population of 200.

]====]

local args = {...}

local wave_size = tonumber(args[1])
local max_pop = tonumber(args[2])
local current_pop = 0

if not wave_size then
  qerror('max-wave: wave_size required')
end

local function isCitizen(unit)
  return dfhack.units.isCitizen(unit) or
  (dfhack.units.isOwnCiv(unit) and
   dfhack.units.isAlive(unit) and
   df.global.world.raws.creatures.all[unit.race].caste[unit.caste].flags.CAN_LEARN and
   not (dfhack.units.isMerchant(unit) or dfhack.units.isForest(unit) or unit.flags1.diplomat or unit.flags2.visitor))
 end

--One would think the game would track this value somewhere...
for k,v in ipairs(df.global.world.units.active) do
  if isCitizen(v) then
   current_pop = current_pop + 1
  end
 end

local new_limit = current_pop + wave_size

if max_pop and new_limit > max_pop then new_limit = max_pop end

if new_limit == df.global.d_init.population_cap then
    print('max-wave: Population cap (' .. new_limit .. ') not changed, maximum population reached')
else
    df.global.d_init.population_cap = new_limit
    print('max-wave: Population cap set to ' .. new_limit)
end
