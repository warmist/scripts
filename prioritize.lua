-- Boosts the priority of jobs of the selected types
--@module = true
--[====[

prioritize
==========

The prioritize script sets the ``do_now`` flag on all of the specified types of
jobs that are currently ready to be picked up by a dwarf. This will force them
to complete those jobs as soon as possible. This script can also continue to
monitor creation of new jobs and automatically boost the priority of jobs of
the specified types.

This is most useful for ensuring important (but low-priority -- according to DF)
tasks don't get indefinitely ignored in busy forts. The list of monitored job
types is cleared whenever you load a new map, so you can add a section like the
one below to your ``onMapLoad.init`` file to ensure important job types are
always completed promptly in your forts::

    prioritize -a StoreItemInVehicle StoreItemInBag StoreItemInBarrel PullLever
    prioritize -a DestroyBuilding RemoveConstruction RecoverWounded DumpItem
    prioritize -a CleanSelf SlaughterAnimal PrepareRawFish ExtractFromRawFish
    prioritize -a --haul-labor=Food StoreItemInStockpile

Tanning hides is also a time-sensitive task, but it doesn't have a specific job
type associated with it. You can prioritize them via::

   prioritize -a CustomReaction

but this is likely to prioritize other, unrelated jobs as well.

Also see the ``do-job-now`` `tweak` for adding a hotkey to the jobs screen that
can toggle the priority of specific individual jobs and the `do-job-now`
script, which sets the priority of jobs related to the current selected
job/unit/item/building/order.

Usage::

    prioritize [<options>] [<job_type> ...]

Examples:

``prioritize``
    Prints out which job types are being automatically prioritized and how many
    jobs of each type we have prioritized since we started watching them.

``prioritize -j``
    Prints out the list of active job types that you can prioritize right now.

``prioritize ConstructBuilding DestroyBuilding``
    Prioritizes all current building construction and destruction jobs.

``prioritize -a --haul-labor=Food StoreItemInStockpile StoreItemInVehicle``
    Prioritizes all current and future food hauling and vehicle loading jobs.

Options:

:``-a``, ``--add``:
    Prioritize all current and future new jobs of the specified job types.
:``-d``, ``--delete``:
    Stop automatically prioritizing new jobs of the specified job types.
:``-h``, ``--help``:
    Show help text.
:``-j``, ``--jobs``:
    Print out how many jobs of each type there are. This is useful for
    discovering the types of the jobs which you can prioritize right now. If any
    job types are specified, only returns the current count for those types.
:``-l``, ``--haul-labor`` <labor>[,<labor>...]:
    For StoreItemInStockpile jobs, restrict prioritization to the specified
    hauling labor(s). Valid types are: "Stone", "Wood", "Body", "Food",
    "Refuse", "Item", "Furniture", and "Animals". If not specified, defaults to
    all.
:``-q``, ``--quiet``:
    Suppress informational output (error messages are still printed).
:``-r``, ``--registry``:
    Print out the full list of valid job types.
]====]

local argparse = require('argparse')
local eventful = require('plugins.eventful')

-- set of job types that we are watching. maps job_type=number to
-- {num_prioritized=number, unit_labors=map of type to num_prioritized} this
-- needs to be global so we don't lose player-set state when the script is
-- reparsed. Also a getter function that can be mocked out by unit tests.
g_watched_job_matchers = g_watched_job_matchers or {}
function get_watched_job_matchers() return g_watched_job_matchers end

eventful.enableEvent(eventful.eventType.UNLOAD, 1)
eventful.enableEvent(eventful.eventType.JOB_INITIATED, 5)

local function make_job_matcher(unit_labors)
    local matcher = {num_prioritized=0}
    if unit_labors then
        local ul_table = {}
        for _,ul in ipairs(unit_labors) do
            ul_table[ul] = 0
        end
        matcher.hauler_matchers = ul_table
    end
    return matcher
end

local function matches(job_matcher, job)
    if not job_matcher then return false end
    if job_matcher.hauler_matchers then
        return job_matcher.hauler_matchers[job.item_subtype]
    end
    return true
end

local function boost_job_if_matches(job, job_matchers)
    if matches(job_matchers[job.job_type], job) and not job.flags.do_now then
        job.flags.do_now = true
        return true
    end
    return false
end

local function on_new_job(job)
    local watched_job_matchers = get_watched_job_matchers()
    if boost_job_if_matches(job, watched_job_matchers) then
        jm = watched_job_matchers[job.job_type]
        jm.num_prioritized = jm.num_prioritized + 1
        if jm.hauler_matchers then
            local hms = jm.hauler_matchers
            hms[job.item_subtype] = hms[job.item_subtype] + 1
        end
    end
end

local function has_elements(collection)
    for _,_ in pairs(collection) do return true end
    return false
end

