-- shape definitions for gui/dig
--@ module = true

if not dfhack_flags.module then
    qerror("this script cannot be called directly")
end

local to_pen = dfhack.pen.parse
local CURSORS = {
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
    POINT = { 4, 3 },
}

-- return the pen, alter based on if we want to display a corner and a mouse over corner
function make_pen(direction, is_corner, is_mouse_over)
    return to_pen {
        ch = "X",
        fg = COLOR_GREEN,
        tile = dfhack.screen.findGraphicsTile(
            "CURSORS",
            direction[1],
            direction[2] + (is_corner and 6 + (is_mouse_over and 3 or 0) or 0)
        ),
    }
end

-- Base shape class, should not be used directly
Shape = defclass(Shape)
Shape.ATTRS {
    name = "",
    arr = {},
    has_point_fn = DEFAULT_NIL,
    apply_options_fn = DEFAULT_NIL,
    invert = false,
    width = 1,
    height = 1
}
function Shape:update(width, height)
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

-- Return a pen object based on the position of the x,y point within the shape
-- Contains logic to determine which corner/side/etc... icon to draw to create an
-- aesthetically pleasing border for the shape. Unfortunately the code itself
-- very much not aesthetically pleasing but I'm not sure if that can be helped
function Shape:get_pen(x, y, mousePos)
    -- Corners
    local function is_corner(_x, _y)
        return _x == 0 and _y == 0 or _x == self.width and _y == 0 or _x == 0 and _y == self.height or
            _x == self.width and _y == self.height
    end

    local function is_mouse_over(_x, _y, mouse)
        return mouse == nil or (_x == mouse.x and _y == mouse.y)
    end

    local n, w, e, s = false, false, false, false
    if y == 0 or not self.arr[x][y - 1] then n = true end
    if x == 0 or not self.arr[x - 1][y] then w = true end
    if x == #self.arr or not self.arr[x + 1][y] then e = true end
    if y == #self.arr[x] or not self.arr[x][y + 1] then s = true end

    if not n and not w and not e and not s then
        return make_pen(CURSORS.INSIDE, is_corner(x, y), is_mouse_over(x, y, mousePos))
    elseif self.arr[x][y] and n and w and not e and not s then
        return make_pen(CURSORS.NW, is_corner(x, y), is_mouse_over(x, y, mousePos))
    elseif self.arr[x][y] and n and not w and not e and not s then
        return make_pen(CURSORS.NORTH, is_corner(x, y), is_mouse_over(x, y, mousePos))
    elseif self.arr[x][y] and n and e and not w and not s then
        return make_pen(CURSORS.NE, is_corner(x, y), is_mouse_over(x, y, mousePos))
    elseif self.arr[x][y] and not n and w and not e and not s then
        return make_pen(CURSORS.WEST, is_corner(x, y), is_mouse_over(x, y, mousePos))
    elseif self.arr[x][y] and not n and not w and e and not s then
        return make_pen(CURSORS.EAST, is_corner(x, y), is_mouse_over(x, y, mousePos))
    elseif self.arr[x][y] and not n and w and not e and s then
        return make_pen(CURSORS.SW, is_corner(x, y), is_mouse_over(x, y, mousePos))
    elseif self.arr[x][y] and not n and not w and not e and s then
        return make_pen(CURSORS.SOUTH, is_corner(x, y), is_mouse_over(x, y, mousePos))
    elseif self.arr[x][y] and not n and not w and e and s then
        return make_pen(CURSORS.SE, is_corner(x, y), is_mouse_over(x, y, mousePos))
    elseif self.arr[x][y] and n and w and e and not s then
        return make_pen(CURSORS.N_NUB, is_corner(x, y), is_mouse_over(x, y, mousePos))
    elseif self.arr[x][y] and n and not w and e and s then
        return make_pen(CURSORS.E_NUB, is_corner(x, y), is_mouse_over(x, y, mousePos))
    elseif self.arr[x][y] and n and w and not e and s then
        return make_pen(CURSORS.W_NUB, is_corner(x, y), is_mouse_over(x, y, mousePos))
    elseif self.arr[x][y] and not n and w and e and s then
        return make_pen(CURSORS.S_NUB, is_corner(x, y), is_mouse_over(x, y, mousePos))
    elseif self.arr[x][y] and not n and w and e and not s then
        return make_pen(CURSORS.VERT_NS, is_corner(x, y), is_mouse_over(x, y, mousePos))
    elseif self.arr[x][y] and n and not w and not e and s then
        return make_pen(CURSORS.VERT_EW, is_corner(x, y), is_mouse_over(x, y, mousePos))
    elseif self.arr[x][y] and n and w and e and s then
        return make_pen(CURSORS.POINT, is_corner(x, y), is_mouse_over(x, y, mousePos))
    elseif is_corner(x, y) and not self.arr[x][y] then
        return make_pen(CURSORS.INSIDE, is_corner(x, y), is_mouse_over(x, y, mousePos))
    else
        return nil
    end
