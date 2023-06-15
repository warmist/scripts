-- Avoid suspended jobs and creating unreachable jobs
--@module = true
--@enable = true

local json = require('json')
local persist = require('persist-table')
local argparse = require('argparse')
local eventful = require('plugins.eventful')
local utils = require('utils')
local repeatUtil = require('repeat-util')
local ok, buildingplan = pcall(require, 'plugins.buildingplan')
if not ok then
    buildingplan = nil
end

local GLOBAL_KEY = 'suspendmanager' -- used for state change hooks and persistence

enabled = enabled or false

eventful.enableEvent(eventful.eventType.JOB_INITIATED, 10)
eventful.enableEvent(eventful.eventType.JOB_COMPLETED, 10)

--- List of reasons for a job to be suspended
---@enum reason
REASON = {
    --- The job is under water and dwarves will suspend the job when starting it
    UNDER_WATER = 1,
    --- The job is planned by buildingplan, but not yet ready to start
    BUILDINGPLAN = 2,
    --- Fuzzy risk detection of jobs blocking each other in shapes like corners
    RISK_BLOCKING = 3,
    --- Building job on top of an erasable designation (smoothing, carving, ...)
    ERASE_DESIGNATION = 4,
    --- Blocks a dead end (either a corridor or on top of a wall)
    DEADEND = 5,
}

REASON_TEXT = {
    [REASON.UNDER_WATER] = 'underwater',
    [REASON.BUILDINGPLAN] = 'planned',
    [REASON.RISK_BLOCKING] = 'blocking',
    [REASON.ERASE_DESIGNATION] = 'designation',
    [REASON.DEADEND] = 'dead end',
}

--- Suspension reasons from an external source
--- SuspendManager does not actively suspend such jobs, but
--- will not unsuspend them
EXTERNAL_REASONS = {
    [REASON.UNDER_WATER]=true,
    [REASON.BUILDINGPLAN]=true,
}

---@class SuspendManager
---@field preventBlocking boolean
---@field suspensions table<integer, reason>
---@field lastAutoRunTick integer
SuspendManager = defclass(SuspendManager)
SuspendManager.ATTRS {
    --- When enabled, suspendmanager also tries to suspend blocking jobs,
    --- when not enabled, it only cares about avoiding unsuspending jobs suspended externally
    preventBlocking = false,

    --- Current job suspensions with their reasons
    suspensions = {},

    --- Last tick where it was run automatically
    lastAutoRunTick = -1,
}

--- SuspendManager instance kept between frames
---@type SuspendManager
Instance = Instance or SuspendManager{preventBlocking=true}

function isEnabled()
    return enabled
end

function preventBlockingEnabled()
    return Instance.preventBlocking
end

local function persist_state()
    persist.GlobalTable[GLOBAL_KEY] = json.encode({
        enabled=enabled,
        prevent_blocking=Instance.preventBlocking,
    })
end

---@param setting string
---@param value string|boolean
function update_setting(setting, value)
    if setting == "preventblocking" then
        if (value == "true" or value == true) then
            Instance.preventBlocking = true
        elseif (value == "false" or value == false) then
            Instance.preventBlocking = false
        else
            qerror(tostring(value) .. " is not a valid value for preventblocking, it must be true or false")
        end
    else
        qerror(setting .. " is not a valid setting.")
    end
    persist_state()
end


--- Suspend a job
---@param job job
function suspend(job)
    job.flags.suspend = true
    job.flags.working = false
    dfhack.job.removeWorker(job, 0)
end

--- Unsuspend a job
---@param job job
function unsuspend(job)
    job.flags.suspend = false
end

--- Loop over all the construction jobs
---@param fn function A function taking a job as argument
function foreach_construction_job(fn)
    for _,job in utils.listpairs(df.global.world.jobs.list) do
        if job.job_type == df.job_type.ConstructBuilding then
            fn(job)
        end
    end
end

local CONSTRUCTION_IMPASSABLE = {
    [df.construction_type.Wall]=true,
    [df.construction_type.Fortification]=true,
}

local BUILDING_IMPASSABLE = {
    [df.building_type.Floodgate]=true,
    [df.building_type.Statue]=true,
    [df.building_type.WindowGlass]=true,
    [df.building_type.WindowGem]=true,
    [df.building_type.GrateWall]=true,
    [df.building_type.BarsVertical]=true,
}

--- Designation job type that are erased if a building is built on top of it
local ERASABLE_DESIGNATION = {
    [df.job_type.CarveTrack]=true,
    [df.job_type.SmoothFloor]=true,
    [df.job_type.DetailFloor]=true,
}

