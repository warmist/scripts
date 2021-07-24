-- automatically nickname dwarves
--[====[

autonick
========
Automatically nickname dwarves according to "data/init/names.txt".

One nickname per line, or an empty line. Repeat entries are discarded.

Dwarves with manually set nicknames are ignored.

If there are fewer available nicknames than dwarves, the remaining
dwarves will go un-nicknamed.

You may wish to use this script with the "repeat" command, e.g:
repeat -name autonick -time 3 -timeUnits months -command [ autonick ]

]====]

names = {};
index = 1;

path = dfhack.getDFPath () .. "/data/init/names.txt";

-- grab list, put in array
for line in io.lines(path) do
	if line ~= "" then
		names [index] = line;
		index = (index + 1);
	end;
end;

--check current nicknames
for _,unit in ipairs(df.global.world.units.active) do
	if dfhack.units.isCitizen(unit) and
	unit.name.nickname ~= "" then
		for i,name in ipairs(names) do
			if name == unit.name.nickname then
				--remove current nickname from array
				table.remove(names, i);
			end;
		end;
	end;
end;

--assign names
for _,unit in ipairs(df.global.world.units.active) do
	if #names > 0 then --if there are any names left
		if dfhack.units.isCitizen(unit) and
		unit.name.nickname == "" then
			newnameIndex = math.random (#names);
			dfhack.units.setNickname(unit, names[newnameIndex]);
			table.remove(names, newnameIndex);
		end;
	end;
end;

