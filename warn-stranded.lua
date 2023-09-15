-- Detects and alerts when a citizen is stranded
-- Logic heavily based off of warn-starving
-- GUI heavily based off of autobutcher
--@ module = true

local gui = require 'gui'
local utils = require 'utils'
local widgets = require 'gui.widgets'

local function clear()
    dfhack.persistent.delete('warnStrandedIgnore')
end

warning = defclass(warning, gui.ZScreenModal)

function warning:init(info)
    self:addviews{
        widgets.Window{
            view_id = 'main',
            frame={w=80, h=18},
            frame_title='Stranded Citizen Warning',
            resizable=true,
            subviews = {
                widgets.List{
                    view_id = 'list',
                    frame = { t = 1, l=0 },
                    text_pen = { fg = COLOR_GREY, bg = COLOR_BLACK },
                    cursor_pen = { fg = COLOR_BLACK, bg = COLOR_GREEN },
                },
                widgets.HotkeyLabel{
                    frame = { b=4, l=0},
                    key='SELECT',
                    label='Toggle Ignore',
                    on_activate=self:callback('onIgnore'),
                },
                widgets.HotkeyLabel{
                    frame = { b=3, l=0 },
                    key = 'CUSTOM_SHIFT_I',
                    label = 'Ignore All',
                    on_activate = self:callback('onIgnoreAll') },
                widgets.HotkeyLabel{
                    frame = { b=2, l=0 },
                    key = 'CUSTOM_SHIFT_C',
                    label = 'Clear All Ignored',
                    on_activate = self:callback('onClear'),
                },
                widgets.HotkeyLabel{
                    frame = { b=1, l=0},
                    key = 'CUSTOM_Z',
                    label = 'Zoom to unit',
                    on_activate = self:callback('onZoom'),
                }
            }
        }
    }

    self.groups = info.groups
    self:initListChoices()
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

    for groupIndex, group in ipairs(self.groups) do
        local groupDesignation = nil

        if group['mainGroup'] then
            groupDesignation = ' (Main Group)'
        else
            groupDesignation = ' (Group '..groupIndex..')'
        end

        for _, unit in ipairs(group['units']) do
            local text = ''

            if unitIgnored(unit) then
                text = '[IGNORED] '
            end

            text = text..getUnitDescription(unit)..groupDesignation
            table.insert(choices, { text = text, data = {unit = unit, group = index} })
        end
    end

    local list = self.subviews.list
    list:setChoices(choices, 1)
end

function warning:onIgnore()
    local index, choice = self.subviews.list:getSelected()
    local unit = choice.data['unit']

    toggleUnitIgnore(unit)
    self:initListChoices()
end

function warning:onIgnoreAll()
    local choices = self.subviews.list:getChoices()

    for _, choice in ipairs(choices) do
        if not unitIgnored(choice.data['unit']) then
            toggleUnitIgnore(choice.data['unit'])
        end
    end

    self:dismiss()
end

function warning:onClear()
    clear()
    self:initListChoices()
end

function warning:onZoom()
    local index, choice = self.subviews.list:getSelected()
    local unit = choice.data['unit']

    local target = xyz2pos(dfhack.units.getPosition(unit))
    dfhack.gui.revealInDwarfmodeMap(target, true)
end

function warning:onDismiss()
    view = nil
end

local function compareGroups(group_one, group_two)
    return #group_one['units'] < #group_two['units']
end

local function getStrandedUnits()
    local groupCount = 0
    local grouped = {}
    local citizens = dfhack.units.getCitizens()

    -- Don't use ignored units to determine if there are any stranded units
    -- but keep them to display later
    local ignoredGroup = {}

    -- Pathability group calculation is from gui/pathable
    for _, unit in ipairs(citizens) do
        local target = xyz2pos(dfhack.units.getPosition(unit))
        local block = dfhack.maps.getTileBlock(target)
        local walkGroup = block and block.walkable[target.x % 16][target.y % 16] or 0

        if unitIgnored(unit) then
            table.insert(ensure_key(ignoredGroup, walkGroup), unit)
        else
            table.insert(ensure_key(grouped, walkGroup), unit)
            if #grouped[walkGroup] == 1 then
                groupCount = groupCount + 1
            end
        end
    end

    -- No one is stranded, so stop here
    if groupCount <= 1 then
        return false, ignoredGroup
    end

    -- We needed the table for easy grouping
    -- Now let us get an array so we can sort easily
    local rawGroups = {}
    for index, units in pairs(grouped) do
        table.insert(rawGroups, { units = units, walkGroup = index })
    end

    -- This data structure is super easy to sort from biggest to smallest
    -- Our group number is just the array index and is sorted for us
    table.sort(rawGroups, compareGroups)

    -- The biggest group is not stranded
    mainGroup = rawGroups[1]['walkGroup']
    table.remove(rawGroups, #rawGroups)

    -- Merge ignoredGroup with grouped
    for index, units in pairs(ignoredGroup) do
        local groupIndex = nil

        -- Handle ignored units in mainGroup by shifting other groups down
        -- We need to list them so they can be toggled
        if index == mainGroup then
            table.insert(rawGroups, 1, { units = {}, walkGroup = mainGroup, mainGroup = true })
            groupIndex = 1
        end

        -- Find matching group
        for i, group in ipairs(rawGroups) do
            if group.walkGroup == index then
                groupIndex = i
            end
        end

        -- No matching group
        if groupIndex == nil then
            table.insert(rawGroups, { units = {}, walkGroup = index })
            groupIndex = #rawGroups
        end

        -- Put all the units in the appropriate group
        for _, unit in ipairs(units) do
            table.insert(rawGroups[groupIndex]['units'], unit)
        end
    end

    -- Key = group number (not pathability group number)
    -- Value = { units = <array of units>, walkGroup = <pathability group>, mainGroup = <is this ignored units from the main group?> }
    return true, rawGroups
end


function doCheck()
    local result, strandedGroups = getStrandedUnits()

    if result then
        return warning{groups=strandedGroups}:show()
    end
end

if dfhack_flags.module then
    return
end

if not dfhack.isMapLoaded() then
    qerror('warn-stranded requires a map to be loaded')
end

local args = utils.invert({...})

if args.clear or args.all then
    clear()
end

if args.status then
    local result, strandedGroups = getStrandedUnits()

    if not result then
        print('No citizens are currently stranded.')

        -- We have some ignored citizens
        if not (next(strandedGroups) == nil) then
            print('\nIgnored citizens:')

            for walkGroup, units in pairs(strandedGroups) do
                for _, unit in ipairs(units) do
                    local text = ''

                    if args.ids then
                        text = text..'|'..unit.id..'| '
                    end

                    text = text..getUnitDescription(unit)..' {'..walkGroup..'}'
                    print(text)
                end
            end
        end

        return false
    end

    for groupIndex, group in ipairs(strandedGroups) do
        local groupDesignation = nil

        if group['mainGroup'] then
            groupDesignation = ' (Main Group)'
        else
            groupDesignation = ' (Group '..groupIndex..')'
        end

        if args.walk_groups then
            groupDesignation = groupDesignation..' {'..group.walkGroup..'}'
        end

        for _, unit in ipairs(group['units']) do
            local text = ''

            if unitIgnored(unit) then
                text = '[IGNORED] '
            end

            if args.ids then
                text = text..'|'..unit.id..'| '
            end

            text = text..getUnitDescription(unit)..groupDesignation
            print(text)
        end
    end

    return true
end

view = view and view:raise() or doCheck()
