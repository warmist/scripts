-- Original opening comment before lua adaptation
-- View or set cavern adaptation levels
-- based on removebadthoughts.rb

-- Rewritten by TBSTeun using OpenAI GPT from adaptation.rb

local help = [====[

adaptation
==========
View or set level of cavern adaptation for the selected unit or the whole fort.

Usage::

    adaptation <show|set> <him|all> [value]

The ``value`` must be between 0 and 800,000 (inclusive).

]====]

-- Color constants, values mapped to color_value enum in include/ColorText.h
local COLOR_RESET = -1
local COLOR_GREEN = 2
local COLOR_RED = 4
local COLOR_YELLOW = 14

local function print_color(color, s)
    dfhack.color(color)
    dfhack.print(s)
    dfhack.color(COLOR_RESET)
end

local function usage(s)
    if s ~= nil then
        print(s)
    end
    print("Usage: adaptation <show|set> <him|all> [value]")
end

local args = {...}

local mode = args[1] or "help"
local who = args[2]
local value = args[3]

if mode == "help" then
    usage()
elseif mode ~= "show" and mode ~= "set" then
    usage("Invalid mode '" .. mode .. "': must be either 'show' or 'set'")
end

if who == nil then
    usage("Target not specified")
elseif who ~= "him" and who ~= "all" then
    usage("Invalid target '" .. who .. "'")
end

if mode == "set" then
    if value == nil then
        usage("Value not specified")
    elseif not tonumber(value) then
        usage("Invalid value '" .. value .. "'")
    end

    if tonumber(value) < 0 or tonumber(value) > 800000 then
        usage("Value must be between 0 and 800000")
    end
    value = tonumber(value)

end

local num_set = 0

local function set_adaptation_value(unit, v)
    if not dfhack.units.isCitizen(unit) or unit.flags2.killed then
        return
    end
    local trait_found = false
    for _, t in ipairs(unit.status.misc_traits) do
        if t.id == df.misc_trait_type.CaveAdapt then
            if mode == "show" then
                    print_color(COLOR_RESET, "Unit " .. unit.id .. " (" .. dfhack.TranslateName(dfhack.units.getVisibleName(unit)) .. ") has an adaptation of ")
                    if t.value <= 399999 then
                        print_color(COLOR_GREEN, t.value .. "\n")
                    elseif t.value <= 599999 then
                        print_color(COLOR_YELLOW, t.value .. "\n")
                    else
                        print_color(COLOR_RED, t.value .. "\n")
                    end
            elseif mode == "set" then
                print("Unit " .. unit.id .. " (" .. dfhack.TranslateName(dfhack.units.getVisibleName(unit)).. ") changed from " .. t.value .. " to " .. v)
                t.value = v
                num_set = num_set + 1
            end
            trait_found = true
            break
        end
    end
    if not trait_found then
        if mode == "show" then
            print_color(COLOR_RESET, "Unit " .. unit.id .. " (" .. dfhack.TranslateName(dfhack.units.getVisibleName(unit)) .. ") has an adaptation of ")
            print_color(COLOR_GREEN, "0\n")
        elseif mode == "set" then
            local new_trait = df.unit_misc_trait:new()
            new_trait.id = df.misc_trait_type.CaveAdapt
            new_trait.value = v
            num_set = num_set + 1
            table.insert(unit.status.misc_traits, new_trait)
            print("Unit " .. unit.id .. " (" .. dfhack.TranslateName(dfhack.units.getVisibleName(unit)) .. ") changed from 0 to " .. v)
        end
    end
end

if who == "him" then
    local u = dfhack.gui.getSelectedUnit(true)
    if u then
        set_adaptation_value(u, value)
    else
        print('Please select a dwarf ingame')
    end
elseif who == "all" then
    for _, uu in ipairs(df.global.world.units.all) do
        set_adaptation_value(uu, value)
    end
    if num_set > 0 then
        print(num_set .. " units changed")
    end
end
