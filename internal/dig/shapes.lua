-- shape definitions for gui/dig
-- modules
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end


local to_pen = dfhack.pen.parse
local PENS = {
    CORNER = { 5, 22 },
    INSIDE = { 1, 2 },
    NORTH = { 1, 1 },
    N_NUB = { 3, 2 },
    S_NUB = { 4, 2 },
    W_NUB = { 3, 1 },
    E_NUB = { 5, 1 },
    NE = { 2, 1 },
    NW = { 0, 1 },
    WEST = { 0, 2 },
    EAST = { 2, 2 },
    SW = { 0, 3 },
    SOUTH = { 1, 3 },
    SE = { 2, 3 },
    VERT_NS = { 3, 3 },
    VERT_EW = { 4, 1 }
}

function getpen(direction)
    return to_pen { ch = 'X', fg = COLOR_GREEN,
        tile = dfhack.screen.findGraphicsTile('CURSORS', direction[1], direction[2]) }
end

Shape = defclass(Shape)
Shape.ATTRS {
    name = "",
    mark_corners = true,
    mark_center = true,
    arr = {},
    has_point_fn = DEFAULT_NIL,
    apply_options_fn = DEFAULT_NIL,
    options = {}

}
function Shape:init()
end

function Shape:update(width, height)
    self.width = width
    self.height = height
    self.arr = {}
    for x = 0, self.width do
        self.arr[x] = {}
        for y = 0, self.height do
            self.arr[x][y] = self:has_point_fn(x, y)
        end
    end
end

function Shape:getPen(x, y)

    if (x == 0 and y == 0) or (x == #self.arr and y == 0) or (x == 0 and y == #self.arr[x]) or
        (x == #self.arr and y == #self.arr[x]) then
        return getpen(PENS.CORNER)
    end

    if not self.arr[x][y] then
        return nil
    end

    local n, w, e, s = false, false, false, false
    if y == 0 or not self.arr[x][y - 1] then n = true end
    if x == 0 or not self.arr[x - 1][y] then w = true end
    if x == #self.arr or not self.arr[x + 1][y] then e = true end
    if y == #self.arr[x] or not self.arr[x][y + 1] then s = true end

    if not n and not w and not e and not s then
        return getpen(PENS.INSIDE)
    elseif n and w and not e and not s then
        return getpen(PENS.NW)
    elseif n and not w and not e and not s then
        return getpen(PENS.NORTH)
    elseif n and e and not w and not s then
        return getpen(PENS.NE)
    elseif not n and w and not e and not s then
        return getpen(PENS.WEST)
    elseif not n and not w and e and not s then
        return getpen(PENS.EAST)
    elseif not n and w and not e and s then
        return getpen(PENS.SW)
    elseif not n and not w and not e and s then
        return getpen(PENS.SOUTH)
    elseif not n and not w and e and s then
        return getpen(PENS.SE)
    elseif n and w and e and not s then
        return getpen(PENS.N_NUB)
    elseif n and not w and e and s then
        return getpen(PENS.E_NUB)
    elseif n and w and not e and s then
        return getpen(PENS.W_NUB)
    elseif not n and w and e and s then
        return getpen(PENS.S_NUB)
    elseif not n and w and e and not s then
        return getpen(PENS.VERT_NS)
    elseif n and not w and not e and s then
        return getpen(PENS.VERT_EW)
    else
        return nil
    end
end

Ellipse = defclass(Ellipse, Shape)
Ellipse.ATTRS = {
    name = "Ellipse",
    has_point_fn = function(self, x, y)
        local center_x, center_y = self.width / 2, self.height / 2
        local point_x, point_y = x - center_x, y - center_y
        local is_inside = (point_x / (self.width / 2)) ^ 2 + (point_y / (self.height / 2)) ^ 2 <= 1
    
        if self.options.hollow.value and is_inside then
            -- Check if all the points surrounding (x, y) are inside the circle
            local all_points_inside = true
            for dx = -self.options.thickness.value, self.options.thickness.value do
                for dy = -self.options.thickness.value, self.options.thickness.value do
                    if dx ~= 0 or dy ~= 0 then
                        local surrounding_x, surrounding_y = x + dx, y + dy
                        local surrounding_point_x, surrounding_point_y = surrounding_x - center_x, surrounding_y - center_y
                        if (surrounding_point_x / (self.width / 2)) ^ 2 + (surrounding_point_y / (self.height / 2)) ^ 2 > 1 then
                            all_points_inside = false
                            break
                        end
                    end
                end
                if not all_points_inside then
                    break
                end
            end
            return not all_points_inside
        else
            return is_inside
        end
    end,
    options = { hollow = { name = "Hollow", type = "bool", value = true },
        thickness = { name = "Thickness", type = "number", value = 2, range = {1,1000}, shows_if = "hollow.value" } }
}

Rectangle = defclass(Rectangle, Shape)
Rectangle.ATTRS = {
    name = "Rectangle",
    has_point_fn = function(self, x, y)
        if self.options.hollow.value == false then
            if (x >= 0 and x <= self.width) and (y >= 0 and y <= self.height) then
                return true
            end
        else
            if (x >= self.options.thickness.value and x <= self.width - self.options.thickness.value) and
                (y >= self.options.thickness.value and y <= self.height - self.options.thickness.value) then
                return false
            else
                return true
            end
        end
        return false
    end,
    options = { hollow = { name = "Hollow", type = "bool", value = true },
        thickness = { name = "Thickness", type = "number", value = 2, dependson = "hollow.value" } }
}
