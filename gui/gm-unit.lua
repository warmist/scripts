-- Interface powered, user friendly, unit editor
--@ module = true

--[====[

gui/gm-unit
===========
An editor for various unit attributes.

]====]
local gui = require 'gui'
local dialog = require 'gui.dialogs'
local widgets = require 'gui.widgets'
local guiScript = require 'gui.script'
local utils = require 'utils'
local args = {...}
local setbelief = dfhack.reqscript("modtools/set-belief")
local setpersonality = dfhack.reqscript("modtools/set-personality")
local setneed = dfhack.reqscript("modtools/set-need")
local setorientation = dfhack.reqscript("set-orientation")

Editor = defclass(Editor, gui.FramedScreen)
Editor.ATTRS = {
    frame_style = gui.GREY_LINE_FRAME,
    target_unit = DEFAULT_NIL
}

rng = rng or dfhack.random.new(nil, 10)

local target
--TODO: add more ways to guess what unit you want to edit
if args[1] ~= nil then
    target = df.units.find(args[1])
else
    target = dfhack.gui.getSelectedUnit(true)
end

if target == nil then
    qerror("No unit to edit") --TODO: better error message
end
local editors = {}
function add_editor(editor_class)
    local title = editor_class.ATTRS.frame_title
    table.insert(editors, {text=title, search_key=title:lower(), on_submit=function(unit)
        editor_class{target_unit=unit}:show()
    end})
end

function weightedRoll(weightedTable)
  local maxWeight = 0
  for index, result in ipairs(weightedTable) do
    maxWeight = maxWeight + result.weight
  end

  local roll = rng:random(maxWeight) + 1
  local currentNum = roll
  local result

  for index, currentResult in ipairs(weightedTable) do
    currentNum = currentNum - currentResult.weight
    if currentNum <= 0 then
      result = currentResult.id
      break
    end
  end

  return result
end


-------------------------------various subeditors---------
------- skill editor
editor_skills = reqscript("gui/editor_skills")
add_editor(editor_skills.Editor_Skills)

------- civilization editor
editor_civ = reqscript("gui/editor_civilization")
add_editor(editor_civ.Editor_Civ)

------- counters editor
editor_counters = reqscript("gui/editor_counters")
add_editor(editor_counters.Editor_Counters)

------- profession editor
editor_prof = reqscript("gui/editor_profession")
add_editor(editor_prof.Editor_Prof)

------- wounds editor
editor_wounds = reqscript("gui/editor_wounds")
add_editor(editor_wounds.Editor_Wounds)

------- attributes editor
editor_attrs = reqscript("gui/editor_attributes")
add_editor(editor_attrs.Editor_Attrs)

------- orientation editor
editor_orientation = reqscript("gui/editor_orientation")
add_editor(editor_orientation.Editor_Orientation)

------- body / body part editor
editor_body = reqscript("gui/editor_body")
add_editor(editor_body.Editor_Body)

------- colors editor
editor_colors = reqscript("gui/editor_colors")
add_editor(editor_colors.Editor_Colors)

------- beliefs editor
editor_beliefs = reqscript("gui/editor_beliefs")
add_editor(editor_beliefs.Editor_Beliefs)

-- Personality editor
editor_personality = defclass(editor_personality, gui.FramedScreen)
editor_personality.ATTRS = {
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Personality editor",
    target_unit = DEFAULT_NIL,
}

function editor_personality:randomiseSelected()
  local index, choice = self.subviews.traits:getSelected()

  setpersonality.randomiseUnitTrait(self.target_unit, choice.trait)
  self:updateChoices()
end

function editor_personality:step(amount)
  local index, choice = self.subviews.traits:getSelected()

  setpersonality.stepUnitTrait(self.target_unit, choice.trait, amount)
  self:updateChoices()
end

function editor_personality:updateChoices()
  local choices = {}

  for index, traitName in ipairs(df.personality_facet_type) do
    if traitName ~= 'NONE' then
      local niceText = traitName
      niceText = niceText:lower()
      niceText = niceText:gsub("_", " ")
      niceText = niceText:gsub("^%l", string.upper)

      local strength = setpersonality.getUnitTraitBase(self.target_unit, index)

      table.insert(choices, {["text"] = niceText .. ": " .. strength, ["trait"] = index, ["value"] = strength, ["name"] = niceText})
    end
  end

  self.subviews.traits:setChoices(choices)
end

function editor_personality:averageTrait(index, choice)
  setpersonality.averageUnitTrait(self.target_unit, choice.trait)
  self:updateChoices()
end

function editor_personality:editTrait(index, choice)
  dialog.showInputPrompt(
    choice.name,
    "Enter new value:",
    COLOR_WHITE,
    tostring(choice.value),
    function(newValue)
      setpersonality.setUnitTrait(self.target_unit, choice.trait, tonumber(newValue))
      self:updateChoices()
    end
  )
end

function editor_personality:close()
  setneed.rebuildNeeds(self.target_unit)
  self:dismiss()
end

function editor_personality:init(args)
  if self.target_unit==nil then
      qerror("invalid unit")
  end

  self:addviews{
    widgets.List{
      frame = {t=0, b=2,l=1},
      view_id = "traits",
      on_submit = self:callback("editTrait"),
      on_submit2 = self:callback("averageTrait")
    },
    widgets.Label{
      frame = {b=1, l=1},
      text = {
        {text = ": exit editor ", key = "LEAVESCREEN", on_activate = self:callback("close")},
        {text = ": edit value ", key = "SELECT"},
        {text = ": randomise selected ", key = "CUSTOM_R", on_activate = self:callback("randomiseSelected")},
        {text = ": raise ", key = "CURSOR_RIGHT", on_activate = self:callback("step", 1)},
        {text = ": reduce", key = "CURSOR_LEFT", on_activate = self:callback("step", -1)},
      },
    },
    widgets.Label{
      frame = {b = 0, l = 1},
      text = {
        {text = ": set to caste average", key = "SEC_SELECT"}
      }
    },
  }

  self:updateChoices()
end
add_editor(editor_personality)

-------------------------------main window----------------
unit_editor = defclass(unit_editor, gui.FramedScreen)
unit_editor.ATTRS = {
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "GameMaster's unit editor",
    target_unit = DEFAULT_NIL,
}


function unit_editor:init(args)
    self:addviews{
        widgets.FilteredList{
            frame = {l=1, t=1},
            choices=editors,
            on_submit=function (idx,choice)
                if choice.on_submit then
                    choice.on_submit(self.target_unit)
                end
            end
        },
        widgets.Label{
            frame = { b=0,l=1},
            text = {{
                text = ": exit editor",
                key = "LEAVESCREEN",
                on_activate = self:callback("dismiss")
            }},
        }
    }
end


unit_editor{target_unit=target}:show()
