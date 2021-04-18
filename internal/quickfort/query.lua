-- query-related logic for the quickfort script
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local gui = require('gui')
local guidm = require('gui.dwarfmode')
local utils = require('utils')
local quickfort_common = reqscript('internal/quickfort/common')
local quickfort_aliases = reqscript('internal/quickfort/aliases')
local quickfort_keycodes = reqscript('internal/quickfort/keycodes')
local quickfort_map = reqscript('internal/quickfort/map')
local quickfort_set = reqscript('internal/quickfort/set')

local log = quickfort_common.log
local common_aliases_filename = 'hack/data/quickfort/aliases-common.txt'
local user_aliases_filename = 'dfhack-config/quickfort/aliases.txt'

local function load_aliases(ctx)
    -- ensure we're starting from a clean alias stack, even if the previous
    -- invocation of this function returned early with an error
    quickfort_aliases.reset_aliases()
    quickfort_aliases.push_aliases_file(common_aliases_filename)
    quickfort_aliases.push_aliases_file(user_aliases_filename)
    local num_file_aliases = 0
    for _ in pairs(ctx.aliases) do num_file_aliases = num_file_aliases + 1 end
    if num_file_aliases > 0 then
        quickfort_aliases.push_aliases(ctx.aliases)
        log('successfully read in %d aliases from "%s"',
            num_file_aliases, ctx.blueprint_name)
    end
end

local function is_queryable_tile(pos)
    local flags, occupancy = dfhack.maps.getTileFlags(pos)
    return not flags.hidden and
        (occupancy.building ~= 0 or
         dfhack.buildings.findCivzonesAt(pos))
end

local function handle_modifiers(token, modifiers)
    local token_lower = token:lower()
    if token_lower == 'shift' or
            token_lower == 'ctrl' or
            token_lower == 'alt' then
        modifiers[token_lower] = true
        return true
    end
    if token_lower == 'wait' then
        -- accepted for compatibility with Python Quickfort, but waiting has no
        -- effect in DFHack quickfort.
        return true
    end
    return false
end

-- the sidebar modes that we know how to get back to if the player starts there
-- instead of query mode
local basic_ui_sidebar_modes = {
    [df.ui_sidebar_mode.QueryBuilding]='D_BUILDJOB',
    [df.ui_sidebar_mode.LookAround]='D_LOOK',
    [df.ui_sidebar_mode.BuildingItems]='D_BUILDITEM',
    [df.ui_sidebar_mode.Stockpiles]='D_STOCKPILES',
    [df.ui_sidebar_mode.Zones]='D_CIVZONE',
}

-- Send ESC keycodes until we get to Dwarfmode/Default and enter the specified
-- sidebar mode. If we don't get to Default after 10 presses of ESC, throw an
-- error. The target sidebar mode must be a member of basic_ui_sidebar_modes.
local function switch_ui_sidebar_mode(sidebar_mode)
    for i=1,10 do
        if df.global.ui.main.mode == df.ui_sidebar_mode.Default then
            gui.simulateInput(dfhack.gui.getCurViewscreen(true),
                              basic_ui_sidebar_modes[sidebar_mode])
            return
        end
        gui.simulateInput(dfhack.gui.getCurViewscreen(true), 'LEAVESCREEN')
    end
    qerror('Unable to get into query mode from current UI viewscreen.')
end

local function is_same_coord(pos1, pos2)
    return pos1.x == pos2.x and pos1.y == pos2.y and pos1.z == pos2.z
end

-- If a tile starts or ends with one of these focus strings, the start and end
-- focus strings can differ without us flagging it as an error.
local exempt_focus_strings = utils.invert({
    'dwarfmode/QueryBuilding/Destroying',
    })

function do_run(zlevel, grid, ctx)
    local stats = ctx.stats
    stats.query_keystrokes = stats.query_keystrokes or
            {label='Keystrokes sent', value=0, always=true}
    stats.query_tiles = stats.query_tiles or
            {label='Tiles modified', value=0}

    quickfort_keycodes.init_keycodes()
    load_aliases(ctx)

    local dry_run = ctx.dry_run
    local saved_mode = df.global.ui.main.mode
    if not dry_run and saved_mode ~= df.ui_sidebar_mode.QueryBuilding then
        switch_ui_sidebar_mode(df.ui_sidebar_mode.QueryBuilding)
    end

    for y, row in pairs(grid) do
        for x, cell_and_text in pairs(row) do
            local pos = xyz2pos(x, y, zlevel)
            local cell, text = cell_and_text.cell, cell_and_text.text
            if not quickfort_set.get_setting('query_unsafe') and
                    not is_queryable_tile(pos) then
                print(string.format(
                        'no building at coordinates (%d, %d, %d); skipping ' ..
                        'text in spreadsheet cell %s: "%s"',
                        pos.x, pos.y, pos.z, cell, text))
                goto continue
            end
            log('applying spreadsheet cell %s with text "%s" to map ' ..
                'coordinates (%d, %d, %d)', cell, text, pos.x, pos.y, pos.z)
            local tokens = quickfort_aliases.expand_aliases(text)
            if not dry_run then quickfort_map.move_cursor(pos) end
            local focus_string = dfhack.gui.getCurFocus(true)
            local modifiers = {} -- tracks ctrl, shift, and alt modifiers
            for _,token in ipairs(tokens) do
                if handle_modifiers(token, modifiers) then goto continue end
                local kcodes = quickfort_keycodes.get_keycodes(token, modifiers)
                if not kcodes then
                    qerror(string.format(
                            'unknown alias or keycode: "%s"', token))
                end
                if not dry_run then
                    gui.simulateInput(dfhack.gui.getCurViewscreen(true), kcodes)
                end
                modifiers = {}
                stats.query_keystrokes.value = stats.query_keystrokes.value + 1
                ::continue::
            end
            -- sanity checks for common blueprint mistakes
            if not dry_run
                    and not quickfort_set.get_setting('query_unsafe') then
                local cursor = guidm.getCursorPos()
                if not is_same_coord(pos, cursor) then
                    qerror(string.format(
                        'expected to be at cursor position (%d, %d, %d) on ' ..
                        'screen "%s" but cursor is at (%d, %d, %d); there ' ..
                        'is likely a problem with the blueprint text in ' ..
                        'cell %s: "%s"', pos.x, pos.y, pos.z, focus_string,
                        cursor.x, cursor.y, cursor.z, cell, text))
                end
                local new_focus_string = dfhack.gui.getCurFocus(true)
                local is_exempt = exempt_focus_strings[focus_string] or
                        exempt_focus_strings[new_focus_string]
                if not is_exempt and focus_string ~= new_focus_string then
                    qerror(string.format(
                        'expected to be at cursor position (%d, %d, %d) on ' ..
                        'screen "%s" but screen is "%s"; there is likely a ' ..
                        'problem with the blueprint text in cell %s: "%s" ' ..
                        '(do you need a "^" at the end to escape back to ' ..
                        'the map screen?)', pos.x, pos.y, pos.z, focus_string,
                        new_focus_string, cell, text))
                end
            end
            stats.query_tiles.value = stats.query_tiles.value + 1
            ::continue::
        end
    end

    if not dry_run then
        if saved_mode ~= df.ui_sidebar_mode.QueryBuilding
                and basic_ui_sidebar_modes[saved_mode] then
            switch_ui_sidebar_mode(saved_mode)
        end
        quickfort_map.move_cursor(ctx.cursor)
    end
end

function do_orders()
    log('nothing to do for blueprints in mode: query')
end

function do_undo()
    log('cannot undo blueprints for mode: query')
end
