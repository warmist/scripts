-- query-related logic for the quickfort script
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local gui = require('gui')
local quickfort_common = reqscript('internal/quickfort/common')
local log = quickfort_common.log
local quickfort_aliases = reqscript('internal/quickfort/aliases')
local quickfort_keycodes = reqscript('internal/quickfort/keycodes')

local common_aliases_filename = 'hack/data/quickfort/aliases-common.txt'
local user_aliases_filename = 'dfhack-config/quickfort/aliases.txt'

local function load_aliases()
    -- ensure we're starting from a clean alias stack, even if the previous
    -- invocation of this function returned early with an error
    quickfort_aliases.reset_aliases()
    quickfort_aliases.push_aliases_csv_file(common_aliases_filename)
    quickfort_aliases.push_aliases_csv_file(user_aliases_filename)
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

-- send keycodes to exit the current UI sidebar mode and enter another one with
-- the given keycode. we verify before calling this function that we are in a
-- mode that can be exited with one press of ESC.
local function switch_ui_sidebar_mode(mode_keycode)
    gui.simulateInput(dfhack.gui.getCurViewscreen(true), 'LEAVESCREEN')
    gui.simulateInput(dfhack.gui.getCurViewscreen(true), mode_keycode)
end

local valid_ui_sidebar_modes = {
    [df.ui_sidebar_mode.QueryBuilding]='D_BUILDJOB',
    [df.ui_sidebar_mode.LookAround]='D_LOOK',
    [df.ui_sidebar_mode.BuildingItems]='D_BUILDITEM',
    [df.ui_sidebar_mode.Stockpiles]='D_STOCKPILES',
    [df.ui_sidebar_mode.Zones]='D_CIVZONE',
}

function do_run(zlevel, grid, ctx)
    local stats = ctx.stats
    stats.query_keystrokes = stats.query_keystrokes or
            {label='Keystrokes sent', value=0, always=true}
    stats.query_tiles = stats.query_tiles or
            {label='Tiles modified', value=0}

    if not valid_ui_sidebar_modes[df.global.ui.main.mode] then
        qerror('To run a blueprint, you must be in one of the following modes:'
               ..' query (q), look (k), view (t), stockpiles (p), or zones (i)')
    end

    load_aliases()

    local saved_mode = df.global.ui.main.mode
    if saved_mode ~= df.ui_sidebar_mode.QueryBuilding then
        switch_ui_sidebar_mode(
            valid_ui_sidebar_modes[df.ui_sidebar_mode.QueryBuilding])
    end

    for y, row in pairs(grid) do
        for x, cell_and_text in pairs(row) do
            local pos = xyz2pos(x, y, zlevel)
            local cell, text = cell_and_text.cell, cell_and_text.text
            if not quickfort_common.settings['query_unsafe'].value and
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
            quickfort_common.move_cursor(pos)
            local focus_string =
                    dfhack.gui.getFocusString(dfhack.gui.getCurViewscreen(true))
            local modifiers = {} -- tracks ctrl, shift, and alt modifiers
            for _,token in ipairs(tokens) do
                if handle_modifiers(token, modifiers) then goto continue end
                local kcodes = quickfort_keycodes.get_keycodes(token, modifiers)
                if not kcodes then
                    qerror(string.format(
                            'unknown alias or keycode: "%s"', token))
                end
                gui.simulateInput(dfhack.gui.getCurViewscreen(true), kcodes)
                modifiers = {}
                stats.query_keystrokes.value = stats.query_keystrokes.value + 1
                ::continue::
            end
            local new_focus_string =
                    dfhack.gui.getFocusString(dfhack.gui.getCurViewscreen(true))
            if not quickfort_common.settings['query_unsafe'].value and
                    focus_string ~= new_focus_string then
                qerror(string.format(
                    'expected to be back on screen "%s" but screen is "%s"; ' ..
                    'there is likely a problem with the blueprint text in ' ..
                    'cell %s: "%s" (do you need a "^" at the end?)',
                    focus_string, new_focus_string, cell, text))
            end
            stats.query_tiles.value = stats.query_tiles.value + 1
            ::continue::
        end
    end

    if saved_mode ~= df.ui_sidebar_mode.QueryBuilding then
        switch_ui_sidebar_mode(valid_ui_sidebar_modes[saved_mode])
    end
    quickfort_common.move_cursor(ctx.cursor)
end

function do_orders()
    log('nothing to do for blueprints in mode: query')
end

function do_undo()
    log('cannot undo blueprints for mode: query')
end
