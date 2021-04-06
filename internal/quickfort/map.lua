-- game map-related logic and functions for the quickfort modules
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local guidm = require('gui.dwarfmode')

function move_cursor(pos)
    guidm.setCursorPos(pos)
    dfhack.gui.refreshSidebar()
end

MapBoundsChecker = defclass(MapBoundsChecker, nil)
MapBoundsChecker.ATTRS{
    -- if unset, bounds will be initialized with the bounds of the currently
    -- loaded game map. format is: {x=width, y=height, z=depth}
    dims=DEFAULT_NIL
}

function MapBoundsChecker:init()
    self.x_min, self.y_min, self.z_min = 0, 0, 0
    local dims = self.dims or {}
    if not dims or not dims.x or not dims.y or not dims.z then
        dims.x, dims.y, dims.z = df.global.world.map.x_count,
                df.global.world.map.y_count, df.global.world.map.z_count
    end
    self.x_max, self.y_max, self.z_max = dims.x - 1, dims.y - 1, dims.z - 1
end

function MapBoundsChecker:is_within_map_bounds_x(x)
    return x > self.x_min and x < self.x_max
end

function MapBoundsChecker:is_within_map_bounds_y(y)
    return y > self.y_min and y < self.y_max
end

function MapBoundsChecker:is_within_map_bounds_z(z)
    return z >= self.z_min and z <= self.z_max
end

function MapBoundsChecker:is_within_map_bounds(pos)
    return self:is_within_map_bounds_x(pos.x) and
            self:is_within_map_bounds_y(pos.y) and
            self:is_within_map_bounds_z(pos.z)
end

function MapBoundsChecker:is_on_map_edge_x(x)
    return x == self.x_min or x == self.x_max
end

function MapBoundsChecker:is_on_map_edge_y(y)
    return y == self.y_min or y == self.y_max
end

function MapBoundsChecker:is_on_map_edge(pos)
    return self:is_on_map_edge_x(pos.x) and self:is_on_map_edge_y(pos.y)
end

function MapBoundsChecker:is_on_map_x(x)
    return self:is_within_map_bounds_x(x) or self:is_on_map_edge_x(x)
end

function MapBoundsChecker:is_on_map_y(y)
    return self:is_within_map_bounds_y(y) or self:is_on_map_edge_y(y)
end

function MapBoundsChecker:is_on_map_z(z)
    return self:is_within_map_bounds_z(z)
end
