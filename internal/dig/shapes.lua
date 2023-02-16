-- shape definitions for gui/dig
--@ module = true

if not dfhack_flags.module then
    qerror("this script cannot be called directly")
end

-- Base shape class, should not be used directly
Shape = defclass(Shape)
Shape.ATTRS {
    name = "",
    arr = {},
    options = DEFAULT_NIL,
    invert = false,
    width = 1,
    height = 1,
    points = {},
    draw_corners = { ne = true, nw = true, se = true, sw = true },
    offsets = { n = 0, s = 0, e = 0, w = 0 },
    needs_update = true
}

function Shape:transform(min_x, min_y)
    local ret = {}
    local dim_min, dim_max = self:get_true_dims()

    print(string.format("dim_min (%d, %d)", dim_min.x, dim_min.y))

    local x_transform = min_x - dim_min.x
    local y_transform = min_y - dim_min.y

    for x = dim_min.x, dim_max.x do
        ret[x + x_transform] = {}
        for y = dim_min.y, dim_max.y do
            ret[x + x_transform][y + y_transform] = self.arr[x][y]
        end
    end

    return ret
end

function Shape:get_point_dims()

    local min_x = self.points[1].x
    local max_x = self.points[1].x
    local min_y = self.points[1].y
    local max_y = self.points[1].y

    for _, point in ipairs(self.points) do
        min_x = math.min(min_x, point.x)
        max_x = math.max(max_x, point.x)
        min_y = math.min(min_y, point.y)
        max_y = math.max(max_y, point.y)
    end

    return { x = min_x, y = min_y }, { x = max_x, y = max_y }
end

function Shape:get_true_dims()
    local min_x, min_y, max_x, max_y
    for x,_ in pairs(self.arr) do
        for y,_ in pairs(self.arr[x]) do
            if not min_x then
                min_x = x
                max_x = x
                min_y = y
                max_y = y
            else
                min_x = math.min(min_x, x)
                max_x = math.max(max_x, x)
                min_y = math.min(min_y, y)
                max_y = math.max(max_y, y)
            end
        end
    end

    return { x = min_x, y = min_y }, { x = max_x, y = max_y }
end

function Shape:to_string()
    return string.format("height: %d, width %d, offsets {%d, %d, %d, %d}", self.height, self.width, self.offsets.n,
        self.offsets.s, self.offsets.e, self.offsets.w)
end

function Shape:points_to_string(points)
    local points = points == nil and self.points or points
    local output = ""
    local sep = ""
    for _, point in ipairs(points) do
        output = output .. sep .. string.format("(%d, %d)", point.x, point.y)
        sep = ", "
    end

    return output
end

-- Basic update function that loops over a rectangle from top left to bottom right
-- Can be overridden for more complex shapes
function Shape:update(points)

    -- If doesn't need update
    if #self.points == #points and not self.needs_update then
        local same = true
        for i, point in ipairs(self.points) do
            if points[i].x ~= point.x or points[i].y ~= point.y then
                same = false
                break
            end
        end

        if same then return end -- No need to update
    end


    self.points = copyall(points)
    local top_left, bot_right = self:get_point_dims()
    self.arr = {}
    self.height = bot_right.y - top_left.y
    self.width = bot_right.x - top_left.x

    for x = top_left.x, bot_right.x do
        self.arr[x] = {}
        for y = top_left.y, bot_right.y do
            local value = self:has_point(x - top_left.x, y - top_left.y)
            if not self.invert then
                self.arr[x][y] = value
            else
                self.arr[x][y] = not value
            end
        end
    end
end

function Shape:get_point(x, y) if self.arr[x] and self.arr[x][y] then return true else return false end end

function Shape:has_point(x, y)
    -- This class isn't meant to be used directly
    return false
end

-- Shape definitions
-- All should have a string name, and a function has_point(self, x, y) which returns true or false based
-- on if the x,y point is within the shape
-- Also options can be defined in a table, see existing shapes for example

--Ellipse

Ellipse = defclass(Ellipse, Shape)
Ellipse.ATTRS {
    name = "Ellipse",
}

function Ellipse:init()
    self.options = {
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
                    return math.ceil(math.min(shape.height, shape.width) / 2)

                end
            end,
            keys = { "CUSTOM_T", "CUSTOM_SHIFT_T" },
        },
    }
end

function Ellipse:has_point(x, y)
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
end

Rectangle = defclass(Rectangle, Shape)
Rectangle.ATTRS {
    name = "Rectangle",
}

