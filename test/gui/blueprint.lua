config = {
    mode = 'fortress',
}

local b = reqscript('gui/blueprint')
local blueprint = require('plugins.blueprint')
local gui = require('gui')
local guidm = require('gui.dwarfmode')

function test.fail_if_no_map_loaded()
    local mock_is_map_loaded = mock.func(false)
    mock.patch(dfhack, 'isMapLoaded', mock_is_map_loaded,
        function()
            expect.error_match('load a fortress map',
                               function() b.BlueprintUI{}:show() end)
        end)
end

local function send_keys(...)
    local keys = {...}
    for _,key in ipairs(keys) do
        gui.simulateInput(dfhack.gui.getCurViewscreen(true), key)
    end
end

local function load_ui()
    -- remove screen mode switching once gui/blueprint supports it natively
    for i=1,10 do
        if df.global.ui.main.mode == df.ui_sidebar_mode.Default and
                'dwarfmode/Default' == dfhack.gui.getCurFocus(true) then
            send_keys('D_LOOK')
            local view = b.BlueprintUI{}
            view:show()
            return view
        end
        send_keys('LEAVESCREEN')
    end
    error('Unable to get into look mode from current UI viewscreen.')
end

function test.minimal_happy_path()
    local mock_print, mock_run = mock.func(), mock.func({'blueprints/dig.csv'})
    mock.patch({
            {b, 'print', mock_print},
            {blueprint, 'run', mock_run},
        },
        function()
            local view = load_ui()
            expect.eq('dfhack/lua/blueprint', dfhack.gui.getCurFocus(true))
            guidm.setCursorPos({x=10, y=20, z=30})
            send_keys('SELECT') -- set the first cursor position
            expect.table_eq({x=10, y=20, z=30}, view.mark)
            send_keys('CURSOR_RIGHT', 'CURSOR_DOWN', 'CURSOR_DOWN',
                      'CURSOR_UP_Z', 'CURSOR_UP_Z', 'CURSOR_UP_Z')
            send_keys('SELECT') -- set the second cursor position
            expect.eq('running: blueprint 2 3 -4 blueprint --cursor=10,20,33',
                    mock_print.call_args[1][1])
            expect.table_eq({'2', '3', '-4', 'blueprint', '--cursor=10,20,33'},
                            mock_run.call_args[1])
            send_keys('SELECT') -- dismiss the success messagebox
            delay() -- allow the messagebox and view to disappear
            expect.nil_(dfhack.gui.getCurFocus(true):find('^dfhack/'))
        end)
end

function test.cancel_ui()
    local mock_print, mock_run = mock.func(), mock.func()
    mock.patch({
            {b, 'print', mock_print},
            {blueprint, 'run', mock_run},
        },
        function()
            load_ui()
            expect.eq('dfhack/lua/blueprint', dfhack.gui.getCurFocus(true))
            send_keys('LEAVESCREEN')
            expect.nil_(dfhack.gui.getCurFocus(true):find('^dfhack/'))
            expect.eq(0, mock_print.call_count)
            expect.eq(0, mock_run.call_count)
        end)
end

function test.cancel_selection()
    local mock_print, mock_run = mock.func(), mock.func()
    mock.patch({
            {b, 'print', mock_print},
            {blueprint, 'run', mock_run},
        },
        function()
            load_ui()
            expect.eq('dfhack/lua/blueprint', dfhack.gui.getCurFocus(true))
            guidm.setCursorPos({x=10, y=20, z=30})
            send_keys('SELECT') -- set first cursor position
            send_keys('LEAVESCREEN') -- cancel first cursor position
            expect.eq('dfhack/lua/blueprint', dfhack.gui.getCurFocus(true))
            guidm.setCursorPos({x=12, y=24, z=24})
            send_keys('SELECT') -- set first cursor position again
            guidm.setCursorPos({x=11, y=22, z=27})
            send_keys('SELECT') -- set second cursor position
            expect.eq('running: blueprint 2 3 -4 blueprint --cursor=11,22,27',
                    mock_print.call_args[1][1])
            expect.table_eq({'2', '3', '-4', 'blueprint',
                            '--cursor=11,22,27'},
                            mock_run.call_args[1])
            send_keys('SELECT') -- dismiss the success messagebox
            delay() -- allow the messagebox and view to disappear
            expect.nil_(dfhack.gui.getCurFocus(true):find('^dfhack/'))
        end)
end

local screen_width, screen_height = dfhack.screen.getWindowSize()
local SPACE_ASCII = (' '):byte()
local function get_screen_word(screen_pos)
    local str = ''
    for x = screen_pos.x,screen_width do
        local pen = dfhack.screen.readTile(x, screen_pos.y, true)
        if pen.ch == SPACE_ASCII then break end
        str = str .. string.char(pen.ch)
    end
    return str
end

