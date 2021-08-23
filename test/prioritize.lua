local eventful = require('plugins.eventful')
local prioritize = reqscript('prioritize')
local p = prioritize.unit_test_hooks

-- mock out state and external dependencies
local mock_eventful_onUnload, mock_eventful_onJobInitiated = {}, {}
local mock_print = mock.func()
local mock_watched_job_matchers = {}
local function get_mock_watched_job_matchers()
    return mock_watched_job_matchers
end
local mock_postings = {}
local function get_mock_postings() return mock_postings end
local function test_wrapper(test_fn)
    mock.patch({{eventful, 'onUnload', mock_eventful_onUnload},
                {eventful, 'onJobInitiated', mock_eventful_onJobInitiated},
                {prioritize, 'print', mock_print},
                {prioritize, 'get_watched_job_matchers',
                 get_mock_watched_job_matchers},
                {prioritize, 'get_postings', get_mock_postings}},
               test_fn)
    mock_eventful_onUnload, mock_eventful_onJobInitiated = {}, {}
    mock_print = mock.func()
    mock_watched_job_matchers, mock_postings = {}, {}
end
config.wrapper = test_wrapper

local DIG, EAT, REST = df.job_type.Dig, df.job_type.Eat, df.job_type.Rest

function test.status()
    p.status()
    expect.eq(1, mock_print.call_count)
    expect.eq('Not automatically prioritizing any jobs.',
              mock_print.call_args[1][1])

    mock_watched_job_matchers[REST] = {num_prioritized=5}
    p.status()
    expect.eq(3, mock_print.call_count)
    expect.eq('Automatically prioritized jobs:', mock_print.call_args[2][1])
    expect.true_(mock_print.call_args[3][1]:find('Rest'))
end

function test.boost()
    mock_postings = {{job={job_type=DIG, flags={}}, flags={}},
                     {job={job_type=DIG, flags={}}, flags={}},
                     {job={job_type=EAT, flags={}}, flags={dead=true}},
                     {job={job_type=EAT, flags={}}, flags={}},
                     {job={job_type=REST, flags={}}, flags={dead=true}}}
    local expected_postings =
            {{job={job_type=DIG, flags={}}, flags={}},
             {job={job_type=DIG, flags={}}, flags={}},
             {job={job_type=EAT, flags={}}, flags={dead=true}},
             {job={job_type=EAT, flags={do_now=true}}, flags={}},
             {job={job_type=REST, flags={}}, flags={dead=true}}}
    p.boost({[EAT]={num_prioritized=0}}, {})
    expect.eq(1, mock_print.call_count)
    expect.eq('Prioritized 1 job.', mock_print.call_args[1][1])
    expect.table_eq(expected_postings, mock_postings)
end

function test.boost_quiet()
    mock_postings = {{job={job_type=DIG, flags={}}, flags={}},
                     {job={job_type=DIG, flags={}}, flags={}},
                     {job={job_type=EAT, flags={}}, flags={dead=true}},
                     {job={job_type=EAT, flags={}}, flags={}},
                     {job={job_type=REST, flags={}}, flags={dead=true}}}
    local expected_postings =
            {{job={job_type=DIG, flags={}}, flags={}},
             {job={job_type=DIG, flags={}}, flags={}},
             {job={job_type=EAT, flags={}}, flags={dead=true}},
             {job={job_type=EAT, flags={do_now=true}}, flags={}},
             {job={job_type=REST, flags={}}, flags={dead=true}}}
    p.boost({[EAT]={num_prioritized=0}}, {quiet=true})
    expect.eq(0, mock_print.call_count)
    expect.table_eq(expected_postings, mock_postings)
end

function test.boost_and_watch()
    p.boost_and_watch({[DIG]={num_prioritized=0}}, {})
    expect.eq(2, mock_print.call_count)
    expect.true_(mock_print.call_args[1][1]:find('^Prioritized'))
    expect.true_(mock_print.call_args[2][1]:find('^Automatically'))
    expect.table_eq({[DIG]={num_prioritized=0}}, mock_watched_job_matchers)

    p.boost_and_watch({[DIG]={num_prioritized=0}}, {})
    expect.eq(4, mock_print.call_count)
    expect.true_(mock_print.call_args[3][1]:find('^Prioritized'))
    expect.true_(mock_print.call_args[4][1]:find('^Skipping'))
    expect.table_eq({[DIG]={num_prioritized=0}}, mock_watched_job_matchers)
end

function test.boost_and_watch_quiet()
    p.boost_and_watch({[DIG]={num_prioritized=0}}, {quiet=true})
    expect.eq(0, mock_print.call_count)
    expect.table_eq({[DIG]={num_prioritized=0}}, mock_watched_job_matchers)

    p.boost_and_watch({[DIG]={num_prioritized=0}}, {quiet=true})
    expect.eq(0, mock_print.call_count)
    expect.table_eq({[DIG]={num_prioritized=0}}, mock_watched_job_matchers)
end

function test.remove_watch()
    p.remove_watch({[DIG]={num_prioritized=0}}, {})
    expect.eq(1, mock_print.call_count)
    expect.true_(mock_print.call_args[1][1]:find('Skipping unwatched'))
    expect.table_eq({}, mock_watched_job_matchers)

    mock_watched_job_matchers[DIG] = {num_prioritized=0}
    p.remove_watch({[DIG]={num_prioritized=0}}, {})
    expect.eq(2, mock_print.call_count)
    expect.true_(mock_print.call_args[2][1]:find('No longer'))
end

