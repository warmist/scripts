local eventful = require('plugins.eventful')
local prioritize = reqscript('prioritize')
local p = prioritize.unit_test_hooks

-- mock out persistent state and external dependencies
local mock_eventful_onUnload, mock_eventful_onJobInitiated = {}, {}
local mock_watched_job_types = {}
local mock_postings = {}
local function get_mock_postings() return mock_postings end
local function test_wrapper(test_fn)
    mock.patch({{eventful, 'onUnload', {}},
                {eventful, 'onJobInitiated', {}},
                {prioritize, 'watched_job_types', mock_watched_job_types},
                {prioritize, 'get_postings', get_mock_postings}},
               test_fn)
    mock_eventful_onUnload, mock_eventful_onJobInitiated = {}, {}
    mock_watched_job_types = {}
    mock_postings = {}
end
config.wrapper = test_wrapper

local DIG, EAT, REST = df.job_type.Dig, df.job_type.Eat, df.job_type.Rest
function test.print_current_jobs()
    local mock_print = mock.func()
    mock.patch(prioritize, 'print', mock_print, function()
            p.print_current_jobs({})
            expect.eq(1, mock_print.call_count)
            expect.eq('No current jobs.', mock_print.call_args[1][1])
        end)

    mock_postings = {{job={job_type=DIG}, flags={}},
                     {job={job_type=DIG}, flags={}},
                     {job={job_type=EAT}, flags={dead=true}},
                     {job={job_type=EAT}, flags={}},
                     {job={job_type=REST}, flags={dead=true}}}
    mock_print = mock.func()
    mock.patch(prioritize, 'print', mock_print, function()
            p.print_current_jobs({})
            expect.eq('Current job counts by type:', mock_print.call_args[1][1])
            local result = {}
            for i,v in ipairs(mock_print.call_args) do
                if i == 1 then goto continue end
                local _,_,num,job_type = v[1]:find('(%d+)%s+(%S+)')
                expect.ne(nil, num)
                expect.nil_(result[job_type])
                result[job_type] = num
                ::continue::
            end
            expect.table_eq({[df.job_type[DIG]]='2', [df.job_type[EAT]]='1'},
                            result)
        end)

    mock_print = mock.func()
    mock.patch(prioritize, 'print', mock_print, function()
            p.print_current_jobs({[EAT]=true})
            expect.eq('Current job counts by type:', mock_print.call_args[1][1])
            local result = {}
            for i,v in ipairs(mock_print.call_args) do
                if i == 1 then goto continue end
                local _,_,num,job_type = v[1]:find('(%d+)%s+(%S+)')
                expect.ne(nil, num)
                expect.nil_(result[job_type])
                result[job_type] = num
                ::continue::
            end
            expect.table_eq({[df.job_type[EAT]]='1'}, result)
        end)
end

function test.print_registry()
    local mock_print = mock.func()
    mock.patch(prioritize, 'print', mock_print, function()
            p.print_registry()
            expect.lt(0, mock_print.call_count)
            for i,v in ipairs(mock_print.call_args) do
                local out = v[1]:trim()
                if i == 1 then
                    expect.eq('Valid job types:', out)
                    goto continue
                end
                expect.ne('nil', tostring(out))
                expect.true_(out:find('^%u%l'))
                expect.ne('NONE', out)
                ::continue::
            end
        end)
end

function test.parse_commandline()
    expect.table_eq({help=true}, p.parse_commandline{'help'})
    expect.table_eq({help=true}, p.parse_commandline{'-h'})
    expect.table_eq({help=true}, p.parse_commandline{'--help'})

    expect.table_eq({action=p.status, job_types={}}, p.parse_commandline{})
    expect.table_eq({action=p.boost, job_types={[df.job_type['Suture']]=true}},
                    p.parse_commandline{'Suture'})
    expect.printerr_match('Ignoring unknown job type',
        function()
            expect.table_eq({action=p.status, job_types={}},
                            p.parse_commandline{'XSutureX'})
        end)
    expect.printerr_match('Ignoring unknown job type',
        function()
            expect.table_eq({action=p.boost,
                             job_types={[df.job_type['Suture']]=true}},
                            p.parse_commandline{'XSutureX', 'Suture'})
        end)

    expect.table_eq({action=p.status, job_types={}, quiet=true},
                    p.parse_commandline{'-q'})
    expect.table_eq({action=p.status, job_types={}, quiet=true},
                    p.parse_commandline{'--quiet'})

    expect.table_eq({action=p.boost_and_watch,
                     job_types={[df.job_type['Suture']]=true}},
                    p.parse_commandline{'-a', 'Suture'})
    expect.table_eq({action=p.boost_and_watch,
                     job_types={[df.job_type['Suture']]=true}},
                    p.parse_commandline{'--add', 'Suture'})

    expect.table_eq({action=p.remove_watch,
                     job_types={[df.job_type['Suture']]=true}},
                    p.parse_commandline{'-d', 'Suture'})
    expect.table_eq({action=p.remove_watch,
                     job_types={[df.job_type['Suture']]=true}},
                    p.parse_commandline{'--delete', 'Suture'})

    expect.table_eq({action=p.print_current_jobs, job_types={}},
                    p.parse_commandline{'-j'})
    expect.table_eq({action=p.print_current_jobs,
                     job_types={[df.job_type['Suture']]=true}},
                    p.parse_commandline{'-j', 'Suture'})
    expect.table_eq({action=p.print_current_jobs,
                     job_types={[df.job_type['Suture']]=true}},
                    p.parse_commandline{'--jobs', 'Suture'})

    expect.table_eq({action=p.print_registry, job_types={}},
                    p.parse_commandline{'-r'})
    expect.table_eq({action=p.print_registry, job_types={}},
                    p.parse_commandline{'--registry'})
end