--- Job types that impact suspendmanager
--- Any completed pathable job can impact suspendmanager by allowing or disallowing
--- access to construction job.
--- Any job read by suspendmanager such as smoothing and carving can also impact
--- job suspension, since it suspends construction job on top of it
local FILTER_JOB_TYPES = utils.invert{
    df.job_type.CarveRamp,
    df.job_type.CarveTrack,
    df.job_type.CarveUpDownStaircase,
    df.job_type.CarveUpwardStaircase,
    df.job_type.CarveDownwardStaircase,
    df.job_type.ConstructBuilding,
    df.job_type.DestroyBuilding,
    df.job_type.DetailFloor,
    df.job_type.Dig,
    df.job_type.DigChannel,
    df.job_type.FellTree,
    df.job_type.SmoothFloor,
    df.job_type.RemoveConstruction,
    df.job_type.RemoveStairs,
}

--- Check if a building is blocking once constructed
---@param building building_constructionst|building
---@return boolean
local function isImpassable(building)
    local type = building:getType()
    if type == df.building_type.Construction then
        return CONSTRUCTION_IMPASSABLE[building.type]
    else
        return BUILDING_IMPASSABLE[type]
    end
end

--- If there is a construction plan to build an unwalkable tile, return the building
---@param pos coord
---@return building?
local function plansToConstructImpassableAt(pos)
    --- @type building_constructionst|building
    local building = dfhack.buildings.findAtTile(pos)
    if not building then return nil end
    if not building.flags.exists and isImpassable(building) then
        return building
    end
    return nil
end

--- Check if the tile can be walked on
---@param pos coord
local function walkable(pos)
    local tt = dfhack.maps.getTileType(pos)
    if not tt then
        return false
    end
    local attrs = df.tiletype.attrs[tt]
    local shape_attrs = df.tiletype_shape.attrs[attrs.shape]
    return shape_attrs.walkable
end

--- List neighbour coordinates of a position
---@param pos coord
---@return table<number, coord>
local function neighbours(pos)
    return {
        {x=pos.x-1, y=pos.y, z=pos.z},
        {x=pos.x+1, y=pos.y, z=pos.z},
        {x=pos.x, y=pos.y-1, z=pos.z},
        {x=pos.x, y=pos.y+1, z=pos.z},
    }
end

--- Get the amount of risk a tile is to be blocked
--- -1: There is a nearby walkable area with no plan to build a wall
--- >=0: Surrounded by either unwalkable tiles, or tiles that will be constructed
--- with unwalkable buildings. The value is the number of already unwalkable tiles.
---@param pos coord
local function riskOfStuckConstructionAt(pos)
    local risk = 0
    for _,neighbourPos in pairs(neighbours(pos)) do
        if not walkable(neighbourPos) then
            -- blocked neighbour, increase danger
            risk = risk + 1
        elseif not plansToConstructImpassableAt(neighbourPos) then
            -- walkable neighbour with no plan to build a wall, no danger
            return -1
        end
    end
    return risk
end

--- Return true if this job is at risk of blocking another one
local function riskBlocking(job)
    -- Not a construction job, no risk
    if job.job_type ~= df.job_type.ConstructBuilding then return false end

    local building = dfhack.job.getHolder(job)
    --- Not building a blocking construction, no risk
    if not building or not isImpassable(building) then return false end

    --- job.pos is sometimes off by one, get the building pos
    local pos = {x=building.centerx,y=building.centery,z=building.z}

    --- Get self risk of being blocked
    local risk = riskOfStuckConstructionAt(pos)

    for _,neighbourPos in pairs(neighbours(pos)) do
        if plansToConstructImpassableAt(neighbourPos) and riskOfStuckConstructionAt(neighbourPos) > risk then
            --- This neighbour job is at greater risk of getting stuck
            return true
        end
    end

    return false
end

--- Analyzes the given job, and if it is at a dead end, follow the "corridor" and
--- mark the jobs containing it as dead end blocking jobs
function SuspendManager:suspendDeadend(start_job)
    local building = dfhack.job.getHolder(start_job)
    if not building then return end
    local pos = {x=building.centerx,y=building.centery,z=building.z}

    -- visited building ids of this potential dead end
    local visited = {
        [building.id] = true
    }

    --- Support dead ends of a maximum length of 1000
    for _=0,1000 do
        -- building plan on the way to the exit
        ---@type building?
        local exit = nil
        for _,neighbourPos in pairs(neighbours(pos)) do
            if not walkable(neighbourPos) then
                -- non walkable neighbour, not an exit
                goto continue
            end

            local impassablePlan = plansToConstructImpassableAt(neighbourPos)
            if not impassablePlan then
                -- walkable neighbour with no building scheduled, not in a dead end
                return
            end

            if visited[impassablePlan.id] then
                -- already visited, not an exit
                goto continue
            end

            if exit then
                -- more than one exit, not in a dead end
                return
            end

            -- the building plan is a candidate to exit
            exit = impassablePlan

            ::continue::
        end

        if not exit then return end

        -- exit is the single exit point of this corridor, suspend its construction job
        -- and continue the exploration from its position
        for _,job in ipairs(exit.jobs) do
            if job.job_type == df.job_type.ConstructBuilding then
                self.suspensions[job.id] = REASON.DEADEND
            end
        end
        visited[exit.id] = true
        pos = {x=exit.centerx,y=exit.centery,z=exit.z}
    end
