-- Original opening comment before lua adaptation
-- View or set cavern adaptation levels
-- based on removebadthoughts.rb

-- Rewritten by TBSTeun from adaptation.lua

local help = [====[

adaptation
==========
View or set level of cavern adaptation for the selected unit or the whole fort.

Usage::

    adaptation <show|set> <him|all> [value]

The ``value`` must be between 0 and 800,000 (inclusive).

]====]

-- Color constants, values mapped to color_value enum in include/ColorText.h
COLOR_RESET  = -1
COLOR_GREEN  = 2
COLOR_RED    = 4
COLOR_YELLOW = 14

function print_color(color, s)
	dfhack.color(color)
    dfhack.print(s)
    dfhack.color(COLOR_RESET)
end

function usage(s)
	if s ~= nil then
		print(s)
	end
    
    print("Usage: adaptation <show|set> <him|all> [value]")

    -- TODO: translate throw :script_finished
end

mode  = args[1]
who   = args[2]
value = args[3]

if mode == 'help' then
	usage(nil)
elseif mode ~= 'show' and mode ~= 'set' then
	usage(string.format("Invalid mode '%s': must be either 'show' or 'set'", mode))
end

if who == nil then
	usage("Target not specified")
elseif who ~= 'him' and who ~= 'all' then
	usage(string.format("Invalid target '%s'", who))
end

if mode == 'set' then
	if value == nil then
		usage("value not specified")
	end

    if tonumber(value) == nil then
    	usage(string.format("Invalud value '%s'", value))
    end

    if tonumber(value) < 0 or tonumber(value) > 800000 then
    	usage("Value must be between 0 and 800000")
    end

    value = tonumber(value)
end

num_set = 0

function set_adaptation_value(u, v)
	if not df.unit.iscitizen(u) then
		return
	end
	if u.flags2.killed then
		return
	end

    trait_found = false
    for trait in u.status.misc_traits do
        if t.id == 'CaveAdapt' then
        	if mode == 'show' then
                print_color(COLOR_RESET, string.format("Unit %s (%s) has an adaptation of ", u.id, u.name))

                if t.value >= 0 and t.value <= 399999 then
                	print_color(COLOR_GREEN, string.format("%s\n", t.value))
                elseif t.value >= 400000 and t.value <= 599999 then
                	print_color(COLOR_YELLOW, string.format("%s\n", t.value))
                else
                	print_color(COLOR_RED, string.format("%s\n", t.value))
                end
            elseif mode == 'set' then
            	t.value = value
            	num_set = num_set + 1
            	print(string.format("Unit %s (%s) changed from %s to %s", u.id, u.name, t.value, v))
            end

            trait_found = true
            break
        end
    end

    if not(trait_found) then
    	if mode == 'show' then
    		print_color(COLOR_RESET, string.format("Unit %s (%s) has an adaptation of ", u.id, u.name))
    		print_color(COLOR_GREEN, "0\n")
    	elseif mode == 'set' then
    		new_trait = df.unit_misc_trait:new()
    		new_trait.id = "CaveAdapt"
    		new_trait.value = v
    		num_set = num_set + 1
    		table.insert(u.status.misc_traits, new_trait)
    		print(string.format("Unit %s (%s) changed from 0 to %s", u.id, u.name, v))
        end
    end
end

if who == 'him' then
	if dfhack.gui.getSelectedUnit(true) then
		u = dfhack.gui.getSelectedUnit(true)
		set_adaptation_value(u, value)
	else
		print("Please select a dwarf ingame")
	end
elseif who == 'all' then
	for unit in df.unit_citizens do
		set_adaptation_value(unit, value)
	end
end

if mode == "set" then
	if num_set ~= 1 then
	    print(string.format("%s units updated", num_set))
    else
    	print(string.format("%s unit upadted", num_set))
    end
end