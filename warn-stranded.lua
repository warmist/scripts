-- Detects and alerts when a citizen is stranded
-- Logic heavily based off of warn-starving
-- GUI heavily based off of autobutcher
--@ module = true

local gui = require 'gui'
local utils = require 'utils'
local widgets = require 'gui.widgets'
local args = nil

-- ===============================================
--              Utility Functions
-- ===============================================

-- Clear the ignore list
local function clear()
    dfhack.persistent.delete('warnStrandedIgnore')
end

-- Taken from warn-starving
local function getSexString(sex)
    local sym = df.pronoun_type.attrs[sex].symbol

    if sym then
        return "("..sym..")"
    else
        return ""
    end
end

-- Partially taken from warn-starving
local function getUnitDescription(unit)
    return '['..dfhack.units.getProfessionName(unit)..'] '..dfhack.TranslateName(dfhack.units.getVisibleName(unit))..
        ' '..getSexString(unit.sex)..' Stress category: '..dfhack.units.getStressCategory(unit)
end

-- Use group data, index, and command arguments to generate a group
--   designation string.
local function getGroupDesignation(group, groupIndex)
    local groupDesignation = ''

    if group['mainGroup'] then
        groupDesignation = ' (Main Group)'
    else
        groupDesignation = ' (Group '..groupIndex..')'
    end

    if args.walk_groups then
        groupDesignation = groupDesignation..' {'..group.walkGroup..'}'
    end

    return groupDesignation
end

-- Check for and potentially add unit.id to text. Controlled by command args.
local function addId(text, unit)
    if args.ids then
        return text..'|'..unit.id..'| '
    else
        return text
    end
end

-- Uses persistent API. Low-level, deserializes 'warnStrandedIgnored' key and
--   will return an initialized empty warnStrandedIgnored table if needed.
-- Performance characterstics unknown of persistent API
local function deserializeIgnoredUnits()
    local currentIgnore = dfhack.persistent.get('warnStrandedIgnore')
    if currentIgnore == nil then return {} end

    local tbl = {}

    for v in string.gmatch(currentIgnore['value'], '%d+') do
        table.insert(tbl, v)
    end

    return tbl
end

-- Uses persistent API. Deserializes 'warnStrandedIgnore' key to determine if unit is ignored
--   deserializedIgnores is optional but allows us to only call deserialize once like an explicit cache.
local function unitIgnored(unit, deserializedIgnores)
    local ignores = deserializedIgnores or deserializeIgnoredUnits()

    for index, id in ipairs(ignores) do
        if tonumber(id) == unit.id then
            return true, index
        end
    end

    return false
end

-- Check for and potentially add [IGNORED] to text. Controlled by command args.
--   Optional deserializedIgnores allows us to call deserialize once for a group of operations
local function addIgnored(text, unit, deserializedIgnores)
    if unitIgnored(unit, deserializedIgnores) then
        return text..'[IGNORED] '
    end

    return text
end

-- Uses persistent API. Toggles a unit's ignored status by deserializing 'warnStrandedIgnore' key
--   then serializing the resulting table after the toggle.
-- Optional cache parameter could affect data integrity. Make sure you don't need data reloaded
--   before using it. Calling several times in a row can use the return result of the function
--   as input to the next call.
local function toggleUnitIgnore(unit, deserializedIgnores)
    local ignores = deserializedIgnores or deserializeIgnoredUnits()
    local is_ignored, index = unitIgnored(unit, ignores)

    if is_ignored then
        table.remove(ignores, index)
    else
        table.insert(ignores, unit.id)
    end

    dfhack.persistent.delete('warnStrandedIgnore')
    dfhack.persistent.save({key = 'warnStrandedIgnore', value = table.concat(ignores, ' ')})

    return ignores
end

-- ===============================================================
--                   Graphical Interface
-- ===============================================================
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


function warning:initListChoices()
    local choices = {}

    for groupIndex, group in ipairs(self.groups) do
        local groupDesignation = getGroupDesignation(group, groupIndex)
        local ignoresCache = deserializeIgnoredUnits()

        for _, unit in ipairs(group['units']) do
            local text = ''

            text = addIgnored(text, unit, ignoresCache)
            text = addId(text, unit)
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
    local ignoresCache = deserializeIgnoredUnits()

    for _, choice in ipairs(choices) do
        -- We don't want to flip ignored units to unignored
        if not unitIgnored(choice.data['unit'], ignoresCache) then
            ignoresCache = toggleUnitIgnore(choice.data['unit'], ignoresCache)
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

-- ======================================================================
--                         Core Logic
-- ======================================================================

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
    local ignoresCache = deserializeIgnoredUnits()

    -- Pathability group calculation is from gui/pathable
    for _, unit in ipairs(citizens) do
        local target = xyz2pos(dfhack.units.getPosition(unit))
        local block = dfhack.maps.getTileBlock(target)
        local walkGroup = block and block.walkable[target.x % 16][target.y % 16] or 0

        if unitIgnored(unit, ignoresCache) then
            table.insert(ensure_key(ignoredGroup, walkGroup), unit)
        else
            table.insert(ensure_key(grouped, walkGroup), unit)

            -- Count each new group
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

-- =========================================================================
--                       Command Line Interface
-- =========================================================================

args = utils.invert({...})

if args.clear then
    clear()
end

if args.status then
    local result, strandedGroups = getStrandedUnits()

    if result then
        local ignoresCache = deserializeIgnoredUnits()

        for groupIndex, group in ipairs(strandedGroups) do
            local groupDesignation = getGroupDesignation(group, groupIndex)

            for _, unit in ipairs(group['units']) do
                local text = ''

                text = addIgnored(text, unit, ignoresCache)
                text = addId(text, unit)

                print(text..getUnitDescription(unit)..groupDesignation)
            end
        end

        return true
    end


    print('No citizens are currently stranded.')

    -- We have some ignored citizens
    if not (next(strandedGroups) == nil) then
        print('\nIgnored citizens:')

        for walkGroup, units in pairs(strandedGroups) do
            for _, unit in ipairs(units) do
                local text = ''

                text = addId(text, unit)

                text = text..getUnitDescription(unit)..' {'..walkGroup..'}'
                print(text)
            end
        end
    end

    return false
end

view = view and view:raise() or doCheck()
