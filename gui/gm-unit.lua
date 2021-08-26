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

-- Orientation editor
editor_orientation=defclass(editor_orientation,gui.FramedScreen)
editor_orientation.ATTRS={
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Orientation editor",
    target_unit = DEFAULT_NIL,
}

function editor_orientation:sexSelected(index, choice)
  local newInterest = choice.interest + 1
  -- Cycle back around if out of bounds
  if newInterest > 2 then
    newInterest = 0
  end

  setorientation.setOrientation(self.target_unit, choice.sex, newInterest)
  self:updateChoices()
end

function editor_orientation:random()
  local index, choice = self.subviews.sex:getSelected()

  setorientation.randomiseOrientation(self.target_unit, choice.sex)
  self:updateChoices()
end

function editor_orientation:updateChoices()
  local choices = {}
  -- Male
  local maleInterest = setorientation.getInterest(self.target_unit, "male")
  local maleInterestString = setorientation.getInterestString(maleInterest)
  table.insert(choices, {text = "Male: " .. maleInterestString, interest = maleInterest, sex = 1})
  -- Female
  local femaleInterest = setorientation.getInterest(self.target_unit, "female")
  local femaleInterestString = setorientation.getInterestString(femaleInterest)
  table.insert(choices, {text = "Female: " .. femaleInterestString, interest = femaleInterest, sex = 0})

  self.subviews.sex:setChoices(choices)
end

function editor_orientation:init(args)
  if self.target_unit == nil then
    qerror("invalid unit")
  end

  self:addviews{
    widgets.List{
      frame = {t=0, b=1,l=1},
      view_id = "sex",
      on_submit = self:callback("sexSelected"),
    },
    widgets.Label{
      frame = {b=0, l=1},
      text = {
        {text = ": exit editor ", key = "LEAVESCREEN", on_activate = self:callback("dismiss")},
        {text = ": cycle selected ", key = "SELECT"},
        {text = ": randomise selected", key = "CUSTOM_R", on_activate = self:callback("random")},
      },
    }
  }

  self:updateChoices()
end
add_editor(editor_orientation)

-- Body / Body Part editor
-- TODO: Trigger recalculation of body sizes after size is edited

editor_body_modifier=defclass(editor_body_modifier, gui.FramedScreen)

function showModifierScreen(target_unit, partChoice)
  editor_body_modifier{
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Select a modifier",
    target_unit = target_unit,
    partChoice = partChoice
  }:show()
end

function editor_body_modifier:beautifyString(text)
  local out = text
  out = out:lower() --Make lowercase
  out = out:gsub("_", " ") --Replace underscores with spaces
  out = out:gsub("^%l", string.upper) --capitalises first letter

  return out
end

function editor_body_modifier:setPartModifier(indexList, value)
  for _, index in ipairs(indexList) do
    self.target_unit.appearance.bp_modifiers[index] = tonumber(value)
  end
  self:updateChoices()
end

function editor_body_modifier:setBodyModifier(modifierIndex, value)
  self.target_unit.appearance.body_modifiers[modifierIndex] = tonumber(value)
  self:updateChoices()
end

function editor_body_modifier:selected(index, selected)
  dialog.showInputPrompt(
    self:beautifyString(df.appearance_modifier_type[selected.modifier.entry.type]),
    "Enter new value:",
    nil,
    tostring(selected.value),
    function(newValue)
      local value = tonumber(newValue)
      if self.partChoice.type == "part" then
        self:setPartModifier(selected.modifier.idx, value)
      else -- Body
        self:setBodyModifier(selected.modifier.index, value)
      end
    end,
    nil,nil
  )
end

function editor_body_modifier:random()
  local _, selected = self.subviews.modifiers:getSelected()
  -- How modifier randomisation works (to my knowledge):
  -- 7 values are listed in the _APPEARANCE_MODIFIER token
  -- One of the first 6 values is randomly selected with the same odds for any
  -- A random number is rolled within the range of that number, and the next one to get the modifier value

  local startIndex = rng:random(6) -- Will give a number between 0-5 which, when accounting for the fact that the range table starts at 0, gives us the index of which of the first 6 to use

  -- Set the ranges
  local min = selected.modifier.entry.ranges[startIndex]
  local max = selected.modifier.entry.ranges[startIndex+1]

  -- Get the difference between the two
  local difference = math.abs(min - max)

  -- Use the minimum, the difference, and a random roll to work out the new value.
  local roll = rng:random(difference+1) -- difference + 1 because we want to include the max value as an option
  local value = min + roll

  -- Set the modifier to the new value
  if self.partChoice.type == "part" then
    self:setPartModifier(selected.modifier.idx, value)
  else
    self:setBodyModifier(selected.modifier.index, value)
  end
