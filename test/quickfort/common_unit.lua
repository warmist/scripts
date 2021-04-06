local common = reqscript('internal/quickfort/common')

function test.module()
    expect.error_match(
        'this script cannot be called directly',
        function() dfhack.run_script('internal/quickfort/common') end)
end

function test.settings()
    for _,v in pairs(common.settings) do
        expect.true_(v.value ~= nil)
    end
end

local mock_print_called = 0
local function mock_print()
    mock_print_called = mock_print_called + 1
end

function test.log()
    local saved_verbose, saved_print = common.verbose, common.print
    common.verbose, common.print = false, mock_print
    dfhack.with_finalize(
        function() common.verbose,common.print = saved_verbose,saved_print end,
        function()
            mock_print_called = 0
            common.log('should not log')
            expect.eq(0, mock_print_called)
            common.verbose = true
            common.log('should log')
            expect.eq(1, mock_print_called)
            common.verbose, mock_print_called = false, 0
            common.log('should not log')
            expect.eq(0, mock_print_called)
        end)
end

function test.logfn()
    saved_verbose, saved_print = common.verbose, common.print
    common.verbose, common.print = false, mock_print
    dfhack.with_finalize(
        function() common.verbose,common.print = saved_verbose,saved_print end,
        function()
            mock_print_called = 0
            common.logfn(mock_print, 'should not log')
            expect.eq(0, mock_print_called)
            common.verbose = true
            common.logfn(mock_print, 'should log')
            expect.eq(1, mock_print_called)
            common.verbose, mock_print_called = false, 0
            common.logfn(mock_print, 'should not log')
            expect.eq(0, mock_print_called)
        end)
end
