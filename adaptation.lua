-- View or set cavern adaptation levels
-- based on adaptation.rb
--[====[

adaptation
==========
View or set level of cavern adaptation for the selected unit or the whole fort.

Examples:

* Shows cave adaptation of unit under cursor:
    adaptation
* Shows cave adaptation of all units:
    adaptation -all
* Sets cave adaptation of unit under cursor to 0:
    adaptation -set 0

The ``value`` must be between 0 and 800,000 (inclusive). "set" and "all" arguments may be combined.

]====]

local utils = require('utils')

local validArgs = utils.invert({
 'all',
 'set',
})

if moduleMode then
 return
end

local args = utils.processArgs({...}, validArgs)

if args.set and (args.set < 0 or args.set > 800000) then
    print("Value must be between 0 and 800,000.")
end

local function set_adaptation_value(unit)
    if unit.flags2.inactive or not dfhack.units.isCitizen(v) then
        return 0
    end
    local found = false
    local amount = 0
    for k,v in ipairs(unit.status.misc_traits) do
        if v.id == df.misc_trait_type.CaveAdapt then
            found = v
            break
        end
    end
    if not found and args.set then
        found = df.unit_misc_trait:new()
        found.id = df.misc_trait_type.CaveAdapt
        found.value = args.set
        unit.status.misc_traits:insert('#', found)
    end
    if found then
        amount = found.value
    end
    if args.set then
        print("Unit "..dfhack.TranslateName(dfhack.units.getVisibleName(unit)).." changed to "..args.set)
    else
        print("Unit "..dfhack.TranslateName(dfhack.units.getVisibleName(unit)).." has an adaptation of "..amount)
    end
    return 1
end

if args.all then
    for k,v in ipairs(df.global.world.units.all) do
        set_adaptation_value(v)
    end
else
    local u = dfhack.gui.getSelectedUnit()
    if u then
        set_adaptation_value(u)
    else
        print("Please select a unit.")
    end
end