end

function editor_body_modifier:step(amount)
  local _, selected = self.subviews.modifiers:getSelected()

  -- Build a table of description ranges
  local ranges = {}
  for index, value in ipairs(selected.modifier.entry.desc_range) do
    -- Only add a new entry if: There are none, or the value is higher than the previous range
    if #ranges == 0 or value > ranges[#ranges] then
      table.insert(ranges, value)
    end
  end

  -- Now determine what range the modifier currently falls into
  local currentValue = selected.value
  local rangeIndex

  for index, value in ipairs(ranges) do
    if ranges[index+1] then -- There's still a next entry
      if currentValue < ranges[index+1] then -- The current value is less than the next entry
        rangeIndex = index
        break
      end
    else -- This is the last entry
      rangeIndex = index
    end
  end

  -- Finally, move the modifier's value up / down in range tiers based on given amount
  local newTier = math.min(#ranges, math.max(1, rangeIndex + amount)) -- Clamp values to not go beyond bounds of ranges
  local newValue = ranges[newTier]

  if self.partChoice.type == "part" then
    self:setPartModifier(selected.modifier.idx, newValue)
  else
    self:setBodyModifier(selected.modifier.index, newValue)
  end
end

function editor_body_modifier:updateChoices()
  local choices = {}

  for index, modifier in ipairs(self.partChoice.modifiers) do
    local currentValue
    if self.partChoice.type == "part" then
      currentValue = self.target_unit.appearance.bp_modifiers[modifier.idx[1]]
    else -- Body
      currentValue = self.target_unit.appearance.body_modifiers[modifier.index]
    end
    table.insert(choices, {text = self:beautifyString(df.appearance_modifier_type[modifier.entry.type]) .. ": " .. currentValue, value = currentValue, modifier = modifier})
  end

  self.subviews.modifiers:setChoices(choices)
end

function editor_body_modifier:init(args)
  self.target_unit = args.target_unit
  self.partChoice = args.partChoice

  self:addviews{
    widgets.List{
      frame = {t=0, b=1,l=1},
      view_id = "modifiers",
      on_submit = self:callback("selected"),
    },
    widgets.Label{
      frame = {b=0, l=1},
      text = {
        {text = ": back ", key = "LEAVESCREEN", on_activate = self:callback("dismiss")},
        {text = ": edit modifier ", key = "SELECT"},
        {text = ": raise ", key = "CURSOR_RIGHT", on_activate = self:callback("step", 1)},
        {text = ": reduce ", key = "CURSOR_LEFT", on_activate = self:callback("step", -1)},
        {text = ": randomise selected", key = "CUSTOM_R", on_activate = self:callback("random")},
      },
    }
  }

  self.frame_title = self.partChoice.text .. " - Select a modifier"
  self:updateChoices()
end

editor_body=defclass(editor_body,gui.FramedScreen)
editor_body.ATTRS={
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Body appearance editor",
    target_unit = DEFAULT_NIL,
}

function makePartList(caste)
  local list = {}
  local lookup = {} -- Stores existing part's index in the list

  for index, modifier in ipairs(caste.bp_appearance.modifiers) do
    local name
    if modifier.noun ~= "" then
      name = modifier.noun
    else
      name = caste.body_info.body_parts[modifier.body_parts[0]].name_singular[0].value -- Use the name of the first body part modified
    end

    -- Make a new entry if this is a new part
    if lookup[name] == nil then
      local entryIndex = #list + 1
      table.insert(list, {name = name, modifiers = {}})
      lookup[name] = entryIndex
    end

    -- Find idxes associated with this modifier. These are what will be used later when setting the unit's appearance
    local idx = {}
    for searchIndex, modifierId in ipairs(caste.bp_appearance.modifier_idx) do
      if modifierId == index then
        table.insert(idx, searchIndex)
      end
    end

    -- Add modifiers to list of part
    table.insert(list[lookup[name]].modifiers, {index = index, entry = modifier, idx = idx})
  end

  return list
end

function editor_body:updateChoices()
  local choices = {}
  local caste = df.creature_raw.find(self.target_unit.race).caste[self.target_unit.caste]

  -- Body is a special case
  if #caste.body_appearance_modifiers > 0 then
    local bodyEntry = {text = "Body", modifiers = {}, type = "body"}
    for index, modifier in ipairs(caste.body_appearance_modifiers) do
      table.insert(bodyEntry.modifiers, {index = index, entry = modifier})
    end
    table.insert(choices, bodyEntry)
  end

  local partList = makePartList(caste)
  for index, partEntry in ipairs(partList) do
    table.insert(choices, {text = partEntry.name:gsub("^%l", string.upper), modifiers = partEntry.modifiers, type = "part"})
  end

  self.subviews.featureSelect:setChoices(choices)
end

function editor_body:partSelected(index, choice)
  showModifierScreen(self.target_unit, choice)
end

function editor_body:init(args)
  if self.target_unit == nil then
    qerror("invalid unit")
  end

  self:addviews{
    widgets.List{
      frame = {t=0, b=1,l=1},
      view_id = "featureSelect",
      on_submit = self:callback("partSelected"),
    },
    widgets.Label{
      frame = {b=0, l=1},
      text = {
        {text = ": exit editor ", key = "LEAVESCREEN", on_activate = self:callback("dismiss")},
        {text = ": select feature ", key = "SELECT"},
      },
    }
  }

  self:updateChoices()
end
add_editor(editor_body)


-- Colors editor
editor_colors=defclass(editor_colors,gui.FramedScreen)
editor_colors.ATTRS={
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Colors editor",
    target_unit = DEFAULT_NIL,
}

function patternString(patternId)
  local pattern = df.descriptor_pattern.find(patternId)
  local prefix
  if pattern.pattern == 0 then --Monochrome
    return df.descriptor_color.find(pattern.colors[0]).name
  elseif pattern.pattern == 1 then --Stripes
    prefix = "striped"
  elseif pattern.pattern == 2 then --Iris_eye
    return df.descriptor_color.find(pattern.colors[2]).name .. " eyes"
  elseif pattern.pattern == 3 then --Spots
    prefix = "spotted" --that's a guess
  elseif pattern.pattern == 4 then --Pupil_eye
    return df.descriptor_color.find(pattern.colors[2]).name .. " eyes"
  elseif pattern.pattern == 5 then --mottled
    prefix = "mottled"
  end
  local out = prefix .. " "
  for i=0, #pattern.colors-1 do
    if i == #pattern.colors-1 then
      out = out .. "and " .. df.descriptor_color.find(pattern.colors[i]).name
    elseif i == #pattern.colors-2 then
      out = out .. df.descriptor_color.find(pattern.colors[i]).name .. " "
    else
      out = out .. df.descriptor_color.find(pattern.colors[i]).name .. ", "
    end
  end
  return out
end

function editor_colors:random()
  local featureChoiceIndex, featureChoice = self.subviews.features:getSelected() -- This is the part / feature that's selected
  local caste = df.creature_raw.find(self.target_unit.race).caste[self.target_unit.caste]

  -- Nil check in case there are no features
  if featureChoiceIndex == nil then
    return
  end

  local options = {}

  for index, patternId in ipairs(featureChoice.mod.pattern_index) do
    local addition = {}
    addition.patternId = patternId
    addition.index = index -- This is the position of the pattern within the modifier index. It's this value (not the pattern ID), that's used in the unit appearance to select their color
    addition.weight = featureChoice.mod.pattern_frequency[index]
    table.insert(options, addition)
  end

  -- Now create a table from this to use for the weighted roller
  -- We'll use the index as the item appears in options for the id
  local weightedTable = {}
  for index, entry in ipairs(options) do
    local addition = {}
    addition.id = index
    addition.weight = entry.weight
    table.insert(weightedTable, addition)
  end

  -- Roll randomly. The result will give us the index of the option to use
  local result = weightedRoll(weightedTable)

  -- Set the unit's appearance for the feature to the new pattern
  self.target_unit.appearance.colors[featureChoice.index] = options[result].index

  -- Notify the user on the change, so they get some visual feedback that something has happened
  local pluralWord
  if featureChoice.mod.unk_6c == 1 then
    pluralWord = "are"
  else
    pluralWord = "is"
  end

  dialog.showMessage("Color randomised!",
    featureChoice.text .. " " .. pluralWord .." now " .. patternString(options[result].patternId),
    nil, nil)
end

function editor_colors:colorSelected(index, choice)
  -- Update the modifier for the unit
  self.target_unit.appearance.colors[self.modIndex] = choice.index
end

function editor_colors:featureSelected(index, choice)
  -- Store the index of the modifier we're editing
  self.modIndex = choice.index

  -- Generate color choices
  local colorChoices = {}

  for index, patternId in ipairs(choice.mod.pattern_index) do
    table.insert(colorChoices, {text = patternString(patternId), index = index})
  end

  dialog.showListPrompt(
    "Choose color",
    "Select feature's color", nil,
    colorChoices,
    function(selectIndex, selectChoice)
      self:colorSelected(selectIndex, selectChoice)
    end,
    nil, nil,
    true
  )
end

function editor_colors:updateChoices()
  local caste = df.creature_raw.find(self.target_unit.race).caste[self.target_unit.caste]
  local choices = {}
  for index, colorMod in ipairs(caste.color_modifiers) do
    table.insert(choices, {text = colorMod.part:gsub("^%l", string.upper), mod = colorMod, index = index})
  end

  self.subviews.features:setChoices(choices)
end

function editor_colors:init(args)
  if self.target_unit == nil then
    qerror("invalid unit")
  end

  self:addviews{
    widgets.List{
      frame = {t=0, b=1,l=1},
      view_id = "features",
      on_submit = self:callback("featureSelected"),
    },
    widgets.Label{
      frame = {b=0, l=1},
      text = {
        {text = ": exit editor ", key = "LEAVESCREEN", on_activate = self:callback("dismiss")},
        {text = ": edit feature ", key = "SELECT"},
        {text = ": randomise color", key = "CUSTOM_R", on_activate = self:callback("random")},
      },
    }
  }

  self:updateChoices()
end
add_editor(editor_colors)

-- Belief editor
editor_belief = defclass(editor_belief, gui.FramedScreen)
editor_belief.ATTRS = {
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Belief editor",
    target_unit = DEFAULT_NIL,
}

function editor_belief:randomiseSelected()
  local index, choice = self.subviews.beliefs:getSelected()

  setbelief.randomiseUnitBelief(self.target_unit, choice.belief)
  self:updateChoices()
end

function editor_belief:step(amount)
  local index, choice = self.subviews.beliefs:getSelected()

  setbelief.stepUnitBelief(self.target_unit, choice.belief, amount)
  self:updateChoices()
end

function editor_belief:updateChoices()
  local choices = {}

  for index, belief in ipairs(df.value_type) do
    if belief ~= 'NONE' then
      local niceText = belief
      niceText = niceText:lower()
      niceText = niceText:gsub("_", " ")
      niceText = niceText:gsub("^%l", string.upper)

      local strength = setbelief.getUnitBelief(self.target_unit, index)
      local symbolAddition = ""
      if setbelief.isCultureBelief(self.target_unit, index) then
        symbolAddition = "*"
      end

      table.insert(choices, {["text"] = niceText .. ": " .. strength .. symbolAddition, ["belief"] = index, ["value"] = strength, ["name"] = niceText})
    end
  end

  self.subviews.beliefs:setChoices(choices)
end

function editor_belief:average(index, choice)
  setbelief.removeUnitBelief(self.target_unit, choice.belief)
  self:updateChoices()
end

function editor_belief:edit(index, choice)
  dialog.showInputPrompt(
    choice.name,
    "Enter new value:",
    COLOR_WHITE,
    tostring(choice.value),
    function(newValue)
      setbelief.setUnitBelief(self.target_unit, choice.belief, tonumber(newValue), true)
      self:updateChoices()
    end
  )
end

function editor_belief:close()
  setneed.rebuildNeeds(self.target_unit)
  self:dismiss()
end

function editor_belief:init(args)
  if self.target_unit==nil then
      qerror("invalid unit")
  end

  self:addviews{
    widgets.List{
      frame = {t=0, b=2,l=1},
      view_id = "beliefs",
      on_submit = self:callback("edit"),
      on_submit2 = self:callback("average")
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
        {text = "* denotes cultural default "},
        {text = ": set to cultural default", key = "SEC_SELECT"}
      }
    },
  }

  self:updateChoices()
end
add_editor(editor_belief)


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
