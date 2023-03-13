-- Reusable functions for job suspension management
--@ module = true

local utils = require('utils')

local ok, buildingplan = pcall(require, 'plugins.buildingplan')
if not ok then
    buildingplan = nil
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

--- True if there is a construction plan to build an unwalkable tile
---@param pos coord
---@return boolean
local function plansToConstructImpassableAt(pos)
    --- @type building_constructionst|building
    local building = dfhack.buildings.findAtTile(pos)
    if not building then return false end
    if building.flags.exists then
        -- The building is already created
        return false
    end
    return building:isImpassableAtCreation()
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
function isBlocking(job)
    -- Not a construction job, no risk
    if job.job_type ~= df.job_type.ConstructBuilding then return false end

    local building = dfhack.job.getHolder(job)
    --- Not building a blocking construction, no risk
    if not building or not building:isImpassableAtCreation() then return false end

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

--- Return true with a reason if a job should be suspended.
--- It takes in account water flow, buildingplan plugin, and optionally
--- the risk of creating stuck construction buildings
--- @param job job
--- @param accountblocking boolean
function shouldBeSuspended(job, accountblocking)
    if dfhack.maps.getTileFlags(job.pos).flow_size > 1 then
        return true, 'underwater'
    end

    local bld = dfhack.buildings.findAtTile(job.pos)
    if bld and buildingplan and buildingplan.isPlannedBuilding(bld) then
        return true, 'buildingplan'
    end

    if accountblocking and isBlocking(job) then
        return true, 'blocking'
    end
    return false, nil
end
