-- Detects and alerts when a citizen is stranded
-- by Azrazalea

-- Taken from warn-starving
local function getSexString(sex)
  local sym = df.pronoun_type.attrs[sex].symbol
  if not sym then
    return ""
  end
  return "("..sym..")"
end

function doCheck()
  local grouped = {}
  local citizens = dfhack.units.getCitizens()

  -- Pathability group calculation is from gui/pathable
  for _, unit in pairs(citizens) do
    local target = unit.pos
    local block = dfhack.maps.getTileBlock(target)
    local walkGroup = block and block.walkable[target.x % 16][target.y % 16] or 0
    local groupTable = grouped[walkGroup]

    if groupTable == nil then
      grouped[walkGroup] = { unit }
    else
      table.insert(groupTable, unit)
    end
  end

  local strandedUnits = {}

  for _, units in pairs(grouped) do
    if #units == 1 then
      table.insert(strandedUnits, units[1])
    end
  end

  print("Number of stranded: ")
  print(#strandedUnits)
  for _, unit in pairs(strandedUnits) do
    print('['..dfhack.units.getProfessionName(unit)..'] '..dfhack.TranslateName(dfhack.units.getVisibleName(unit))..' '..getSexString(unit.sex)..' Stress category: '..dfhack.units.getStressCategory(unit))
  end
end

doCheck()
