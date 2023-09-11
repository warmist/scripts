-- Detects and alerts when a citizen is stranded
-- by Azrazalea
-- Heavily based off of warn-starving
-- Thanks myk002 for telling me about pathability groups!
--@ module = true

local gui = require 'gui'
local utils = require 'utils'
local widgets = require 'gui.widgets'

warning = defclass(warning, gui.ZScreen)
warning.ATTRS = {
    focus_path='warn-stranded',
    force_pause=true,
    pass_mouse_clicks=false,
}

function warning:init(info)
    local main = widgets.Window{
        frame={w=80, h=18},
        frame_title='Stranded Citizen Warning',
        resizable=true,
        autoarrange_subviews=true
    }

    main:addviews{
        widgets.WrappedLabel{
            text_to_wrap=table.concat(info.messages, NEWLINE),
        }
    }

    self:addviews{main}
end

function warning:onDismiss()
    view = nil
end

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

  if #strandedUnits > 0 then
    dfhack.color(COLOR_LIGHTMAGENTA)

    local messages = {}
    local preface = "Number of stranded: "..#strandedUnits
    print(dfhack.df2console(preface))
    table.insert(messages, preface)
    for _, unit in pairs(strandedUnits) do
      local unitString = '['..dfhack.units.getProfessionName(unit)..'] '..dfhack.TranslateName(dfhack.units.getVisibleName(unit))..' '..getSexString(unit.sex)..' Stress category: '..dfhack.units.getStressCategory(unit)
      print(dfhack.df2console(unitString))
      table.insert(messages, unitString)
    end

    dfhack.color()
    return warning{messages=messages}:show()
   end
end

if dfhack_flags.module then
    return
end

if not dfhack.isMapLoaded() then
    qerror('warn-stranded requires a map to be loaded')
end

view = view and view:raise() or doCheck()