function test.remove_watch_quiet()
    p.remove_watch({[DIG]={num_prioritized=0}}, {quiet=true})
    expect.eq(0, mock_print.call_count)
    expect.table_eq({}, mock_watched_job_matchers)

    mock_watched_job_matchers[DIG] = {num_prioritized=0}
    p.remove_watch({[DIG]={num_prioritized=0}}, {quiet=true})
    expect.eq(0, mock_print.call_count)
    expect.table_eq({}, mock_watched_job_matchers)
end

function test.eventful_hook_lifecycle()
    expect.nil_(mock_eventful_onUnload.prioritize)
    expect.nil_(mock_eventful_onJobInitiated.prioritize)

    p.boost_and_watch({[DIG]={num_prioritized=0}}, {quiet=true})
    expect.table_eq({[DIG]={num_prioritized=0}}, mock_watched_job_matchers)

    expect.eq(p.clear_watched_job_matchers, mock_eventful_onUnload.prioritize)
    expect.eq(p.on_new_job, mock_eventful_onJobInitiated.prioritize)

    p.remove_watch({[DIG]={num_prioritized=0}}, {quiet=true})
    expect.table_eq({}, mock_watched_job_matchers)

    expect.nil_(mock_eventful_onUnload.prioritize)
    expect.nil_(mock_eventful_onJobInitiated.prioritize)
end

function test.eventful_callbacks()
    -- unwatched job
    local job = {job_type=DIG, flags={}}
    local expected = {job_type=DIG, flags={}}
    p.on_new_job(job)
    expect.table_eq(expected, job)

    -- watched job
    local expected = {job_type=DIG, flags={do_now=true}}
    p.boost_and_watch({[DIG]={num_prioritized=0}}, {quiet=true})
    p.on_new_job(job)
    expect.table_eq(expected, job)

    -- map unload
    p.clear_watched_job_matchers()
    expect.table_eq({}, mock_watched_job_matchers)
    expect.nil_(mock_eventful_onUnload.prioritize)
    expect.nil_(mock_eventful_onJobInitiated.prioritize)
end

function test.print_current_jobs_empty()
    p.print_current_jobs({})
    expect.eq(1, mock_print.call_count)
    expect.eq('No current jobs.', mock_print.call_args[1][1])
end

function test.print_current_jobs_full()
    mock_postings = {{job={job_type=DIG}, flags={}},
                     {job={job_type=DIG}, flags={}},
                     {job={job_type=EAT}, flags={dead=true}},
                     {job={job_type=EAT}, flags={}},
                     {job={job_type=REST}, flags={dead=true}}}
    p.print_current_jobs({})
    expect.eq(3, mock_print.call_count)
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
    expect.table_eq({[df.job_type[DIG]]='2', [df.job_type[EAT]]='1'}, result)
end

function test.print_current_jobs_filtered()
    mock_postings = {{job={job_type=DIG}, flags={}},
                     {job={job_type=DIG}, flags={}},
                     {job={job_type=EAT}, flags={dead=true}},
                     {job={job_type=EAT}, flags={}},
                     {job={job_type=REST}, flags={dead=true}}}
    p.print_current_jobs({[EAT]=true})
    expect.eq(2, mock_print.call_count)
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
end

function test.print_registry()
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
end

local SUTURE = df.job_type['Suture']
function test.parse_commandline()
    expect.table_eq({help=true}, p.parse_commandline{'help'})
    expect.table_eq({help=true}, p.parse_commandline{'-h'})
    expect.table_eq({help=true}, p.parse_commandline{'--help'})

    expect.table_eq({action=p.status, job_matchers={}}, p.parse_commandline{})
    expect.table_eq({action=p.boost,
                     job_matchers={[SUTURE]={num_prioritized=0}}},
                    p.parse_commandline{'Suture'})
    expect.printerr_match('Ignoring unknown job type',
        function()
            expect.table_eq({action=p.status, job_matchers={}},
                            p.parse_commandline{'XSutureX'})
        end)
    expect.printerr_match('Ignoring unknown job type',
        function()
            expect.table_eq({action=p.boost,
                             job_matchers={[SUTURE]={num_prioritized=0}}},
                            p.parse_commandline{'XSutureX', 'Suture'})
        end)

    expect.table_eq({action=p.status, job_matchers={}, quiet=true},
                    p.parse_commandline{'-q'})
    expect.table_eq({action=p.status, job_matchers={}, quiet=true},
                    p.parse_commandline{'--quiet'})

    expect.table_eq({action=p.boost_and_watch,
                     job_matchers={[SUTURE]={num_prioritized=0}}},
                    p.parse_commandline{'-a', 'Suture'})
    expect.table_eq({action=p.boost_and_watch,
                     job_matchers={[SUTURE]={num_prioritized=0}}},
                    p.parse_commandline{'--add', 'Suture'})

    expect.table_eq({action=p.remove_watch,
                     job_matchers={[SUTURE]={num_prioritized=0}}},
                    p.parse_commandline{'-d', 'Suture'})
    expect.table_eq({action=p.remove_watch,
                     job_matchers={[SUTURE]={num_prioritized=0}}},
                    p.parse_commandline{'--delete', 'Suture'})

    expect.table_eq({action=p.print_current_jobs, job_matchers={}},
                    p.parse_commandline{'-j'})
    expect.table_eq({action=p.print_current_jobs,
                     job_matchers={[SUTURE]={num_prioritized=0}}},
                    p.parse_commandline{'-j', 'Suture'})
    expect.table_eq({action=p.print_current_jobs,
                     job_matchers={[SUTURE]={num_prioritized=0}}},
                    p.parse_commandline{'--jobs', 'Suture'})

    expect.table_eq({action=p.print_registry, job_matchers={}},
                    p.parse_commandline{'-r'})
    expect.table_eq({action=p.print_registry, job_matchers={}},
                    p.parse_commandline{'--registry'})
end