function Rectangle:init()
    self.options = {
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
                    return math.ceil(math.min(shape.height, shape.width) / 2)
                end
            end,
            keys = { "CUSTOM_T", "CUSTOM_SHIFT_T" },
        },
    }
end

function Rectangle:has_point(x, y)
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
end

Rows = defclass(Rows, Shape)
Rows.ATTRS {
    name = "Rows",
}

function Rows:init()
    self.options = {
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
    }
end

function Rows:has_point(x, y)
    if self.options.vertical.value and x % self.options.spacing.value == 0 or
        self.options.horizontal.value and y % self.options.spacing.value == 0 then
        return true
    else
        return false
    end
end

Diag = defclass(Diag, Shape)
Diag.ATTRS {
    name = "Diagonal",
}

function Diag:init()
    self.options = {
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
    }
end

function Diag:has_point(x, y)
    local mult = 1
    if self.options.reverse.value then
        mult = -1
    end

    if (x + mult * y) % self.options.spacing.value == 0 then
        return true
    else
        return false
    end
end

-- module users can get shapes through this global, shape option values
Line = defclass(Line, Shape)
Line.ATTRS {
    name = "Line Segments",
    -- todo extra corners
}

function Line:init()
    self.options = {
        thickness = {
            name = "Thickness",
            type = "plusminus",
            value = 1,
            min = 1,
            max = function(shape) if not shape.height or not shape.width then
                    return nil
                else
                    return math.max(shape.height, shape.width)

                end
            end,
            keys = { "CUSTOM_T", "CUSTOM_SHIFT_T" },
        },
    }
end

function Line:update(points)

    if #self.points == #points and not self.needs_update then
        local same = true
        for i, point in ipairs(self.points) do
            if points[i].x ~= point.x or points[i].y ~= point.y then
                same = false
                break
            end
        end

        if same then return end -- No need to update
    end

    self.points = copyall(points)
    local top_left, bot_right = self:get_point_dims()
    self.arr = {}
    self.height = bot_right.x - top_left.x
    self.width = bot_right.y - top_left.y
    self.offsets = { n = 0, s = 0, e = 0, w = 0 }

    local x0, y0 = self.points[1].x, self.points[1].y
    local x1, y1 = self.points[2].x, self.points[2].y
    local dx = math.abs(x1 - x0)
    local sx = x0 < x1 and 1 or -1
    local dy = -math.abs(y1 - y0)
    local sy = y0 < y1 and 1 or -1
    local err = dx + dy
    local e2

    -- self.offsets = {n = self.options.thickness.value - 1, s = self.options.thickness.value - 1, e = self.options.thickness.value - 1, w = self.options.thickness.value - 1}

    while true do
        self.arr[x0] = self.arr[x0] or {}
        self.arr[x0][y0] = true

        -- Add line thickness
        if (math.abs(dx) > math.abs(dy)) then
            local i = 1
            while i < self.options.thickness.value do
                local offset = math.ceil(i / 2)
                if y0 >= i then
                    if not self.arr[x0] then self.arr[x0] = {} end
                    self.arr[x0][y0 - offset] = true
                end
                i = i + 1
                self.offsets.n = offset

                if y0 + i - 1 <= self.height and self.options.thickness.value > i then
                    if not self.arr[x0] then self.arr[x0] = {} end
                    self.arr[x0][y0 + offset] = true
                    i = i + 1
                    self.offsets.s = offset
                end
            end
        elseif (math.abs(dx) <= math.abs(dy)) then
            local i = 1
            while i < self.options.thickness.value do
                local offset = math.ceil(i / 2)
                if x0 >= i then
                    if not self.arr[x0 - offset] then self.arr[x0 - offset] = {} end
                    self.arr[x0 - offset][y0] = true
                end
                i = i + 1
                self.offsets.w = offset

                if x0 + i - 1 <= self.width and self.options.thickness.value > i then
                    if not self.arr[x0 - offset] then self.arr[x0 - offset] = {} end
                    self.arr[x0 + offset][y0] = true
                    i = i + 1
                    -- print(offset)
                    self.offsets.e = offset
                end
            end
        end

        if x0 == x1 and y0 == y1 then
            break
        end

        e2 = 2 * err

        if e2 >= dy then
            err = err + dy
            x0 = x0 + sx
        end

        if e2 <= dx then
            err = err + dx
            y0 = y0 + sy
        end
    end
end

-- persist in these as long as the module is loaded
-- idk enough lua to know if this is okay to do or not
all_shapes = { Rectangle {}, Ellipse {}, Rows {}, Diag {}, Line {} }
