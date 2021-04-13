--Cause floating webs to fall
--By Bumber
--@module = true
--[====[

fix/webs
========
Turns floating webs into projectiles, causing them to fall down to a valid surface
Use ``fix/webs -all`` to turn all webs into projectiles, causing webs to fall out of branches, etc.

]====]
local utils = require "utils"

function fix_webs(air_only)
    if not dfhack.isMapLoaded() then
        qerror("Error: Map not loaded!")
    end
    
    local count = 0
    for i, item in ipairs(df.global.world.items.all) do
        if item:getType() == df.item_type.THREAD and
        item.flags.spider_web and
        item.flags.on_ground and
        not item.flags.in_job then
            local valid_tile = true
            
            if air_only then
                local tt = dfhack.maps.getTileBlock(item.pos).tiletype[item.pos.x%16][item.pos.y%16]
                valid_tile = (tt == df.tiletype.OpenSpace)
            end
            
            if valid_tile then
                local proj = dfhack.items.makeProjectile(item)
                proj.flags.no_impact_destroy = true
                proj.flags.bouncing = true
                proj.flags.piercing = true
                proj.flags.parabolic = true
                proj.flags.unk9 = true
                proj.flags.no_collide = true
                count = count+1
            end
        end
    end
    print(tostring(count).." webs projectilized!")
end

function main(...)
    local validArgs = utils.invert({"all"})
    local args = utils.processArgs({...}, validArgs)
    
    if args.all then
        fix_webs(false)
    else
        fix_webs(true)
    end
end

if not dfhack_flags.module then
    main(...)
end
