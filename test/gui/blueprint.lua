config = {
    mode = 'fortress',
}

local b = reqscript('gui/blueprint')
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
    delay()
end

local function load_ui()
    -- remove screen mode switching once gui/blueprint supports it natively
    for i=1,10 do
        if df.global.ui.main.mode == df.ui_sidebar_mode.Default and
                'dwarfmode/Default' == dfhack.gui.getCurFocus(true) then
            send_keys('D_LOOK')
            b.BlueprintUI{}:show()
            delay()
            return
        end
        send_keys('LEAVESCREEN')
    end
    error('Unable to get into look mode from current UI viewscreen.')
end

function test.minimal_happy_path()
    local mock_print, mock_run_command = mock.func(), mock.func()
    mock.patch({
            {b, 'print', mock_print},
            {dfhack, 'run_command', mock_run_command},
            {gui, 'blink_visible', mock.func(true)},
        },
        function()
            load_ui()
            expect.eq('dfhack/lua', dfhack.gui.getCurFocus(true))
            guidm.setCursorPos({x=10, y=20, z=30})
            send_keys('SELECT')
            send_keys('CURSOR_RIGHT', 'CURSOR_DOWN', 'CURSOR_DOWN',
                      'CURSOR_UP_Z', 'CURSOR_UP_Z', 'CURSOR_UP_Z')
            send_keys('SELECT')
            expect.ne('dfhack/lua', dfhack.gui.getCurFocus(true))
            expect.eq('running: blueprint 2 3 -4 blueprint --cursor=10,20,33',
                    mock_print.call_args[1][1])
            expect.table_eq({'blueprint', '2', '3', '-4', 'blueprint',
                            '--cursor=10,20,33'},
                            mock_run_command.call_args[1][1])
        end)
end

function test.cancel_ui()
    local mock_print, mock_run_command = mock.func(), mock.func()
    mock.patch({
            {b, 'print', mock_print},
            {dfhack, 'run_command', mock_run_command},
        },
        function()
            load_ui()
            expect.eq('dfhack/lua', dfhack.gui.getCurFocus(true))
            send_keys('LEAVESCREEN')
            expect.nil_(dfhack.gui.getCurFocus(true):find('^dfhack/'))
            expect.eq(0, mock_print.call_count)
            expect.eq(0, mock_run_command.call_count)
        end)
end

function test.cancel_selection()
    local mock_print, mock_run_command = mock.func(), mock.func()
    mock.patch({
            {b, 'print', mock_print},
            {dfhack, 'run_command', mock_run_command},
        },
        function()
            load_ui()
            expect.eq('dfhack/lua', dfhack.gui.getCurFocus(true))
            guidm.setCursorPos({x=10, y=20, z=30})
            send_keys('SELECT')
            send_keys('LEAVESCREEN')
            expect.eq('dfhack/lua', dfhack.gui.getCurFocus(true))
            guidm.setCursorPos({x=12, y=24, z=24})
            send_keys('SELECT')
            guidm.setCursorPos({x=11, y=22, z=27})
            send_keys('SELECT')
            expect.nil_(dfhack.gui.getCurFocus(true):find('^dfhack/'))
            expect.eq('running: blueprint 2 3 -4 blueprint --cursor=11,22,27',
                    mock_print.call_args[1][1])
            expect.table_eq({'blueprint', '2', '3', '-4', 'blueprint',
                            '--cursor=11,22,27'},
                            mock_run_command.call_args[1][1])
        end)
end
