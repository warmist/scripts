local argparse = require('argparse')

local zmin = 0
local zmax = df.global.world.map.z_count - 1

local function drain()
    local layers = {} --as:bool[]
    local layer_count = 0
    local tile_count = 0

    for _, block in ipairs(df.global.world.map.map_blocks) do
        if not block.flags.has_aquifer then goto continue end
        if block.map_pos.z < zmin or block.map_pos.z > zmax then goto continue end

        block.flags.has_aquifer = false
        block.flags.check_aquifer = false

        for _, row in ipairs(block.designation) do
            for _, tile in ipairs(row) do
                if tile.water_table then
                    tile.water_table = false
                    tile_count = tile_count + 1
                end
            end
        end

        if not layers[block.map_pos.z] then
            layers[block.map_pos.z] = true
            layer_count = layer_count + 1
        end
        ::continue::
    end

    print(('Cleared %d aquifer tile%s in %d layer%s.'):format(
        tile_count, (tile_count ~= 1) and 's' or '', layer_count, (layer_count ~= 1) and 's' or ''))
end

local help = false
local top = 0

local positionals = argparse.processArgsGetopt({...}, {
    {'h', 'help', handler=function() help = true end},
    {'t', 'top', hasArg=true, handler=function(optarg) top = argparse.nonnegativeInt(optarg, 'top') end},
    {'d', 'zdown', handler=function() zmax = df.global.window_z end},
    {'u', 'zup', handler=function() zmin = df.global.window_z end},
    {'z', 'cur-zlevel', handler=function() zmax, zmin = df.global.window_z, df.global.window_z end},
})

if help or positionals[1] == 'help' then
    print(dfhack.script_help())
    return
end

if top > 0 then
    zmax = -1
    for _, block in ipairs(df.global.world.map.map_blocks) do
        if block.flags.has_aquifer and zmax < block.map_pos.z then
            zmax = block.map_pos.z
        end
    end
    zmax = zmax - top
    if zmax < zmin then
        print('No aquifer levels need draining')
        return
    end
end

drain()