end

-- Shape definitions
-- All should have a string name, and a function has_point_fn(self, x, y) which returns true or false based
-- on if the x,y point is within the shape
-- Also options can be defined in a table, see existing shapes for example

Ellipse = defclass(Ellipse, Shape)
Ellipse.ATTRS = {
    name = "Ellipse",
    has_point_fn = function(self, x, y)
        local center_x, center_y = self.width / 2, self.height / 2
        local point_x, point_y = x - center_x, y - center_y
        local is_inside =
        (point_x / (self.width / 2)) ^ 2 + (point_y / (self.height / 2)) ^ 2 <= 1

        if self.options.hollow.value and is_inside then
            local all_points_inside = true
            for dx = -self.options.thickness.value, self.options.thickness.value do
                for dy = -self.options.thickness.value, self.options.thickness.value do
                    if dx ~= 0 or dy ~= 0 then
                        local surrounding_x, surrounding_y = x + dx, y + dy
                        local surrounding_point_x, surrounding_point_y =
                        surrounding_x - center_x,
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
    options = {
        hollow = {
            name = "Hollow",
            type = "bool",
            value = false,
            key = "CUSTOM_H",
        },
        thickness = {
            name = "Thickness",
            type = "plusminus",
            value = 2,
            enabled = { "hollow", true },
            min = 1,
            max = function(shape) if not shape.height or not shape.width then
                      return nil
                  else
                      return math.ceil(math.min(shape.height , shape.width) / 2)

                  end
            end,
            keys = { "CUSTOM_T", "CUSTOM_SHIFT_T" },
        },
    },
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
    options = {
        hollow = {
            name = "Hollow",
            type = "bool",
            value = false,
            key = "CUSTOM_H",
        },
        thickness = {
            name = "Thickness",
            type = "plusminus",
            value = 2,
            enabled = { "hollow", true },
            min = 1,
            max = function(shape) if not shape.height or not shape.width then
                      return nil
                  else
                      return math.ceil(math.min(shape.height , shape.width) / 2)
                  end
            end,
            keys = { "CUSTOM_T", "CUSTOM_SHIFT_T" },
        },
    },
}

Rows = defclass(Rows, Shape)
Rows.ATTRS = {
    name = "Rows",
    has_point_fn = function(self, x, y)
        if self.options.vertical.value and x % self.options.spacing.value == 0 or
            self.options.horizontal.value and y % self.options.spacing.value == 0 then
            return true
        else
            return false
        end
    end,
    options = {
        vertical = {
            name = "Vertical",
            type = "bool",
            value = true,
            key = "CUSTOM_V",
        },
        horizontal = {
            name = "Horizontal",
            type = "bool",
            value = false,
            key = "CUSTOM_H",
        },
        spacing = {
            name = "Spacing",
            type = "plusminus",
            value = 3,
            min = 1,
            keys = { "CUSTOM_T", "CUSTOM_SHIFT_T" },
        },
    },
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
    options = {
        spacing = {
            name = "Spacing",
            type = "plusminus",
            value = 5,
            min = 1,
            keys = { "CUSTOM_T", "CUSTOM_SHIFT_T" },
        },
        reverse = {
            name = "Reverse",
            type = "bool",
            value = false,
            key = "CUSTOM_R",
        },
    },
}

-- module users can get shapes through this global, shape option values
-- persist in these as long as the module is loaded
-- idk enough lua to know if this is okay to do or not
all_shapes = { Rectangle {}, Ellipse {}, Rows {}, Diag {} }
