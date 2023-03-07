-- Suspend jobs
--@ module = true

-- It can either suspend all jobs, or just jobs that risk blocking others.

local utils = require('utils')
local argparse = require('argparse')

function suspend(job)
    job.flags.suspend = true
    job.flags.working = false
    dfhack.job.removeWorker(job, 0)
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

local function main(args)
    local help, onlyblocking = false, false
    argparse.processArgsGetopt(args, {
        {'h', 'help', handler=function() help = true end},
        {'b', 'onlyblocking', handler=function() onlyblocking = true end},
    })

    if help then
        print(dfhack.script_help())
        return
    end

    for _,job in utils.listpairs(df.global.world.jobs.list) do
        if not onlyblocking or isBlocking(job) then
            suspend(job)
        end
    end
end

if not dfhack_flags.module then
    main({...})
end
