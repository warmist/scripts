-- Detects and alerts when a citizen is stranded
-- by Azrazalea
-- Logic heavily based off of warn-starving
-- GUI heavily based off of autobutcher
-- Thanks myk002 for telling me about pathability groups!
--@ module = true

local gui = require 'gui'
local utils = require 'utils'
local widgets = require 'gui.widgets'

local function clear()
   dfhack.persistent.delete('warnStrandedIgnore')
end

local args = utils.invert({...})
if args.clear then
   clear()
end


warning = defclass(warning, gui.ZScreen)
warning.ATTRS = {
    focus_path='warn-stranded',
    force_pause=true,
    pass_mouse_clicks=false,
}

function warning:init(info)
    self:addviews{
       widgets.Window{
          view_id = 'main',
          frame={w=80, h=18},
          frame_title='Stranded Citizen Warning',
          resizable=true,
          subviews = {
             widgets.Label{
                frame = { l = 0, t = 0},
                text_pen = COLOR_CYAN,
                text = 'Number Stranded: '..#info.units,
             },
             widgets.List{
                view_id = 'list',
                frame = { t = 3, b = 5 },
                text_pen = { fg = COLOR_GREY, bg = COLOR_BLACK },
                cursor_pen = { fg = COLOR_BLACK, bg = COLOR_GREEN },
             },
             widgets.Label{
                view_id = 'bottom_ui',
                frame = { b = 0, h = 1 },
                text = 'filled by updateBottom()'
             }
          }
       }
    }

    self.units = info.units
    self:initListChoices()
    self:updateBottom()
end

local function getSexString(sex)
  local sym = df.pronoun_type.attrs[sex].symbol
  if not sym then
    return ""
  end
  return "("..sym..")"
end

local function getUnitDescription(unit)
   return '['..dfhack.units.getProfessionName(unit)..'] '..dfhack.TranslateName(dfhack.units.getVisibleName(unit))..
      ' '..getSexString(unit.sex)..' Stress category: '..dfhack.units.getStressCategory(unit)
end


local function unitIgnored(unit)
   local currentIgnore = dfhack.persistent.get('warnStrandedIgnore')
   if currentIgnore == nil then return false end

   local tbl = string.gmatch(currentIgnore['value'], '%d+')
   local index = 1
   for id in tbl do
      if tonumber(id) == unit.id then
         return true, index
      end
      index = index + 1
   end

   return false
end

local function toggleUnitIgnore(unit)
   local currentIgnore = dfhack.persistent.get('warnStrandedIgnore')
   local tbl = {}

   if currentIgnore == nil then
      currentIgnore = { key = 'warnStrandedIgnore' }
   else
      local index = 1
      for v in string.gmatch(currentIgnore['value'], '%d+') do
        tbl[index] = v
        index = index + 1
      end
   end

   local ignored, index = unitIgnored(unit)

   if ignored then
      table.remove(tbl, index)
   else
      table.insert(tbl, unit.id)
   end

   dfhack.persistent.delete('warnStrandedIgnore')
   currentIgnore.value = table.concat(tbl, ' ')
   dfhack.persistent.save(currentIgnore)
end

function warning:initListChoices()
   local choices = {}
   for _, unit in pairs(self.units) do
      local text = ''

      dfhack.printerr('Ignored: ', unitIgnored(unit))

      if unitIgnored(unit) then
         text = '[IGNORED] '
      end

      text = text..getUnitDescription(unit)
      table.insert(choices, { text = text, unit = unit })
   end
   local list = self.subviews.list
   list:setChoices(choices, 1)
end

function warning:updateBottom()
   self.subviews.bottom_ui:setText(
      {
         { key = 'SELECT', text = ': Toggle ignore unit', on_activate = self:callback('onIgnore') }, ' ',
         { key = 'CUSTOM_SHIFT_I', text = ': Ignore all', on_activate = self:callback('onIgnoreAll') }, ' ',
         { key = 'CUSTOM_SHIFT_C', text = ': Clear all ignored', on_activate = self:callback('onClear') },
      }
   )
end

function warning:onIgnore()
   local index, choice = self.subviews.list:getSelected()
   local unit = choice.unit

   toggleUnitIgnore(unit)
   self:initListChoices()
end

function warning:onIgnoreAll()
   local choices = self.subviews.list:getChoices()

   for _, choice in pairs(choices) do
      if not unitIgnored(choice.unit) then
         toggleUnitIgnore(choice.unit)
      end
   end

   self:dismiss()
end

function warning:onClear()
   clear()
   self:initListChoices()
   self:updateBottom()
end

function warning:onDismiss()
    view = nil
end

function doCheck()
  local grouped = {}
  local citizens = dfhack.units.getCitizens()

  -- Pathability group calculation is from gui/pathable
  for _, unit in ipairs(citizens) do
    local target = unit.pos
    local block = dfhack.maps.getTileBlock(target)
    local walkGroup = block and block.walkable[target.x % 16][target.y % 16] or 0
    table.insert(ensure_key(grouped, walkGroup), unit)
  end

  local strandedUnits = {}


  for _, units in pairs(grouped) do
    if #units == 1 and not unitIgnored(units[1]) then
      table.insert(strandedUnits, units[1])
    end
  end

  if #strandedUnits > 0 then
    return warning{units=strandedUnits}:show()
   end
end

if dfhack_flags.module then
    return
end

if not dfhack.isMapLoaded() then
    qerror('warn-stranded requires a map to be loaded')
end

view = view and view:raise() or doCheck()
