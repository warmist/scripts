local common = reqscript('internal/quickfort/common')

function test.module()
    expect.error_match(
        'this script cannot be called directly',
        function() dfhack.run_script('internal/quickfort/common') end)
end

function test.settings()
    for _,v in pairs(common.settings) do
        expect.ne(v.value, nil)
    end
end

function test.log()
    local mock_print = mock.func()
    mock.patch(
        {
            {common, 'verbose', false},
            {common, 'print', mock_print},
        },
        function()
            common.log('should not log')
            expect.eq(0, mock_print.call_count)
            common.verbose = true
            common.log('should log')
            expect.eq(1, mock_print.call_count)
            common.verbose = false
            common.log('should not log')
            expect.eq(1, mock_print.call_count)
        end)
end

function test.logfn()
    local mock_print = mock.func()
    mock.patch(
        {
            {common, 'verbose', false},
            {common, 'print', mock_print},
        },
        function()
            common.logfn(mock_print, 'should not log')
            expect.eq(0, mock_print.call_count)
            common.verbose = true
            common.logfn(mock_print, 'should log')
            expect.eq(1, mock_print.call_count)
            common.verbose = false
            common.logfn(mock_print, 'should not log')
            expect.eq(1, mock_print.call_count)
        end)
end
