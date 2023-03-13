-- Avoid suspended jobs and creating unreachable jobs
--@module = true
--@enable = true

local json = require('json')
local persist = require('persist-table')
local argparse = require('argparse')
local eventful = require('plugins.eventful')
local repeatUtil = require('repeat-util')
local suspendmanagerUtils = reqscript('internal/suspendmanager/suspendmanager-utils')

local GLOBAL_KEY = 'suspendmanager' -- used for state change hooks and persistence

enabled = enabled or false
prevent_blocking = prevent_blocking == nil and true or prevent_blocking

eventful.enableEvent(eventful.eventType.JOB_INITIATED, 10)
eventful.enableEvent(eventful.eventType.JOB_COMPLETED, 10)

function isEnabled()
    return enabled
end

function preventBlockingEnabled()
    return prevent_blocking
end

local function persist_state()
    persist.GlobalTable[GLOBAL_KEY] = json.encode({
        enabled=enabled,
        prevent_blocking=prevent_blocking,
    })
end

function set_prevent_blocking(enable)
    prevent_blocking = enable
    persist_state()
end

local function run_now()
    suspendmanagerUtils.foreach_construction_job(function(job)
        local shouldBeSuspended, _ = suspendmanagerUtils.shouldBeSuspended(job, prevent_blocking)
        if shouldBeSuspended and not job.flags.suspend then
            suspendmanagerUtils.suspend(job)
        elseif not shouldBeSuspended and job.flags.suspend then
            suspendmanagerUtils.unsuspend(job)
        end
    end)
end

--- @param job job
local function on_job_change(job)
    if prevent_blocking then
        -- Note: This method could be made incremental by taking in account the
        -- changed job
        run_now()
    end
end

local function update_triggers()
    if enabled then
        eventful.onJobInitiated[GLOBAL_KEY] = on_job_change
        eventful.onJobCompleted[GLOBAL_KEY] = on_job_change
        repeatUtil.scheduleEvery(GLOBAL_KEY, 1, "days", run_now)
    else
        eventful.onJobInitiated[GLOBAL_KEY] = nil
        eventful.onJobCompleted[GLOBAL_KEY] = nil
        repeatUtil.cancel(GLOBAL_KEY)
    end
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_MAP_UNLOADED then
        enabled = false
        return
    end

    if sc ~= SC_MAP_LOADED or df.global.gamemode ~= df.game_mode.DWARF then
        return
    end

    local persisted_data = json.decode(persist.GlobalTable[GLOBAL_KEY] or '')
    enabled = (persisted_data or {enabled=false})['enabled']
    prevent_blocking = (persisted_data or {prevent_blocking=true})['prevent_blocking']
    update_triggers()
end

local function main(args)
    if df.global.gamemode ~= df.game_mode.DWARF or not dfhack.isMapLoaded() then
        dfhack.printerr('suspendmanager needs a loaded fortress map to work')
        return
    end

    if dfhack_flags and dfhack_flags.enable then
        args = {dfhack_flags.enable_state and 'enable' or 'disable'}
    end

    local help = false
    local command = argparse.processArgsGetopt(args, {
        {"h", "help", handler=function() help = true end},
        {"b", "preventblocking", handler=function() set_prevent_blocking(true) end},
        {"n", "nopreventblocking", handler=function() set_prevent_blocking(false) end}
        })[1]

    if help or command == "help" then
        print(dfhack.script_help())
        return
    elseif command == "enable" then
        run_now()
        enabled = true
    elseif command == "disable" then
        enabled = false
    elseif command == nil then
        print(string.format("suspendmanager is currently %s", (enabled and "enabled" or "disabled")))
        if prevent_blocking then
            print("It is configured to prevent construction jobs from blocking each others")
        else
            print("It is configured to unsuspend all jobs")
        end
    else
        return
    end

    persist_state()
    update_triggers()
end

if not dfhack_flags.module then
    main({...})
end