local function clear_watched_job_matchers()
    local watched_job_matchers = get_watched_job_matchers()
    for job_type in pairs(watched_job_matchers) do
        watched_job_matchers[job_type] = nil
    end
    eventful.onUnload.prioritize = nil
    eventful.onJobInitiated.prioritize = nil
end

local function update_handlers()
    local watched_job_matchers = get_watched_job_matchers()
    if has_elements(watched_job_matchers) then
        eventful.onUnload.prioritize = clear_watched_job_matchers
        eventful.onJobInitiated.prioritize = on_new_job
    else
        clear_watched_job_matchers()
    end
end

local function get_unit_labor_str(unit_labor)
    if not unit_labor then
        return ''
    end
    local labor_str = df.unit_labor[unit_labor]
    return (' (%s%s)'):format(labor_str:sub(6,6), labor_str:sub(7):lower())
end

local function status()
    local first = true
    local watched_job_matchers = get_watched_job_matchers()
    for k,v in pairs(watched_job_matchers) do
        if first then
            print('Automatically prioritized jobs:')
            first = false
        end
        if v.hauler_matchers then
            for hk,hv in pairs(v.hauler_matchers) do
                print(('%d\t%s%s')
                      :format(hv, df.job_type[k], get_unit_labor_str(hk)))
            end
        else
            print(('%d\t%s'):format(v.num_prioritized, df.job_type[k]))
        end
    end
    if first then print('Not automatically prioritizing any jobs.') end
end

-- encapsulate this in a function so unit tests can mock it out
function get_postings()
    return df.global.world.jobs.postings
end

local function for_all_live_postings(cb)
    for _,posting in ipairs(get_postings()) do
        if posting.job and not posting.flags.dead then
            cb(posting)
        end
    end
end

local function boost(job_matchers, opts)
    local count = 0
    for_all_live_postings(
        function(posting)
            if boost_job_if_matches(posting.job, job_matchers) then
                count = count + 1
            end
        end)
    if not opts.quiet then
        print(('Prioritized %d job%s.'):format(count, count == 1 and '' or 's'))
    end
end

local function print_add_message(job_type, unit_labor)
    local ul_str = get_unit_labor_str(unit_labor)
    print(('Automatically prioritizing future jobs of type: %s%s')
          :format(df.job_type[job_type], ul_str))
end

local function print_skip_add_message(job_type, unit_labor)
    local ul_str = get_unit_labor_str(unit_labor)
    print(('Skipping already-watched type: %s%s')
          :format(df.job_type[job_type], ul_str))
end

local function boost_and_watch(job_matchers, opts)
    local quiet = opts.quiet
    boost(job_matchers, opts)
    local watched_job_matchers = get_watched_job_matchers()
    for job_type,job_matcher in pairs(job_matchers) do
        local wjm = watched_job_matchers[job_type]
        if job_type == df.job_type.StoreItemInStockpile then
            if not wjm then
                watched_job_matchers[job_type] = job_matcher
                if not quiet then
                    local hms = job_matcher.hauler_matchers
                    if not hms then
                        print_add_message(job_type)
                    else
                        for ul in pairs(hms) do
                            print_add_message(job_type, ul)
                        end
                    end
                end
            else
                if not wjm.hauler_matchers
                        and not job_matcher.hauler_matchers then
                    if not quiet then
                        print_skip_add_message(job_type)
                    end
                elseif not wjm.hauler_matchers then
                    for ul in pairs(job_matcher.hauler_matchers) do
                        if not quiet then
                            print_skip_add_message(job_type, ul)
                        end
                    end
                elseif not job_matcher.hauler_matchers then
                    if not quiet then
                        print_add_message(job_type)
                    end
                    wjm.hauler_matchers = nil
                else
                    for ul in pairs(job_matcher.hauler_matchers) do
                        if wjm.hauler_matchers[ul] then
                            if not quiet then
                                print_skip_add_message(job_type, ul)
                            end
                        else
                            wjm.hauler_matchers[ul] = 0
                            if not quiet then
                                print_add_message(job_type, ul)
                            end
                        end
                    end
                end
            end
        elseif wjm then
            if not quiet then
                print_skip_add_message(job_type)
            end
        else
            watched_job_matchers[job_type] = job_matcher
            if not quiet then
                print_add_message(job_type)
            end
        end
    end
    update_handlers()
end

local function print_del_message(job_type, unit_labor)
    local ul_str = get_unit_labor_str(unit_labor)
    print(('No longer automatically prioritizing jobs of type: %s%s')
          :format(df.job_type[job_type], ul_str))
end

local function print_skip_del_message(job_type, unit_labor)
    local ul_str = get_unit_labor_str(unit_labor)
    print(('Skipping unwatched type: %s%s')
          :format(df.job_type[job_type], ul_str))
end

