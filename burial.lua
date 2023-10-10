-- Allows burial in unowned coffins.
-- Based on Putnam's work (https://gist.github.com/Putnam3145/e7031588f4d9b24b9dda)
local argparse = require('argparse')
local utils = require('utils')

local args = argparse.processArgs({...}, utils.invert{'d', 'p'})

for i, c in pairs(df.global.world.buildings.other.COFFIN) do
    -- Check for existing tomb
    for i, z in pairs(c.relations) do
        if z.type == df.civzone_type.Tomb then
            goto skip
        end
    end
    
    dfhack.buildings.constructBuilding {
        type = df.building_type.Civzone,
        subtype = df.civzone_type.Tomb,
        pos = xyz2pos(c.x1, c.y1, c.z),
        abstract = true,
        fields = {
            is_active = 8,
            zone_settings = {
                tomb = {
                    no_pets = args.d and not args.p,
                    no_citizens = args.p and not args.d,
                },
            },
        },
    }

    ::skip::
end

