-- A GUI front-end for the digging designations
--@ module = false

-- TODOS ====================

-- Must Haves
-----------------------------

-- Should Haves
-----------------------------
-- Keyboard support
-- As the number of shapes and designations grow it might be better to have list menus for them instead of cycle
-- 3D shapes, would allow stuff like spiral staircases/minecart tracks and other neat stuff, probably not too hard
-- Grid view without slowness (can ignore if next TODO is done, since nrmal mining mode has grid view)
--   Lags when drawing the full screen grid on each frame render
-- Integrate with default mining mode for designation type, priority, etc... (possible?)
-- Add warning to stairs if not spanning z levels like vanilla does
-- Figure out how to remove dug stairs with mode (nothing seems to work, include 'dig ramp')
-- 'No overwrite' mode to not overwrite existing designations
-- Smoothing and engraving

-- Nice To Haves
-----------------------------
-- Triangle shapes, more shapes in general, could even do dynamic creation of residential layouts as long as they can be mathematically represented
-- Exploration pattern ladder https://dwarffortresswiki.org/index.php/DF2014:Exploratory_mining#Ladder_Rows
-- Investigate using single quickfort API call when commiting  https://github.com/joelpt/quickfort/blob/master/README.md#area-expansion-syntax

-- Stretch Goals
-----------------------------
-- Shape preview in panel
-- Shape designer in preview panel to draw repeatable shapes i'e' 2x3 room with door

-- END TODOS ================

local gui = require("gui")
local guidm = require("gui.dwarfmode")
local widgets = require("gui.widgets")
local quickfort = reqscript("quickfort")
local shapes = reqscript("internal/dig/shapes")

local tile_attrs = df.tiletype.attrs

local to_pen = dfhack.pen.parse

local function get_dims(pos1, pos2)
    local width, height, depth =
    math.abs(pos1.x - pos2.x) + 1,
        math.abs(pos1.y - pos2.y) + 1,
        math.abs(pos1.z - pos2.z) + 1

    return width, height, depth
end

-- Panel to show the Mouse position/dimensions/etc
-- Stolen from blueprint or quickfort I forget
ActionPanel = defclass(ActionPanel, widgets.ResizingPanel)
ActionPanel.ATTRS {
    get_area_fn = DEFAULT_NIL,
    get_mark1_fn = DEFAULT_NIL,
    get_mark2_fn = DEFAULT_NIL,
    autoarrange_subviews = true,
}

function ActionPanel:init()
    self:addviews {
        widgets.WrappedLabel {
            view_id = "action_label",
            text_to_wrap = self:callback("get_action_text"),
        },
        widgets.WrappedLabel {
            view_id = "selected_area",
            text_to_wrap = self:callback("get_area_text"),
        },
        widgets.WrappedLabel {
            view_id = "mark1_label",
            text_to_wrap = self:callback("get_mark1_text"),
        },
        widgets.WrappedLabel {
            view_id = "mark2_label",
            text_to_wrap = self:callback("get_mark2_text"),
        }
    }
end

function ActionPanel:get_action_text()
    local text = ""
    if self.get_mark1_fn() and not self.parent_view.mark2  then
        text = "Place the next corner"
    elseif not self.get_mark1_fn() then
        text = "Place the first corner"
    elseif not self.parent_view.placing_extra.active and self.parent_view.prev_center == nil then
        text = "Select any draggable points"
    elseif self.parent_view.placing_extra.active then
        text = "Place any extra points"
    elseif self.parent_view.prev_center ~= nil then
        text = "Place the center point"
    else
        text = "Select any draggable points"
    end
    return text .. " with the mouse. Use right-click to dismiss points in order."
end

function ActionPanel:get_area_text()
    local mark1 = self.get_mark1_fn()

    local label = "Area: "

    if not mark1 then
        return label .. "N/A"
    end

    local mark2 = self.get_mark2_fn()

    local width, height, depth = get_dims(mark1, mark2) -- Replace
    local tiles = width * height * depth
    local plural = tiles > 1 and "s" or ""
    return label .. ("%dx%dx%d (%d tile%s)"):format(
        width,
        height,
        depth,
        tiles,
        plural
    )
end

function ActionPanel:get_mark1_text()
    local mark1 = self.get_mark1_fn()

    local label = "Mark 1: "

    if not mark1 then
        return label .. "Not set"
    end

    return label .. ("%d, %d, %d"):format(
        mark1.x,
        mark1.y,
        mark1.z
    )
end

function ActionPanel:get_mark2_text()
    local mark2 = self.get_mark2_fn()

    local label = "Mark 2: "

    if not mark2 then
        return label .. "Not set"
    end

    return label .. ("%d, %d, %d"):format(
        mark2.x,
        mark2.y,
        mark2.z
    )
end