end

--- Return true if the building overlaps with a tile with a designation flag
---@param building building
local function buildingOnDesignation(building)
    local z = building.z
    for x=building.x1,building.x2 do
        for y=building.y1,building.y2 do
            local flags, occupancy = dfhack.maps.getTileFlags(x,y,z)
            if flags.dig ~= df.tile_dig_designation.No or
                flags.smooth > 0 or
                occupancy.carve_track_north or
                occupancy.carve_track_east or
                occupancy.carve_track_south or
                occupancy.carve_track_west
            then
                return true
            end
        end
    end
end

--- Return the reason for suspending a job or nil if it should not be suspended
--- @param job job
--- @return reason?
function SuspendManager:shouldBeSuspended(job)
    local reason = self.suspensions[job.id]
    if reason and EXTERNAL_REASONS[reason] then
        -- don't actively suspend external reasons for suspension
        return nil
    end
    return reason
end

--- Return the reason for keeping a job suspended or nil if it can be unsuspended
--- @param job job
--- @return reason?
function SuspendManager:shouldStaySuspended(job)
    return self.suspensions[job.id]
end

--- Recompute the list of suspended jobs
function SuspendManager:refresh()
    self.suspensions = {}

    for _,job in utils.listpairs(df.global.world.jobs.list) do
        -- External reasons to suspend a job
        if job.job_type == df.job_type.ConstructBuilding then
            if dfhack.maps.getTileFlags(job.pos).flow_size > 1 then
                self.suspensions[job.id]=REASON.UNDER_WATER
            end

            local bld = dfhack.job.getHolder(job)
            if bld and buildingplan and buildingplan.isPlannedBuilding(bld) then
                self.suspensions[job.id]=REASON.BUILDINGPLAN
            end
        end

        if not self.preventBlocking then goto continue end

        -- Internal reasons to suspend a job
        if riskBlocking(job) then
            self.suspensions[job.id]=REASON.RISK_BLOCKING
        end

        -- If this job is a dead end, mark jobs leading to it as dead end
        self:suspendDeadend(job)

        -- First designation protection check: tile with designation flag
        if job.job_type == df.job_type.ConstructBuilding then
            ---@type building
            local building = dfhack.job.getHolder(job)
            if building then
                if buildingOnDesignation(building) then
                    self.suspensions[job.id]=REASON.ERASE_DESIGNATION
                end
            end
        end

        -- Second designation protection check: designation job
        if ERASABLE_DESIGNATION[job.job_type] then
            local building = dfhack.buildings.findAtTile(job.pos)
            if building ~= nil then
                for _,building_job in ipairs(building.jobs) do
                    if building_job.job_type == df.job_type.ConstructBuilding then
                        self.suspensions[building_job.id]=REASON.ERASE_DESIGNATION
                    end
                end
            end
        end

        ::continue::
    end
end

local function run_now()
    Instance:refresh()
    foreach_construction_job(function(job)
        if job.flags.suspend then
            if not Instance:shouldStaySuspended(job) then
                unsuspend(job)
            end
        else
            if Instance:shouldBeSuspended(job) then
                suspend(job)
            end
        end
    end)
end

--- @param job job
local function on_job_change(job)
    local tick = df.global.cur_year_tick
    if Instance.preventBlocking and FILTER_JOB_TYPES[job.job_type] and tick ~= Instance.lastAutoRunTick then
        Instance.lastAutoRunTick = tick
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
    Instance.preventBlocking = (persisted_data or {prevent_blocking=true})['prevent_blocking']
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
    local positionals = argparse.processArgsGetopt(args, {
        {"h", "help", handler=function() help = true end},
    })
    local command = positionals[1]

    if help or command == "help" then
        print(dfhack.script_help())
        return
    elseif command == "enable" then
        run_now()
        enabled = true
    elseif command == "disable" then
        enabled = false
    elseif command == "set" then
        update_setting(positionals[2], positionals[3])
    elseif command == nil then
        print(string.format("suspendmanager is currently %s", (enabled and "enabled" or "disabled")))
        if Instance.preventBlocking then
            print("It is configured to prevent construction jobs from blocking each others")
        else
            print("It is configured to unsuspend all jobs")
        end
    else
        qerror("Unknown command " .. command)
        return
    end

    persist_state()
    update_triggers()
end

if not dfhack_flags.module then
    main({...})
end
