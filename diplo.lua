--[[ diplo - Quick "Diplomacy"
Without arguments:
	Print list of civs the player civ has diplomatic relations to.
	This list might not match the ingame civ list, but is what matters. Does not include 'no contect' civs, etc.
	Also shows if relations match between player civ and other civ - a mismatch can potentially happen 'naturally', but is important when trying to make peace proper, as both civs need to be at peace with the other.
With arguments:
	diplo CIV_ID RELATION
	Changes the relation to the civ identified by CIV_ID to the one specified in RELATION, making sure that this is mutual.
	Relations: 0 = Peace; 1 = War; 3 = Alliance (seems to only apply to site govs...?)
	Civ list is shown afterwards.
]]

local args = {...}

-- player civ references:
local p_civ_id = df.global.plotinfo.civ_id
local p_civ = df.historical_entity.find(df.global.plotinfo.civ_id)

-- get a very rough, but readable name for a civ:
function get_raw_name(civ)
	local raw_name = ""
	for _, name_word in pairs(civ.name.words) do
		if name_word ~= -1 then
			raw_name = raw_name .. " " .. df.global.world.raws.language.words[name_word].word
		end
	end
	raw_name = string.sub(raw_name, 2)
	return raw_name
end

-- if no civ ID is entered, just output list of civs:
if not args[1] then
	goto outputlist
end

-- make sure that there is a relation to change to:
if not args[2] then qerror("Missing relation!") end

-- change relation:
print("Changing relation with " .. args[1] .. " to " .. args[2])
for _, entity in pairs(p_civ.relations.diplomacy) do
	local cur_civ_id = entity.group_id
	local cur_civ = df.historical_entity.find(cur_civ_id)
	if cur_civ.type == 0 and cur_civ_id == tonumber(args[1]) then
		entity.relation = tonumber(args[2])
		for _, entity2 in pairs(cur_civ.relations.diplomacy) do
			if entity2.group_id == p_civ_id then
				entity2.relation = tonumber(args[2])
			end
		end
	end
end

-- output list of civs
:: outputlist ::
local civ_list = {}
for _, entity in pairs(p_civ.relations.diplomacy) do
	local cur_civ_id = entity.group_id
	local cur_civ = df.historical_entity.find(cur_civ_id)
	if cur_civ.type == 0 then
		rel_str = ""
		if entity.relation == 0 then
			rel_str = "0 (Peace)"
		elseif entity.relation == 1 then
			rel_str = "1 (War)"
		elseif entity.relation == 3 then
			rel_str = "3 (Alliance)"
		end
		matched = "Yes"
		for _, entity2 in pairs(cur_civ.relations.diplomacy) do
			if entity2.group_id == p_civ_id and entity2.relation ~= entity.relation then
				matched = "No"
			end
		end
		table.insert(civ_list, {
		cur_civ_id,
		rel_str,
		matched,
		get_raw_name(cur_civ)
		})
	end
end

print(([[%4s %12s %8s %20s]]):format("ID", "Relation", "Matched", "Name"))
for _, civ in pairs(civ_list) do
    print(([[%4s %12s %8s %20s]]):format(civ[1], civ[2], civ[3], civ[4]))
end