function test.render_labels()
    local view = load_ui()
    view:onRender()
    local action_label = view.subviews[3].subviews[1]
    local action_word_pos = {x=action_label.frame_body.x1+11,
                             y=action_label.frame_body.y1}
    local cancel_label = view.subviews[4]
    local cancel_word_pos = {x=cancel_label.frame_body.x1+5,
                             y=cancel_label.frame_body.y1}
    expect.eq('first', get_screen_word(action_word_pos))
    expect.eq('Back', get_screen_word(cancel_word_pos))
    guidm.setCursorPos({x=10, y=20, z=30})
    send_keys('SELECT')
    view:onRender()
    expect.eq('second', get_screen_word(action_word_pos))
    expect.eq('Cancel', get_screen_word(cancel_word_pos))
    send_keys('LEAVESCREEN') -- cancel selection
    view:onRender()
    expect.eq('first', get_screen_word(action_word_pos))
    expect.eq('Back', get_screen_word(cancel_word_pos))
    send_keys('LEAVESCREEN') -- leave UI
    expect.nil_(dfhack.gui.getCurFocus(true):find('^dfhack/'))
end

local X_ASCII = ('X'):byte()
local function check_overlay(view, mark, cursor)
    guidm.setCursorPos(cursor)
    dfhack.gui.revealInDwarfmodeMap(cursor, true)
    view:onRender()
    local vp = view:getViewport()
    local z = cursor.z
    local upper_left = {x=math.min(mark.x, cursor.x),
                        y=math.min(mark.y, cursor.y),
                        z=z}
    local lower_right = {x=math.max(mark.x, cursor.x),
                         y=math.max(mark.y, cursor.y),
                         z=z}
    -- ensure tiles within boundaries are all 'X' characters and ensure
    -- surrounding tiles do not have 'X' characters
    -- also ensure 'X' characters are COLOR_GREEN except for the cursor position
    for y = upper_left.y-1,lower_right.y+1 do
        for x = upper_left.x-1,lower_right.x+1 do
            local pos = xyz2pos(x, y, z)
            local stile = vp:tileToScreen(pos)
            -- +1 in each dimension to account for screen border
            local pen = dfhack.screen.readTile(stile.x+1, stile.y+1, true)
            local on_border = y == upper_left.y-1 or y == lower_right.y+1 or
                    x == upper_left.x-1 or x == lower_right.x+1
            if on_border then
                if pen.ch == X_ASCII then return false end
            else
                if pen.ch ~= X_ASCII then return false end
                if same_xyz(cursor, pos) ~= (pen.fg ~= COLOR_GREEN) then
                    return false
                end
            end
        end
    end
    return true
end

function test.render_selected()
    mock.patch(gui, 'blink_visible', mock.func(true),
        function()
            local view = load_ui()
            local mark = {x=10, y=20, z=30}
            guidm.setCursorPos(mark)
            send_keys('SELECT')
            expect.true_(check_overlay(view, mark, {x=8, y=18, z=30}),
                         'up_left')
            expect.true_(check_overlay(view, mark, {x=12, y=18, z=30}),
                         'up_right')
            expect.true_(check_overlay(view, mark, {x=8, y=22, z=30}),
                         'down_left')
            expect.true_(check_overlay(view, mark, {x=12, y=22, z=30}),
                         'down_right')
            send_keys('LEAVESCREEN', 'LEAVESCREEN') -- cancel selection and UI
            expect.nil_(dfhack.gui.getCurFocus(true):find('^dfhack/'))
        end)
end

--auto enter and leave cursor-supporting mode

-- clear and reshow ui if gui/blueprint is run while currently shown

-- mouse support for selecting boundary tiles
local function click_mouse_and_test(screenx, screeny, should_mark, comment)
    mock.patch(dfhack.screen, 'getMousePos', mock.func(screenx, screeny),
        function()
            local view = load_ui()
            view:onInput({_MOUSE_L=true})
            if not should_mark then
                expect.nil_(view.mark, comment)
            else
                local expected_mark = {x=df.global.window_x+screenx-1,
                                       y=df.global.window_y+screeny-1,
                                       z=df.global.window_z}
                expect.table_eq(expected_mark, view.mark, comment)
                send_keys('LEAVESCREEN') -- cancel selection
            end
            send_keys('LEAVESCREEN') -- cancel out of UI
        end)
end

function test.set_with_mouse()
    click_mouse_and_test(0, 0)
    click_mouse_and_test(0, 5)
    click_mouse_and_test(5, 0)
    click_mouse_and_test(5, -1)
    click_mouse_and_test(-1, 5)

    click_mouse_and_test(5, 7, true, 'interior tile')

    local screen_width, screen_height = dfhack.screen.getWindowSize()
    click_mouse_and_test(screen_width - 33, 7, true,
                         'just to left of border between map and blueprint gui')
    click_mouse_and_test(screen_width - 32, 7, false,
                         'on border between map and blueprint gui')
    click_mouse_and_test(5, screen_height - 2, true, 'above bottom border')
    click_mouse_and_test(5, screen_height - 1, false, 'on bottom border')
end

-- live status line showing the dimensions of the currently selected area

-- edit widget for setting the blueprint name

-- widgets to configure which blueprint phases to output

-- presetting config values from commandline parameters