-- Generic options not specific to shapes
GenericOptionsPanel = defclass(GenericOptionsPanel, widgets.ResizingPanel)
GenericOptionsPanel.ATTRS {
    name = DEFAULT_NIL,
    autoarrange_subviews = true,
    dig_panel = DEFAULT_NIL,
    on_layout_change = DEFAULT_NIL,
}

function GenericOptionsPanel:init()
    local options = {}
    for i, shape in pairs(shapes.all_shapes) do
        options[#options + 1] = {
            label = shape.name,
            value = i,
        }
    end

    local stair_options = {
        {
            label = "Auto",
            value = "auto",
        },
        {
            label = "Up/Down",
            value = "i",
        },
        {
            label = "Up",
            value = "u",
        },
        {
            label = "Down",
            value = "j",
        },
    }
    self:addviews {
        widgets.WrappedLabel {
            view_id = "settings_label",
            text_to_wrap = "General Settings:\n",
        },
        widgets.CycleHotkeyLabel {
            view_id = "shape_name",
            key = "CUSTOM_Z",
            key_back = "CUSTOM_SHIFT_Z",
            label = "Shape: ",
            label_width = 8,
            active = true,
            enabled = true,
            options = options,
            disabled = false,
            show_tooltip = true,
            on_change = self:callback("change_shape"),
        },
        widgets.ToggleHotkeyLabel {
            view_id = "invert_designation_label",
            key = "CUSTOM_I",
            label = "Invert: ",
            label_width = 8,
            active = true,
            enabled = function()
                return self.dig_panel.shape.invertable == true
            end,
            show_tooltip = true,
            initial_option = false,
            on_change = function(new, old)
                self.dig_panel.shape.invert = new
                self.dig_panel.needs_update = true
            end,
        },
        widgets.HotkeyLabel {
            view_id = "shape_place_extra_point",
            key = "CUSTOM_V",
            label = function()
                local msg = "Place extra point: "
                if #self.dig_panel.extra_points < #self.dig_panel.shape.extra_points then
                    return msg .. self.dig_panel.shape.extra_points[#self.dig_panel.extra_points + 1].label
                end

                return msg .. "N/A"
            end,
            active = true,
            visible = function() return self.dig_panel.shape ~= nil and #self.dig_panel.shape.extra_points > 0 end,
            enabled = function()
                if self.dig_panel.shape ~= nil then
                    return #self.dig_panel.extra_points < #self.dig_panel.shape.extra_points
                end

                return false
            end,
            show_tooltip = true,
            on_activate = function()
                if self.dig_panel.mark1 and self.dig_panel.mark2 then
                    self.dig_panel.placing_extra.active = true
                    self.dig_panel.placing_extra.index = #self.dig_panel.extra_points + 1
                elseif self.dig_panel.mark1 and not self.dig_panel.mark2 then
                    local mouse_pos = dfhack.gui.getMousePos()
                    self.dig_panel.extra_points[#self.dig_panel.extra_points + 1] = { x = mouse_pos.x, y = mouse_pos.y }
                end
                self.dig_panel.needs_update = true
            end,
        },
        widgets.HotkeyLabel {
            view_id = "shape_clear_all_points",
            key = "CUSTOM_X",
            label = "Clear all points",
            active = true,
            enabled = function()
                if self.dig_panel.mark1 or self.dig_panel.mark2 then return true
                elseif self.dig_panel.shape ~= nil then
                    if #self.dig_panel.extra_points < #self.dig_panel.shape.extra_points then
                        return true
                    end
                end

                return false
            end,
            disabled = false,
            show_tooltip = true,
            on_activate = function()
                self.dig_panel.mark1 = nil
                self.dig_panel.mark2 = nil
                self.dig_panel.extra_points = {}
                self.dig_panel.prev_center = nil
                self.dig_panel.needs_update = true
            end,
        },
        widgets.HotkeyLabel {
            view_id = "shape_clear_extra_points",
            key = "CUSTOM_SHIFT_X",
            label = "Clear extra points",
            active = true,
            enabled = function()
                if self.dig_panel.shape ~= nil then
                    if #self.dig_panel.extra_points > 0 then
                        return true
                    end
                end

                return false
            end,
            disabled = false,
            visible = function() return self.dig_panel.shape ~= nil and #self.dig_panel.shape.extra_points > 0 end,
            show_tooltip = true,
            on_activate = function()
                if self.dig_panel.shape ~= nil then
                    self.dig_panel.extra_points = {}
                    self.dig_panel.prev_center = nil
                    self.dig_panel.placing_extra.active = false
                    self.dig_panel.placing_extra.index = 0
                    self.dig_panel:updateLayout()
                    self.dig_panel.needs_update = true
                end
            end,
        },
        widgets.CycleHotkeyLabel {
            view_id = "mode_name",
            key = "CUSTOM_F",
            key_back = "CUSTOM_SHIFT_F",
            label = "Mode: ",
            label_width = 8,
            active = true,
            enabled = true,
            options = {
                {
                    label = "Dig",
                    value = "d",
                },
                {
                    label = "Channel",
                    value = "h",
                },
                {
                    label = "Remove Designation",
                    value = "x",
                },
                {
                    label = "Remove Ramps",
                    value = "z",
                },
                {
                    label = "Remove Constructions",
                    value = "n",
                },
                {
                    label = "Stairs",
                    value = "i",
                },
                {
                    label = "Ramp",
                    value = "r",
                },
                {
                    label = "Smooth",
                    value = "s",
                },
                {
                    label = "Engrave",
                    value = "e",
                }
            },
            disabled = false,
            show_tooltip = true,
            on_change = function(new, old) self.dig_panel:updateLayout() end,
        },
        widgets.CycleHotkeyLabel {
            view_id = "stairs_top_subtype",
            key = "CUSTOM_R",
            label = "Top Stair Type: ",
            active = true,
            enabled = true,
            visible = function() return self.dig_panel.subviews.mode_name:getOptionValue() == "i" end,
            options = stair_options,
        },
        widgets.CycleHotkeyLabel {
            view_id = "stairs_middle_subtype",
            key = "CUSTOM_G",
            label = "Middle Stair Type: ",
            active = true,
            enabled = true,
            visible = function() return self.dig_panel.subviews.mode_name:getOptionValue() == "i" end,
            options = stair_options,
        },
        widgets.CycleHotkeyLabel {
            view_id = "stairs_bottom_subtype",
            key = "CUSTOM_B",
            label = "Bottom Stair Type: ",
            active = true,
            enabled = true,
            visible = function() return self.dig_panel.subviews.mode_name:getOptionValue() == "i" end,
            options = stair_options,
        },
        widgets.WrappedLabel {
            view_id = "shape_prio_label",
            text_to_wrap = function()
                return "Priority: " .. tostring(self.dig_panel.prio)
            end,
        },
        widgets.HotkeyLabel {
            view_id = "shape_option_priority_minus",
            key = "CUSTOM_P",
            label = "Increase Priority",
            active = true,
            enabled = function()
                return self.dig_panel.prio > 1
            end,
            disabled = false,
            show_tooltip = true,
            on_activate = function()
                self.dig_panel.prio = self.dig_panel.prio - 1
                self.dig_panel:updateLayout()
                self.dig_panel.needs_update = true
            end,
        },
        widgets.HotkeyLabel {
            view_id = "shape_option_priority_plus",
            key = "CUSTOM_SHIFT_P",
            label = "Decrease Priority",
            active = true,
            enabled = function()
                return self.dig_panel.prio < 7
            end,
            disabled = false,
            show_tooltip = true,
            on_activate = function()
                self.dig_panel.prio = self.dig_panel.prio + 1
                self.dig_panel:updateLayout()
                self.dig_panel.needs_update = true
            end,
        },
        widgets.ToggleHotkeyLabel {
            view_id = "autocommit_designation_label",
            key = "CUSTOM_C",
            label = "Auto-Commit: ",
            active = true,
            enabled = true,
            disabled = false,
            show_tooltip = true,
            initial_option = true,
            on_change = function(new, old)
                self.dig_panel.autocommit = new
                self.dig_panel.needs_update = true
            end,
        },
        widgets.HotkeyLabel {
            view_id = "commit_label",
            key = "CUSTOM_CTRL_C",
            label = "Commit Designation",
            active = true,
            enabled = function()
                return self.dig_panel.mark2 and self.dig_panel.mark1
            end,
            disabled = false,
            show_tooltip = true,
            on_activate = function()
                self.dig_panel:commit()
                self.dig_panel.needs_update = true
            end,
        } }
end

function GenericOptionsPanel:change_shape(new, old)
    self.dig_panel.shape = shapes.all_shapes[new]
    self.dig_panel:add_shape_options()
    self.dig_panel.needs_update = true
    self.dig_panel:updateLayout()
end

--
-- For tile graphics
--

local CURSORS = {
    INSIDE =  { 1, 2 },
    NORTH =   { 1, 1 },
    N_NUB =   { 3, 2 },
    S_NUB =   { 4, 2 },
    W_NUB =   { 3, 1 },
    E_NUB =   { 5, 1 },
    NE =      { 2, 1 },
    NW =      { 0, 1 },
    WEST =    { 0, 2 },
    EAST =    { 2, 2 },
    SW =      { 0, 3 },
    SOUTH =   { 1, 3 },
    SE =      { 2, 3 },
    VERT_NS = { 3, 3 },
    VERT_EW = { 4, 1 },
    POINT =   { 4, 3 },
}

-- Bit positions to use for keys in PENS table
local PEN_MASK = {
    NORTH =       1,
    SOUTH =       2,
    EAST =        3,
    WEST =        4,
    CORNER =      5,
    MOUSEOVER =   6,
    INSHAPE =     7,
    EXTRA_POINT = 8,
}

-- Populated dynamically as needed
-- The pens will be stored with keys corresponding to the directions passed to gen_pen_key()
local PENS = {}

--
-- Dig
--

Dig = defclass(Dig, widgets.Window)
Dig.ATTRS {
    frame_title = "Dig",
    frame = {
        w = 47,
        h = 40,
        r = 2,
        t = 18,
    },
    resizable = true,
    resize_min = { h = 30 },
    autoarrange_subviews = true,
    autoarrange_gap = 1,
    shape = DEFAULT_NIL,
    prio = 4,
    autocommit = true,
    cur_shape = 1,
    placing_extra = { active = false, index = nil },
    prev_center = DEFAULT_NIL,
    extra_points = {},
    last_mouse_point = DEFAULT_NIL,
    needs_update = false
}

-- Check to see if we're moving a point, or some change was made that implise we need to update the shape
-- This stop us needing to update the shape geometery every frame which can tank FPS
function Dig:shape_needs_update()
    if self.needs_update then return true end

    local mouse_pos = dfhack.gui.getMousePos()
    if mouse_pos then
        local mouse_moved = not self.last_mouse_point and mouse_pos or
            (
            self.last_mouse_point.x ~= mouse_pos.x or self.last_mouse_point.y ~= mouse_pos.y or
                self.last_mouse_point.z ~= mouse_pos.z)

        if self.mark1 and not self.mark2 and mouse_moved then
            return true
        end

        if self.placing_extra.active and mouse_moved then
            return true
        end
    end

    return false
end

function Dig:print_view_bounds()
    local view_bounds = self:get_view_bounds()

    local second_point = self.mark2 ~= nil and self.mark2 or dfhack.gui.getMousePos()

    if view_bounds then
        print(string.format("view_bounds: (%d, %d) - (%d, %d) self.mark1: (%d, %d) second_point: (%d, %d)",
            view_bounds.x1
            , view_bounds.y1,
            view_bounds.x2, view_bounds.y2, self.mark1.x, self.mark1.y, second_point.x, second_point.y))
    end
end

-- Get the pen to use when drawing a type of tile based on it's position in the shape and
-- neighboring tiles. The first time a certain tile type needs to be drawn, it's pen
-- is generated and stored in PENS. On subsequent calls, the cached pen will be used for
-- other tiles with the same position/direction
function Dig:get_pen(x, y, mousePos)

    local get_point = self.shape:get_point(x, y)
    local mouse_over = (mousePos) and (x == mousePos.x and y == mousePos.y) or false

    local drag_corner = false

    -- Some shapes like Line define which corners should have handles
    local shape_top_left, shape_bot_right = self.shape:get_point_dims()
    if x == shape_top_left.x and y == shape_top_left.y and self.shape.drag_corners.nw then
        drag_corner = true
    elseif x == shape_bot_right.x and y == shape_top_left.y and self.shape.drag_corners.ne then
        drag_corner = true
    elseif x == shape_top_left.x and y == shape_bot_right.y and self.shape.drag_corners.sw then
        drag_corner = true
    elseif x == shape_bot_right.x and y == shape_bot_right.y and self.shape.drag_corners.se then
        drag_corner = true
    end

    -- Is there an extra point
    local extra_point = false
    for i, point in ipairs(self.extra_points) do
        if x == point.x and y == point.y then
            extra_point = true
            break
        end
    end

    -- Show center point if both marks are set
    if self.mark1 ~= nil and self.mark2 ~= nil then
        local center_x, center_y = self.shape:get_center()

        if x == center_x and y == center_y then
            extra_point = true
        end
    end


    local n, w, e, s = false, false, false, false
    if self.shape:get_point(x, y) then
        if y == 0 or not self.shape:get_point(x, y - 1) then n = true end
        if x == 0 or not self.shape:get_point(x - 1, y) then w = true end
        if not self.shape:get_point(x + 1, y) then e = true end
        if not self.shape:get_point(x, y + 1) then s = true end
    end

    -- Get the bit field to use as a key for the PENS map
    local pen_key = self:gen_pen_key(n, s, e, w, drag_corner, mouse_over, get_point, extra_point)

    -- If key doesn't exist in the map, set it
    if pen_key and not PENS[pen_key] then
        if get_point and not n and not w and not e and not s then
            PENS[pen_key] = self:make_pen(CURSORS.INSIDE, drag_corner, mouse_over, get_point, extra_point)
        elseif get_point and n and w and not e and not s then
            PENS[pen_key] = self:make_pen(CURSORS.NW, drag_corner, mouse_over, get_point, extra_point)
        elseif get_point and n and not w and not e and not s then
            PENS[pen_key] = self:make_pen(CURSORS.NORTH, drag_corner, mouse_over, get_point, extra_point)
        elseif get_point and n and e and not w and not s then
            PENS[pen_key] = self:make_pen(CURSORS.NE, drag_corner, mouse_over, get_point, extra_point)
        elseif get_point and not n and w and not e and not s then
            PENS[pen_key] = self:make_pen(CURSORS.WEST, drag_corner, mouse_over, get_point, extra_point)
        elseif get_point and not n and not w and e and not s then
            PENS[pen_key] = self:make_pen(CURSORS.EAST, drag_corner, mouse_over, get_point, extra_point)
        elseif get_point and not n and w and not e and s then
            PENS[pen_key] = self:make_pen(CURSORS.SW, drag_corner, mouse_over, get_point, extra_point)
        elseif get_point and not n and not w and not e and s then
            PENS[pen_key] = self:make_pen(CURSORS.SOUTH, drag_corner, mouse_over, get_point, extra_point)
        elseif get_point and not n and not w and e and s then
            PENS[pen_key] = self:make_pen(CURSORS.SE, drag_corner, mouse_over, get_point, extra_point)
        elseif get_point and n and w and e and not s then
            PENS[pen_key] = self:make_pen(CURSORS.N_NUB, drag_corner, mouse_over, get_point, extra_point)
        elseif get_point and n and not w and e and s then
            PENS[pen_key] = self:make_pen(CURSORS.E_NUB, drag_corner, mouse_over, get_point, extra_point)
        elseif get_point and n and w and not e and s then
            PENS[pen_key] = self:make_pen(CURSORS.W_NUB, drag_corner, mouse_over, get_point, extra_point)
        elseif get_point and not n and w and e and s then
            PENS[pen_key] = self:make_pen(CURSORS.S_NUB, drag_corner, mouse_over, get_point, extra_point)
        elseif get_point and not n and w and e and not s then
            PENS[pen_key] = self:make_pen(CURSORS.VERT_NS, drag_corner, mouse_over, get_point, extra_point)
        elseif get_point and n and not w and not e and s then
            PENS[pen_key] = self:make_pen(CURSORS.VERT_EW, drag_corner, mouse_over, get_point, extra_point)
        elseif get_point and n and w and e and s then
            PENS[pen_key] = self:make_pen(CURSORS.POINT, drag_corner, mouse_over, get_point, extra_point)
        elseif drag_corner and not get_point then
            PENS[pen_key] = self:make_pen(CURSORS.INSIDE, drag_corner, mouse_over, get_point, extra_point)
        elseif extra_point then
            PENS[pen_key] = self:make_pen(CURSORS.INSIDE, drag_corner, mouse_over, get_point, extra_point)
        else
            PENS[pen_key] = nil
        end
    end

    -- Return the pen for the caller
    return PENS[pen_key]
end

function Dig:init()
    self:addviews { ActionPanel {
        view_id = "action_panel",
        get_mark1_fn = function()
            return self.mark1
        end,
        get_mark2_fn = function()
            if self.mark1 then
                return self.mark2 ~= nil and self.mark2 or dfhack.gui.getMousePos()
            else
                return nil
            end
        end,
        get_extra_pt_count = function()
            return #self.extra_points
        end,
    },
        GenericOptionsPanel {
            view_id = "name_panel",
            dig_panel = self,
        } }
end

function Dig:postinit()
    self.shape = shapes.all_shapes[self.subviews.shape_name:getOptionValue()]
    if self.shape then
        self:add_shape_options()
    end
end

-- Add shape specific options dynamically based on the shape.options table
-- Currently only supports 'bool' aka toggle and 'plusminus' which creates
-- a pair of HotKeyLabel's to increment/decrement a value
-- Will need to update as needed to add more option types
function Dig:add_shape_options()
    local prefix = "shape_option_"
    for i, view in ipairs(self.subviews or {}) do
        if view.view_id:sub(1, #prefix) == prefix then
            self.subviews[i] = nil
        end
    end

    if not self.shape or not self.shape.options then return end

    self:addviews { widgets.WrappedLabel {
        view_id = "shape_option_label",
        text_to_wrap = "Shape Settings:\n",
    } }

    for key, option in pairs(self.shape.options) do
        if option.type == "bool" then
            self:addviews {
                widgets.ToggleHotkeyLabel {
                    view_id = "shape_option_" .. option.name,
                    key = option.key,
                    label = option.name,
                    active = true,
                    enabled = function()
                        if option.enabled == nil then
                            return true
                        else
                            return self.shape.options[option.enabled[1]] == option.enabled[2]
                        end
                    end,
                    disabled = false,
                    show_tooltip = true,
                    initial_option = option.value,
                    on_change = function(new, old)
                        self.shape.options[key].value = new
                        self.needs_update = true
                    end,
                }
            }

        elseif option.type == "plusminus" then
            local min, max = nil, nil
            if type(option['min']) == "number" then
                min = option['min']
            elseif type(option['min']) == "function" then
                min = option['min'](self.shape)
            end
            if type(option['max']) == "number" then
                max = option['max']
            elseif type(option['max']) == "function" then
                max = option['max'](self.shape)
            end

            self:addviews {
                widgets.HotkeyLabel {
                    view_id = "shape_option_" .. option.name .. "_minus",
                    key = option.keys[1],
                    label = "Decrease " .. option.name,
                    active = true,
                    enabled = function()
                        if option.enabled ~= nil then
                            if self.shape.options[option.enabled[1]].value ~= option.enabled[2] then
                                return false
                            end
                        end
                        return min == nil or
                            (self.shape.options[key].value > min)
                    end,
                    disabled = false,
                    show_tooltip = true,
                    on_activate = function()
                        self.shape.options[key].value =
                        self.shape.options[key].value - 1
                        self.needs_update = true
                    end,
                },
                widgets.HotkeyLabel {
                    view_id = "shape_option_" .. option.name .. "_plus",
                    key = option.keys[2],
                    label = "Increase " .. option.name,
                    active = true,
                    enabled = function()
                        if option.enabled ~= nil then
                            if self.shape.options[option.enabled[1]].value ~= option.enabled[2] then
                                return false
                            end
                        end
                        return max == nil or
                            (self.shape.options[key].value <= max)
                    end,
                    disabled = false,
                    show_tooltip = true,
                    on_activate = function()
                        self.shape.options[key].value =
                        self.shape.options[key].value + 1
                        self.needs_update = true
                    end,
                }
            }
        end
    end
end

-- TODO think about if these are too redundant
function Dig:on_mark1(pos)
    self.mark1 = pos
    self:updateLayout()
end

function Dig:on_mark2(pos)
    self.mark2 = pos
    self:updateLayout()
end

function Dig:get_view_bounds()
    local cur = self.mark2 or dfhack.gui.getMousePos()
    if not cur then return end
    local mark1 = self.mark1 or cur

    return {
        x1 = math.min(cur.x, mark1.x),
        x2 = math.max(cur.x, mark1.x),
        y1 = math.min(cur.y, mark1.y),
        y2 = math.max(cur.y, mark1.y),
        z1 = math.min(cur.z, mark1.z),
        z2 = math.max(cur.z, mark1.z),
    }
end

-- return the pen, alter based on if we want to display a corner and a mouse over corner
function Dig:make_pen(direction, is_corner, is_mouse_over, inshape, extra_point)

    local color = COLOR_GREEN
    local ycursor_mod = 0
    if not extra_point then
        if is_corner then
            color = COLOR_CYAN
            ycursor_mod = ycursor_mod + 6
            if is_mouse_over then
                color = COLOR_MAGENTA
                ycursor_mod = ycursor_mod + 3
            end
        end
    elseif extra_point then
        ycursor_mod = ycursor_mod + 15
        color = COLOR_LIGHTRED

        if is_mouse_over then
            color = COLOR_RED
            ycursor_mod = ycursor_mod + 3
        end

    end
    return to_pen {
        ch = inshape and "X" or "o",
        fg = color,
        tile = dfhack.screen.findGraphicsTile(
            "CURSORS",
            direction[1],
            direction[2] + ycursor_mod
        ),
    }
end

-- Generate a bit field to store as keys in PENS
function Dig:gen_pen_key(n, s, e, w, is_corner, is_mouse_over, inshape, extra_point)
    local ret = 0
    if n then ret = ret + (1 << PEN_MASK.NORTH) end
    if s then ret = ret + (1 << PEN_MASK.SOUTH) end
    if e then ret = ret + (1 << PEN_MASK.EAST) end
    if w then ret = ret + (1 << PEN_MASK.WEST) end
    if is_corner then ret = ret + (1 << PEN_MASK.CORNER) end
    if is_mouse_over then ret = ret + (1 << PEN_MASK.MOUSEOVER) end
    if inshape then ret = ret + (1 << PEN_MASK.INSHAPE) end
    if extra_point then ret = ret + (1 << PEN_MASK.EXTRA_POINT) end

    return ret
end

function Dig:onRenderFrame(dc, rect)

    Dig.super.onRenderFrame(self, dc, rect)

    if self.shape == nil then
        self.shape = shapes.all_shapes[self.subviews.shape_name:getOptionValue()]
    end

    local mouse_pos = dfhack.gui.getMousePos()

    if self.mark1 then
        local second_point = self.mark2 ~= nil and self.mark2 or mouse_pos

        if not second_point then return end

        -- Set the pos of the currently moving extra point
        if self.placing_extra.active then
            local mouse_pos = mouse_pos
            self.extra_points[self.placing_extra.index] = { x = mouse_pos.x, y = mouse_pos.y }
        end

        -- Set main points
        local points = { self.mark1, second_point }

        -- Check if moving center, if so shift the shape by the delta between the previous and current points
        if self.prev_center ~= nil and self.mark1 ~= nil and self.mark2 ~= nil then
            if self.prev_center.x ~= mouse_pos.x or self.prev_center.y ~= mouse_pos.y or
                self.prev_center.z ~= mouse_pos.z then
                self.needs_update = true
                local transform_x = mouse_pos.x - self.prev_center.x
                local transform_y = mouse_pos.y - self.prev_center.y
                local transform_z = mouse_pos.z - self.prev_center.z

                self.mark1.x = self.mark1.x + transform_x
                self.mark1.y = self.mark1.y + transform_y
                self.mark1.z = self.mark1.z + transform_z
                self.mark2.x = self.mark2.x + transform_x
                self.mark2.y = self.mark2.y + transform_y
                self.mark2.z = self.mark2.z + transform_z

                for i, point in pairs(self.extra_points) do
                    self.extra_points[i].x = self.extra_points[i].x + transform_x
                    self.extra_points[i].y = self.extra_points[i].y + transform_y
                end

                self.prev_center = mouse_pos
            end
        end

        if self:shape_needs_update() then
            self.shape:update(points, self.extra_points)
            self.last_mouse_point = mouse_pos
            self.needs_update = false
        end

        self:add_shape_options()
        self:updateLayout()

        local function get_overlay_pen(pos)
            return self:get_pen(pos.x, pos.y, mouse_pos)
        end

        -- Generate bounds based on the shape's dimensions
        local bounds = self:get_view_bounds()
        if self.shape ~= nil then
            local top_left, bot_right = self.shape:get_view_dims(self.extra_points)
            bounds.x1 = top_left.x
            bounds.x2 = bot_right.x
            bounds.y1 = top_left.y
            bounds.y2 = bot_right.y
        end

        guidm.renderMapOverlay(get_overlay_pen, bounds)
    end
end

function Dig:onInput(keys)
    if Dig.super.onInput(self, keys) then
        return true
    end

    if keys.LEAVESCREEN or keys._MOUSE_R_DOWN then

        -- If extra points, clear them and return
        if self.shape ~= nil then
            -- if extra points have been set
            if #self.extra_points > 0 or self.placing_extra.active then
                self.extra_points = {}
                self.placing_extra.active = false
                self.prev_center = nil
                self.placing_extra.index = 0
                self.needs_update = true
                self:updateLayout()
                return true
            end
        end

        if self.mark2 then
            self.mark2 = nil
            self.needs_update = true
        elseif self.mark1 then
            self.mark1 = nil
            self.needs_update = true
            self:updateLayout()
        else
            self.parent_view:dismiss()
        end

        return true
    end

    local pos = nil
    if keys._MOUSE_L_DOWN and not self:getMouseFramePos() then
        pos = dfhack.gui.getMousePos()
        if pos then
            guidm.setCursorPos(pos)
        end
    elseif keys.SELECT then
        pos = guidm.getCursorPos()
    end

    if keys._MOUSE_L_DOWN and pos then
        if self.mark1 and not self.mark2 then
            self:on_mark2(pos)
            -- The statement after the or is to allow the 1x1 special case for easy doorways
            self.needs_update = true
            if self.autocommit or (self.mark1.x == self.mark2 and self.mark1.y == self.mark2.y) then
                self:commit()
            end
        elseif not self.mark1 then
            self.needs_update = true
            self:on_mark1(pos)
        elseif self.placing_extra.active then
            self.needs_update = true
            self.placing_extra.active = false
        else
            -- Clicking a corner
            local shape_top_left, shape_bot_right = self.shape:get_point_dims()
            if pos.x == shape_top_left.x and pos.y == shape_top_left.y and self.shape.drag_corners.nw then
                self.mark1 = xyz2pos(shape_bot_right.x, shape_bot_right.y, self.mark1.z)
                self.mark2 = nil
            elseif pos.x == shape_bot_right.x and pos.y == shape_top_left.y and self.shape.drag_corners.ne then
                self.mark1 = xyz2pos(shape_top_left.x, shape_bot_right.y, self.mark1.z)
                self.mark2 = nil
            elseif pos.x == shape_top_left.x and pos.y == shape_bot_right.y and self.shape.drag_corners.sw then
                self.mark1 = xyz2pos(shape_bot_right.x, shape_top_left.y, self.mark1.z)
                self.mark2 = nil
            elseif pos.x == shape_bot_right.x and pos.y == shape_bot_right.y and self.shape.drag_corners.se then
                self.mark1 = xyz2pos(shape_top_left.x, shape_top_left.y, self.mark1.z)
                self.mark2 = nil
            end

            -- Clicking an extra point
            for i = 1, #self.extra_points do
                if pos.x == self.extra_points[i].x and pos.y == self.extra_points[i].y then
                    self.placing_extra.active = true
                    self.placing_extra.index = i
                    self.needs_update = true
                    return true
                end
            end

            -- Clicking center point
            local center_x, center_y = self.shape:get_center()
            if pos.x == center_x and pos.y == center_y and self.prev_center == nil then
                self.prev_center = pos
            elseif self.prev_center ~= nil then
                self.prev_center = nil
            end
        end

        self.needs_update = true
        return true
    end

    -- send movement and pause keys through, but otherwise we're a modal dialog
    return not (keys.D_PAUSE or guidm.getMapKey(keys))
end

-- Put any special logic for designation type here
-- Right now it's setting the stair type based on the z-level
-- Fell through, pass through the option directly from the options value
function Dig:get_designation(x, y, z)
    local mode = self.subviews.mode_name:getOptionValue()

    local view_bounds = self:get_view_bounds()

    -- Stairs
    if mode == "i" then
        local stairs_top_type = self.subviews.stairs_top_subtype:getOptionValue()
        local stairs_middle_type = self.subviews.stairs_middle_subtype:getOptionValue()
        local stairs_bottom_type = self.subviews.stairs_bottom_subtype:getOptionValue()
        if z == 0 then
            return stairs_bottom_type == "auto" and "u" or stairs_bottom_type
        elseif z == math.abs(view_bounds.z1 - view_bounds.z2) then
            local pos = xyz2pos(view_bounds.x1 + x, view_bounds.y1 + y, view_bounds.z1 + z)
            local tile_type = dfhack.maps.getTileType(pos)
            local tile_shape = tile_type ~= nil and tile_attrs[tile_type].shape or nil
            local designation = dfhack.maps.getTileFlags(pos)

            -- If top of the view_bounds is down stair, 'auto' should change it to up/down to match vanilla stair logic
            local up_or_updown_dug = (
                tile_shape == df.tiletype_shape.STAIR_DOWN or tile_shape == df.tiletype_shape.STAIR_UPDOWN)
            local up_or_updown_desig = designation ~= nil and (designation.dig == df.tile_dig_designation.UpStair or
                designation.dig == df.tile_dig_designation.UpDownStair)

            if stairs_top_type == "auto" then
                return (up_or_updown_desig or up_or_updown_dug) and "i" or "j"
            else
                return stairs_top_type
            end
        else
            return stairs_middle_type == "auto" and 'i' or stairs_middle_type
        end
    end

    return self.subviews.mode_name:getOptionValue()
end

-- Commit the shape using quickfort API
function Dig:commit()
    local data = {}
    local top_left, bot_right = self.shape:get_true_dims()
    local view_bounds = self:get_view_bounds()

    -- Generates the params for quickfort API
    local function generate_params(grid, position)
        -- local top_left, bot_right = self.shape:get_true_dims()
        for zlevel = 0, math.abs(view_bounds.z1 - view_bounds.z2) do
            data[zlevel] = {}
            for row = 0, math.abs(
                bot_right.y - top_left.y
            ) do
                data[zlevel][row] = {}
                for col = 0, math.abs(
                    bot_right.x - top_left.x
                ) do
                    if grid[col] and grid[col][row] then
                        local desig = self:get_designation(col, row, zlevel)
                        if desig ~= "`" then
                            data[zlevel][row][col] =
                            desig .. tostring(self.prio)
                        end
                    end
                end
            end
        end

        return {
            data = data,
            pos = position,
            mode = "dig",
        }
    end

    local start = {
        x = top_left.x,
        y = top_left.y,
        z = math.min(view_bounds.z1, view_bounds.z2),
    }

    local grid = self.shape:transform(0, 0)

    -- Special case for 1x1 to ease doorway mark1ing
    if top_left.x == bot_right.x and top_left.y == bot_right.y2 then
        grid = {}
        grid[0] = {}
        grid[0][0] = true
    end

    local params = generate_params(grid, start)
    quickfort.apply_blueprint(params)

    -- Only clear points if we're autocommit
    if self.autocommit then
        self.mark1 = nil
        self.mark2 = nil
        self.placing_extra = { active = false, index = nil }
        self.extra_points = {}
        self.prev_center = nil
    end
    self:updateLayout()
end

--
-- Dig
--

DigScreen = defclass(DigScreen, gui.ZScreen)
DigScreen.ATTRS {
    focus_path = "dig",
    pass_pause = true,
    pass_movement_keys = true,
}

function DigScreen:init()
    self:addviews { Dig {} }
end

function DigScreen:onDismiss()
    view = nil
end

if dfhack_flags.module then return end

if not dfhack.isMapLoaded() then
    qerror("This script requires a fortress map to be loaded")
end

view = view and view:raise() or DigScreen {}:show()
