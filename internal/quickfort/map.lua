-- game map-related logic and functions for the quickfort modules
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local guidm = require('gui.dwarfmode')

-- TODO: reload these values when the map changes (or don't cache them)
local map_limits = {
    x={min=0, max=df.global.world.map.x_count-1},
    y={min=0, max=df.global.world.map.y_count-1},
    z={min=0, max=df.global.world.map.z_count-1},
}

function is_within_map_bounds_x(x)
    return x > map_limits.x.min and
            x < map_limits.x.max
end

function is_within_map_bounds_y(y)
    return y > map_limits.y.min and
            y < map_limits.y.max
end

function is_within_map_bounds_z(z)
    return z >= map_limits.z.min and
            z <= map_limits.z.max
end

function is_within_map_bounds(pos)
    return is_within_map_bounds_x(pos.x) and
            is_within_map_bounds_y(pos.y) and
            is_within_map_bounds_z(pos.z)
end

function is_on_map_edge_x(x)
    return x == map_limits.x.min or x == map_limits.x.max
end

function is_on_map_edge_y(y)
    return y == map_limits.y.min or y == map_limits.y.max
end

function is_on_map_edge(pos)
    return is_on_map_edge_x(pos.x) and is_on_map_edge_y(pos.y)
end

function move_cursor(pos)
    guidm.setCursorPos(pos)
    dfhack.gui.refreshSidebar()
end
