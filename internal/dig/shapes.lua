-- shape definitions for gui/dig
-- modules
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local to_pen = dfhack.pen.parse
local PENS = {
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
    VERT_EW = { 4, 1 },
    POINT = { 4, 3 }
}

function getpen(direction, is_corner)
    return to_pen { ch = 'X', fg = COLOR_GREEN,
        tile = dfhack.screen.findGraphicsTile('CURSORS', direction[1], direction[2] + (is_corner and 6 or 0)) }
end

Shape = defclass(Shape)
Shape.ATTRS {
    name = "",
    mark_corners = true,
    mark_center = true,
    arr = {},
    has_point_fn = DEFAULT_NIL,
    apply_options_fn = DEFAULT_NIL,
    invert = false,

}
function Shape:init()
end

function Shape:update(width, height)
    print(self.invert)
    self.width = width
    self.height = height
    self.arr = {}
    for x = 0, self.width do
        self.arr[x] = {}
        for y = 0, self.height do
            local value = self:has_point_fn(x, y)
            if not self.invert then
                self.arr[x][y] = value
            else
                self.arr[x][y] = not value
            end
        end
    end
end

function Shape:getPen(x, y)

    -- Corners
    local function is_corner(_x, _y)
        return _x == 0 and _y == 0
            or _x == self.width and _y == 0
            or _x == 0 and _y == self.height
            or _x == self.width and _y == self.height
    end

    local n, w, e, s = false, false, false, false
    if y == 0 or not self.arr[x][y - 1] then n = true end
    if x == 0 or not self.arr[x - 1][y] then w = true end
    if x == #self.arr or not self.arr[x + 1][y] then e = true end
    if y == #self.arr[x] or not self.arr[x][y + 1] then s = true end


    if not n and not w and not e and not s then
        return getpen(PENS.INSIDE, is_corner(x,y))
    elseif self.arr[x][y] and n and w and not e and not s then
        return getpen(PENS.NW, is_corner(x,y))
    elseif self.arr[x][y] and n and not w and not e and not s then
        return getpen(PENS.NORTH, is_corner(x,y))
    elseif self.arr[x][y] and n and e and not w and not s then
        return getpen(PENS.NE, is_corner(x,y))
    elseif self.arr[x][y] and not n and w and not e and not s then
        return getpen(PENS.WEST, is_corner(x,y))
    elseif self.arr[x][y] and not n and not w and e and not s then
        return getpen(PENS.EAST, is_corner(x,y))
    elseif self.arr[x][y] and not n and w and not e and s then
        return getpen(PENS.SW, is_corner(x,y))
    elseif self.arr[x][y] and not n and not w and not e and s then
        return getpen(PENS.SOUTH, is_corner(x,y))
    elseif self.arr[x][y] and not n and not w and e and s then
        return getpen(PENS.SE, is_corner(x,y))
    elseif self.arr[x][y] and n and w and e and not s then
        return getpen(PENS.N_NUB, is_corner(x,y))
    elseif self.arr[x][y] and n and not w and e and s then
        return getpen(PENS.E_NUB, is_corner(x,y))
    elseif self.arr[x][y] and n and w and not e and s then
        return getpen(PENS.W_NUB, is_corner(x,y))
    elseif self.arr[x][y] and not n and w and e and s then
        return getpen(PENS.S_NUB, is_corner(x,y))
    elseif self.arr[x][y] and not n and w and e and not s then
        return getpen(PENS.VERT_NS, is_corner(x,y))
    elseif self.arr[x][y] and n and not w and not e and s then
        return getpen(PENS.VERT_EW, is_corner(x,y))
    elseif self.arr[x][y] and n and w and e and s then
        return getpen(PENS.POINT, is_corner(x,y))
    elseif is_corner(x,y) and not self.arr[x][y] then
        return getpen(PENS.INSIDE, is_corner(x,y))
    else
        return nil
    end
end

-- Shape definitions

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
                        local surrounding_point_x, surrounding_point_y = surrounding_x - center_x,
                            surrounding_y - center_y
                        if (surrounding_point_x / (self.width / 2)) ^ 2 + (surrounding_point_y / (self.height / 2)) ^ 2 >
                            1 then
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
    options = { hollow = { name = "Hollow", type = "bool", value = false, key = 'CUSTOM_H' },
        thickness = { name = "Thickness", type = "plusminus", value = 2, enabled = {"hollow", true}, min = 1,
            keys = { 'CUSTOM_T', 'CUSTOM_SHIFT_T' } } },
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
    options = { hollow = { name = "Hollow", type = "bool", value = false, key = 'CUSTOM_H' },
        thickness = { name = "Thickness", type = "plusminus", value = 2, enabled = {"hollow", true} , min = 1,
            keys = { 'CUSTOM_T', 'CUSTOM_SHIFT_T' } } },
}

Rows = defclass(Rows, Shape)
Rows.ATTRS = {
    name = "Expl. Rows",
    has_point_fn = function(self, x, y)
        if self.options.vertical.value and x % self.options.spacing.value == 0 or
            self.options.horizontal.value and y % self.options.spacing.value == 0 then
            return true;
        else
            return false
        end
    end,
    options = { vertical = { name = "Vertical", type = "bool", value = true, key = 'CUSTOM_V' },
        horizontal = { name = "Horizontal", type = "bool", value = false, key = 'CUSTOM_H' },
        spacing = { name = "Spacing", type = "plusminus", value = 3, min = 1,
            keys = { 'CUSTOM_T', 'CUSTOM_SHIFT_T' } } },
}

Diag = defclass(Diag, Shape)
Diag.ATTRS = {
    name = "Diagonal",
    has_point_fn = function(self, x, y)

        local mult = 1
        if self.options.reverse.value then
            mult = -1
        end

        if (x + mult * y) % self.options.spacing.value == 0 then
            return true
        else
            return false
        end

    end,
    options = { spacing = { name = "Spacing", type = "plusminus", value = 5, min = 1,
        keys = { 'CUSTOM_T', 'CUSTOM_SHIFT_T' }, },
        reverse = { name = "Reverse", type = "bool", value = false, key = 'CUSTOM_R' },
    },
}

-- Line = defclass(Line, Shape)
-- Diag.ATTRS = {
--     name = "Line",
--     has_point_fn = function(self, x, y)
--         local slope = (self.y2 - self.y1) / (self.x2 - self.x1)
--         local y_intercept = self.y1 - slope * self.x1
--         local y_value = slope * x + y_intercept
--         return y_value >= y and y_value <= y + 1
--     end,
-- }

all_shapes = { Rectangle {}, Ellipse {}, Rows {}, Diag {} }