local function remove_watch(job_matchers, opts)
    local quiet = opts.quiet
    local watched_job_matchers = get_watched_job_matchers()
    for job_type,job_matcher in pairs(job_matchers) do
        local wjm = watched_job_matchers[job_type]
        if not wjm then
            if not quiet then
                print_skip_del_message(job_type)
            end
        elseif not job_matcher.hauler_matchers then
            watched_job_matchers[job_type] = nil
            if not quiet then
                print_del_message(job_type)
            end
        else
            if not wjm.hauler_matchers then
                wjm.hauler_matchers = {}
                for id,name in ipairs(df.unit_labor) do
                    if name:startswith('HAUL_')
                            and id <= df.unit_labor.HAUL_ANIMALS then
                        wjm.hauler_matchers[id] = 0
                    end
                end
            end
            for ul in pairs(job_matcher.hauler_matchers) do
                if wjm.hauler_matchers[ul] then
                    if not quiet then
                        print_del_message(job_type, ul)
                    end
                    wjm.hauler_matchers[ul] = nil
                else
                    if not quiet then
                        print_skip_del_message(job_type, ul)
                    end
                end
            end
        end
    end
    update_handlers()
end

local function get_job_type_str(job)
    local job_type = job.job_type
    local job_type_str = df.job_type[job_type]
    if job_type ~= df.job_type.StoreItemInStockpile then
        return job_type_str
    end
    return ('%s%s'):format(job_type_str, get_unit_labor_str(job.item_subtype))
end

local function print_current_jobs(job_matchers, opts)
    local job_counts_by_type = {}
    local filtered = has_elements(job_matchers)
    for_all_live_postings(
        function(posting)
            local job = posting.job
            if filtered and not job_matchers[job.job_type] then return end
            local job_type = get_job_type_str(job)
            if not job_counts_by_type[job_type] then
                job_counts_by_type[job_type] = 0
            end
            job_counts_by_type[job_type] = job_counts_by_type[job_type] + 1
        end)
    local first = true
    for k,v in pairs(job_counts_by_type) do
        if first then
            print('Current job counts by type:')
            first = false
        end
        print(('%d\t%s'):format(v, k))
    end
    if first then print('No current jobs.') end
end

local function print_registry()
    print('Valid job types:')
    for k,v in ipairs(df.job_type) do
        if v and df.job_type[v] and v:find('^%u%l') then
            print('  ' .. v)
        end
    end
end

local function parse_commandline(args)
    local opts, action, unit_labors = {}, status, nil
    local positionals = argparse.processArgsGetopt(args, {
            {'a', 'add', handler=function() action = boost_and_watch end},
            {'d', 'delete', handler=function() action = remove_watch end},
            {'h', 'help', handler=function() opts.help = true end},
            {'j', 'jobs', handler=function() action = print_current_jobs end},
            {'l', 'haul-labor', hasArg=true,
             handler=function(arg) unit_labors = argparse.stringList(arg) end},
            {'q', 'quiet', handler=function() opts.quiet = true end},
            {'r', 'registry', handler=function() action = print_registry end},
        })

    if positionals[1] == 'help' then opts.help = true end
    if opts.help then return opts end

    -- validate any specified hauler types and convert the list to ids
    if unit_labors then
        local ul_ids = nil
        for _,ulabor in ipairs(unit_labors) do
            ulabor = 'HAUL_'..ulabor:upper()
            if not df.unit_labor[ulabor] then
                dfhack.printerr(('Ignoring unknown unit labor: "%s". Run' ..
                    ' "prioritize -h" for a list of valid hauling labors.')
                    :format(ulabor))
            else
                ul_ids = ul_ids or {}
                table.insert(ul_ids, df.unit_labor[ulabor])
            end
        end
        unit_labors = ul_ids
    end

    -- validate the specified job types and create matchers
    local job_matchers = {}
    for _,job_type_name in ipairs(positionals) do
        local job_type = df.job_type[job_type_name]
        if not job_type then
            dfhack.printerr(('Ignoring unknown job type: "%s". Run' ..
                ' "prioritize -r" for a list of valid job types.')
                :format(job_type_name))
        else
            local job_matcher = make_job_matcher(
                    job_type == df.job_type.StoreItemInStockpile
                        and unit_labors or nil)
            job_matchers[job_type] = job_matcher
        end
    end
    opts.job_matchers = job_matchers

    if action == status and has_elements(job_matchers) then
        action = boost
    end
    opts.action = action

    return opts
end

if not dfhack_flags.module then
    -- main script
    local opts = parse_commandline({...})
    if opts.help then print(dfhack.script_help()) return end

    opts.action(opts.job_matchers, opts)
end

if dfhack.internal.IN_TEST then
    unit_test_hooks = {
        clear_watched_job_matchers=clear_watched_job_matchers,
        on_new_job=on_new_job,
        status=status,
        boost=boost,
        boost_and_watch=boost_and_watch,
        remove_watch=remove_watch,
        print_current_jobs=print_current_jobs,
        print_registry=print_registry,
        parse_commandline=parse_commandline,
    }
end
