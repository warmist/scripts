-- A GUI front-end for the digging designations
--@ module = false

-- TODOS ====================

-- Must Haves
-----------------------------
-- Reconsider sorting of mirrored points
-- Better UI, it's starting to get really crowded

-- Should Haves
-----------------------------
-- Refactor duplicated code into functions
--  File is getting long... might be time to consider creating additional modules
-- All the various states are getting hard to keep track of, e.g. placing extra/mirror/mark/etc...
--   Should consolidate the states into a single attribute with enum values
-- Keyboard support
-- As the number of shapes and designations grow it might be better to have list menus for them instead of cycle
-- Grid view without slowness (can ignore if next TODO is done, since nrmal mining mode has grid view)
--   Lags when drawing the full screen grid on each frame render
-- Integrate with default mining mode for designation type, priority, etc... (possible?)
-- Figure out how to remove dug stairs with mode (nothing seems to work, include 'dig ramp')
-- 'No overwrite' mode to not overwrite existing designations
-- Snap to grid, or angle, like 45 degrees, or some kind of tools to assist with symmetrical designs

-- Nice To Haves
-----------------------------
-- Exploration pattern ladder https://dwarffortresswiki.org/index.php/DF2014:Exploratory_mining#Ladder_Rows

-- Stretch Goals
-----------------------------
-- Shape preview in panel
-- Shape designer in preview panel to draw repeatable shapes i'e' 2x3 room with door
-- 3D shapes, would allow stuff like spiral staircases/minecart tracks and other neat stuff, probably not too hard

-- END TODOS ================

local gui = require("gui")
local guidm = require("gui.dwarfmode")
local widgets = require("gui.widgets")
local quickfort = reqscript("quickfort")
local shapes = reqscript("internal/dig/shapes")

local tile_attrs = df.tiletype.attrs

local to_pen = dfhack.pen.parse
local guide_tile_pen = to_pen {
    ch = "+",
    fg = COLOR_YELLOW,
    tile = dfhack.screen.findGraphicsTile(
        "CURSORS",
        0,
        22
    ),
}

local mirror_guide_pen = to_pen {
    ch = "+",
    fg = COLOR_YELLOW,
    tile = dfhack.screen.findGraphicsTile(
        "CURSORS",
        1,
        22
    ),
}

-- Utilities

local function same_xy(pos1, pos2)
    return pos1.x == pos2.x and pos1.y == pos2.y
end

local function same_xyz(pos1, pos2)
    return same_xy(pos1, pos2) and pos1.z == pos2.z
end

-- Debug window

SHOW_DEBUG_WINDOW = true

local function table_to_string(tbl, indent)
    indent = indent or ""
    local result = {}
    for k, v in pairs(tbl) do
        local key = type(k) == "number" and "[" .. tostring(k) .. "]" or tostring(k)
        if type(v) == "table" then
            table.insert(result, indent .. key .. " = {")
            local subTable = table_to_string(v, indent .. "  ")
            for _, line in ipairs(subTable) do
                table.insert(result, line)
            end
            table.insert(result, indent .. "},")
        elseif type(v) == "function" then
            local res = v()
            local value = type(res) == "number" and tostring(res) or "\"" .. tostring(res) .. "\""
            table.insert(result, indent .. key .. " = " .. value .. ",")
        else
            local value = type(v) == "number" and tostring(v) or "\"" .. tostring(v) .. "\""
            table.insert(result, indent .. key .. " = " .. value .. ",")
        end
    end
    return result
end

DigDebugWindow = defclass(DigDebugWindow, widgets.Window)
DigDebugWindow.ATTRS {
    frame_title = "Debug",
    frame = {
        w = 47,
        h = 40,
        l = 10,
        t = 8,
    },
    resizable = true,
    resize_min = { h = 30 },
    autoarrange_subviews = true,
    autoarrange_gap = 1,
    dig_window = DEFAULT_NIL
}
function DigDebugWindow:init()

    local attrs = {
        -- "shape", -- prints a lot of lines due to the self.arr, best to disable unless needed, TODO add a 'get debug string' function
        "prio",
        "autocommit",
        "cur_shape",
        "placing_extra",
        "placing_mark",
        "prev_center",
        "start_center",
        "extra_points",
        "last_mouse_point",
        "needs_update",
        "#marks",
        "placing_mirror",
        "mirror_point",
        "mirror",
        "show_guides"
    }

    if not self.dig_window then
        return
    end
    for i, a in pairs(attrs) do
        local attr = a
        local sizeOnly = string.sub(attr, 1, 1) == "#"

        if (sizeOnly) then
            attr = string.sub(attr, 2)
        end

        self:addviews { widgets.WrappedLabel {
            view_id = "debug_label_" .. attr,
            text_to_wrap = function()
                if type(self.dig_window[attr]) ~= "table" then
                    return tostring(attr) .. ": " .. tostring(self.dig_window[attr])
                end

                if sizeOnly then
                    return '#' .. tostring(attr) .. ": " .. tostring(#self.dig_window[attr])
                else
                    return { tostring(attr) .. ": ", table.unpack(table_to_string(self.dig_window[attr], "  ")) }
                end
            end,
        } }
    end
end

--Show mark point coordinates
MarksPanel = defclass(MarksPanel, widgets.ResizingPanel)
MarksPanel.ATTRS {
    get_area_fn = DEFAULT_NIL,
    autoarrange_subviews = true,
    dig_panel = DEFAULT_NIL
}

function MarksPanel:init()
end

function MarksPanel:update_mark_labels()
    self.subviews = {}
    local label_text = {}
    if #self.dig_panel.marks >= 1 then
        local first_mark = self.dig_panel.marks[1]
        if first_mark then
            table.insert(label_text,
                string.format("First Mark (%d): %d, %d, %d ", 1, first_mark.x, first_mark.y, first_mark.z))
        end
    end

    if #self.dig_panel.marks > 1 then
        local last_mark = self.dig_panel.marks[#self.dig_panel.marks]
        if last_mark then
            table.insert(label_text,
                string.format("Last Mark (%d): %d, %d, %d ", #self.dig_panel.marks, last_mark.x, last_mark.y, last_mark.z))
        end
    end

    local mouse_pos = dfhack.gui.getMousePos()
    if mouse_pos then
        table.insert(label_text, string.format("Mouse: %d, %d, %d", mouse_pos.x, mouse_pos.y, mouse_pos.z))
    end

    local mirror = self.dig_panel.mirror_point
    if mirror then
        table.insert(label_text, string.format("Mirror Point: %d, %d, %d", mirror.x, mirror.y, mirror.z))
    end

    self:addviews {
        widgets.WrappedLabel {
            view_id = "mark_labels",
            text_to_wrap = label_text,
        }
    }

end

-- Panel to show the Mouse position/dimensions/etc
ActionPanel = defclass(ActionPanel, widgets.ResizingPanel)
ActionPanel.ATTRS {
    get_area_fn = DEFAULT_NIL,
    autoarrange_subviews = true,
    dig_panel = DEFAULT_NIL
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
        self:get_mark_labels()
    }
end

function ActionPanel:get_mark_labels()
end

function ActionPanel:get_action_text()
    local text = ""
    if self.dig_panel.marks[1] and self.dig_panel.placing_mark.active then
        text = "Place the next point"
    elseif not self.dig_panel.marks[1] then
        text = "Place the first point"
    elseif not self.parent_view.placing_extra.active and not self.parent_view.prev_center then
        text = "Select any draggable points"
    elseif self.parent_view.placing_extra.active then
        text = "Place any extra points"
    elseif self.parent_view.prev_center then
        text = "Place the center point"
    else
        text = "Select any draggable points"
    end
    return text .. " with the mouse. Use right-click to dismiss points in order."
end

function ActionPanel:get_area_text()
    local label = "Area: "

    local bounds = self.dig_panel:get_view_bounds()
    if not bounds then return label .. "N/A" end
    local width = math.abs(bounds.x2 - bounds.x1) + 1
    local height = math.abs(bounds.y2 - bounds.y1) + 1
    local depth = math.abs(bounds.z2 - bounds.z1) + 1
    local tiles = self.dig_panel.shape.num_tiles * depth
    local plural = tiles > 1 and "s" or ""
    return label .. ("%dx%dx%d (%d tile%s)"):format(
        width,
        height,
        depth,
        tiles,
        plural
    )
end

function ActionPanel:get_mark_text(num)
    local mark = self.dig_panel.marks[num]

    local label = string.format("Mark %d: ", num)

    if not mark then
        return label .. "Not set"
    end

    return label .. ("%d, %d, %d"):format(
        mark.x,
        mark.y,
        mark.z
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
    for i, shape in ipairs(shapes.all_shapes) do
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

        widgets.ResizingPanel { autoarrange_subviews = true,
            subviews = {
                widgets.ToggleHotkeyLabel {
                    key = 'CUSTOM_SHIFT_Y',
                    view_id = 'transform',
                    label = 'Transform',
                    active = true,
                    enabled = true,
                    initial_option = false,
                    on_change = nil
                },
                widgets.ResizingPanel {
                    view_id = 'transform_panel_rotate',
                    visible = function() return self.dig_panel.subviews.transform:getOptionValue() end,
                    subviews = {
                        widgets.HotkeyLabel {
                            key = 'STRING_A040',
                            frame = { t = 1, l = 1 }, key_sep = '',
                            on_activate = self.dig_panel:callback('on_transform', 'ccw'),
                        },
                        widgets.HotkeyLabel {
                            key = 'STRING_A041',
                            frame = { t = 1, l = 2 }, key_sep = ':',
                            on_activate = self.dig_panel:callback('on_transform', 'cw'),
                        },
                        widgets.WrappedLabel {
                            frame = { t = 1, l = 5 },
                            text_to_wrap = 'Rotate'
                        },
                        widgets.HotkeyLabel {
                            key = 'STRING_A095',
                            frame = { t = 2, l = 1 }, key_sep = '',
                            on_activate = self.dig_panel:callback('on_transform', 'flipv'),
                        },
                        widgets.HotkeyLabel {
                            key = 'STRING_A061',
                            frame = { t = 2, l = 2 }, key_sep = ':',
                            on_activate = self.dig_panel:callback('on_transform', 'fliph'),
                        },
                        widgets.WrappedLabel {
                            frame = { t = 2, l = 5 },
                            text_to_wrap = 'Flip'
                        }
                    }
                }
            }
        },
        widgets.ResizingPanel { autoarrange_subviews = true,
            subviews = {
                widgets.HotkeyLabel {
                    key = 'CUSTOM_M',
                    view_id = 'mirror_point_panel',
                    visible = function() return self.dig_panel.shape.can_mirror end,
                    label = function() if not self.dig_panel.mirror_point then return 'Place Mirror Point' else return 'Delete Mirror Point' end end,
                    active = true,
                    enabled = function() return not self.dig_panel.placing_extra.active and
                            not self.dig_panel.placing_mark.active and not self.prev_center
                    end,
                    on_activate = function()
                        if not self.dig_panel.mirror_point then
                            self.dig_panel.placing_mark.active = false
                            self.dig_panel.placing_extra.active = false
                            self.dig_panel.placing_extra.active = false
                            self.dig_panel.placing_mirror = true
                        else
                            self.dig_panel.placing_mirror = false
                            self.dig_panel.mirror_point = nil
                        end
                    end
                },
                widgets.ResizingPanel {
                    view_id = 'transform_panel_rotate',
                    visible = function() return self.dig_panel.mirror_point end,
                    subviews = {
                        widgets.CycleHotkeyLabel {
                            view_id = "mirror_horiz_label",
                            key = "CUSTOM_SHIFT_J",
                            label = "Mirror Horizontal: ",
                            active = true,
                            enabled = true,
                            show_tooltip = true,
                            initial_option = 1,
                            options = { { label = "Off", value = 1 }, { label = "On (odd)", value = 2 },
                                { label = "On (even)", value = 3 } },
                            frame = { t = 1, l = 1 }, key_sep = '',
                            on_change = function() self.dig_panel.needs_update = true end
                        },
                        widgets.CycleHotkeyLabel {
                            view_id = "mirror_diag_label",
                            key = "CUSTOM_SHIFT_O",
                            label = "Mirror Diagonal: ",
                            active = true,
                            enabled = true,
                            show_tooltip = true,
                            initial_option = 1,
                            options = { { label = "Off", value = 1 }, { label = "On (odd)", value = 2 },
                                { label = "On (even)", value = 3 } },
                            frame = { t = 2, l = 1 }, key_sep = '',
                            on_change = function() self.dig_panel.needs_update = true end
                        },
                        widgets.CycleHotkeyLabel {
                            view_id = "mirror_vert_label",
                            key = "CUSTOM_SHIFT_K",
                            label = "Mirror Vertical: ",
                            active = true,
                            enabled = true,
                            show_tooltip = true,
                            initial_option = 1,
                            options = { { label = "Off", value = 1 }, { label = "On (odd)", value = 2 },
                                { label = "On (even)", value = 3 } },
                            frame = { t = 3, l = 1 }, key_sep = '',
                            on_change = function() self.dig_panel.needs_update = true end
                        },
                        widgets.HotkeyLabel {
                            view_id = "mirror_vert_label",
                            key = "CUSTOM_SHIFT_M",
                            label = "Save Mirrored Points",
                            active = true,
                            enabled = true,
                            show_tooltip = true,
                            initial_option = 1,
                            frame = { t = 4, l = 1 }, key_sep = ': ',
                            on_activate = function()
                                local points = self.dig_panel:get_mirrored_points(self.dig_panel.marks)
                                self.dig_panel.marks = points
                                self.dig_panel.mirror_point = nil
                            end
                        },
                    }
                }
            }
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
            visible = function() return self.dig_panel.shape and #self.dig_panel.shape.extra_points > 0 end,
            enabled = function()
                if self.dig_panel.shape then
                    return #self.dig_panel.extra_points < #self.dig_panel.shape.extra_points
                end

                return false
            end,
            show_tooltip = true,
            on_activate = function()
                if not self.dig_panel.placing_mark.active then
                    self.dig_panel.placing_extra.active = true
                    self.dig_panel.placing_extra.index = #self.dig_panel.extra_points + 1
                elseif #self.dig_panel.marks then
                    local mouse_pos = dfhack.gui.getMousePos()
                    if mouse_pos then table.insert(self.dig_panel.extra_points, { x = mouse_pos.x, y = mouse_pos.y }) end
                end
                self.dig_panel.needs_update = true
            end,
        },
        widgets.HotkeyLabel {
            view_id = "shape_toggle_placing_marks",
            key = "CUSTOM_B",
            label = function()
                return (self.dig_panel.placing_mark.active) and "Stop placing" or "Start placing"
            end,
            active = true,
            visible = true,
            enabled = function()
                if not self.dig_panel.placing_mark.active and not self.dig_panel.prev_center then
                    return not self.dig_panel.shape.max_points or
                        #self.dig_panel.marks < self.dig_panel.shape.max_points
                elseif not self.dig_panel.placing_extra.active and not self.dig_panel.prev_centerl then
                    return true
                end

                return false
            end,
            show_tooltip = true,
            on_activate = function()
                self.dig_panel.placing_mark.active = not self.dig_panel.placing_mark.active
                self.dig_panel.placing_mark.index = (self.dig_panel.placing_mark.active) and #self.dig_panel.marks + 1 or
                    nil
                if not self.dig_panel.placing_mark.active then
                    table.remove(self.dig_panel.marks, #self.dig_panel.marks)
                else
                    self.dig_panel.placing_mark.continue = true
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
                if #self.dig_panel.marks > 0 then return true
                elseif self.dig_panel.shape then
                    if #self.dig_panel.extra_points < #self.dig_panel.shape.extra_points then
                        return true
                    end
                end

                return false
            end,
            disabled = false,
            show_tooltip = true,
            on_activate = function()
                self.dig_panel.marks = {}
                self.dig_panel.placing_mark.active = true
                self.dig_panel.placing_mark.index = 1
                self.dig_panel.extra_points = {}
                self.dig_panel.prev_center = nil
                self.dig_panel.start_center = nil
                self.dig_panel.needs_update = true
            end,
        },
        widgets.HotkeyLabel {
            view_id = "shape_clear_extra_points",
            key = "CUSTOM_SHIFT_X",
            label = "Clear extra points",
            active = true,
            enabled = function()
                if self.dig_panel.shape then
                    if #self.dig_panel.extra_points > 0 then
                        return true
                    end
                end

                return false
            end,
            disabled = false,
            visible = function() return self.dig_panel.shape and #self.dig_panel.shape.extra_points > 0 end,
            show_tooltip = true,
            on_activate = function()
                if self.dig_panel.shape then
                    self.dig_panel.extra_points = {}
                    self.dig_panel.prev_center = nil
                    self.dig_panel.start_center = nil
                    self.dig_panel.placing_extra = { active = false, index = 0 }
                    self.dig_panel:updateLayout()
                    self.dig_panel.needs_update = true
                end
            end,
        },
        widgets.ToggleHotkeyLabel {
            view_id = "shape_show_guides",
            key = "CUSTOM_SHIFT_G",
            label = "Show Cursor Guides",
            active = true,
            enabled = true,
            visible = true,
            show_tooltip = true,
            initial_option = true,
            on_change = function(new, old)
                self.dig_panel.show_guides = new
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
            enabled = function() return self.dig_panel.shape.max_points end,
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
                return #self.dig_panel.marks >= self.dig_panel.shape.min_points
            end,
            disabled = false,
            show_tooltip = true,
            on_activate = function()
                self.dig_panel:commit()
                self.dig_panel.needs_update = true
            end,
        },
    }
end

function GenericOptionsPanel:change_shape(new, old)
    self.dig_panel.shape = shapes.all_shapes[new]
    if self.dig_panel.shape.max_points and #self.dig_panel.marks > self.dig_panel.shape.max_points then
        -- pop marks until we're down to the max of the new shape
        for i = #self.dig_panel.marks, self.dig_panel.shape.max_points, -1 do
            table.remove(self.dig_panel.marks, i)
        end
    end
    self.dig_panel:add_shape_options()
    self.dig_panel.needs_update = true
    self.dig_panel:updateLayout()
end

--
-- For tile graphics
--

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

-- Bit positions to use for keys in PENS table
local PEN_MASK = {
    NORTH = 1,
    SOUTH = 2,
    EAST = 3,
    WEST = 4,
    DRAG_POINT = 5,
    MOUSEOVER = 6,
    INSHAPE = 7,
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
    name = "dig_window",
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
    placing_mark = { active = true, index = 1, continue = true },
    prev_center = DEFAULT_NIL,
    start_center = DEFAULT_NIL,
    extra_points = {},
    last_mouse_point = DEFAULT_NIL,
    needs_update = false,
    marks = {},
    placing_mirror = false,
    mirror_point = DEFAULT_NIL,
    mirror = { horizontal = false, vertical = false },
    show_guides = true
}

-- Check to see if we're moving a point, or some change was made that implise we need to update the shape
-- This stop us needing to update the shape geometery every frame which can tank FPS
function Dig:shape_needs_update()
    -- if #self.marks < self.shape.min_points then return false end

    if self.needs_update then return true end

    local mouse_pos = dfhack.gui.getMousePos()
    if mouse_pos then
        local mouse_moved = not self.last_mouse_point and mouse_pos or
            (
            self.last_mouse_point.x ~= mouse_pos.x or self.last_mouse_point.y ~= mouse_pos.y or
                self.last_mouse_point.z ~= mouse_pos.z)

        if self.placing_mark.active and mouse_moved then
            return true
        end

        if self.placing_extra.active and mouse_moved then
            return true
        end
    end

    return false
end

-- Get the pen to use when drawing a type of tile based on it's position in the shape and
-- neighboring tiles. The first time a certain tile type needs to be drawn, it's pen
-- is generated and stored in PENS. On subsequent calls, the cached pen will be used for
-- other tiles with the same position/direction
function Dig:get_pen(x, y, mousePos)

    local get_point = self.shape:get_point(x, y)
    local mouse_over = (mousePos) and (x == mousePos.x and y == mousePos.y) or false

    local drag_point = false

    -- Basic shapes are bounded by rectangles and therefore can have corner drag points
    -- even if they're not real points in the shape
    if #self.marks >= self.shape.min_points and self.shape.basic_shape then
        local shape_top_left, shape_bot_right = self.shape:get_point_dims()
        if x == shape_top_left.x and y == shape_top_left.y and self.shape.drag_corners.nw then
            drag_point = true
        elseif x == shape_bot_right.x and y == shape_top_left.y and self.shape.drag_corners.ne then
            drag_point = true
        elseif x == shape_top_left.x and y == shape_bot_right.y and self.shape.drag_corners.sw then
            drag_point = true
        elseif x == shape_bot_right.x and y == shape_bot_right.y and self.shape.drag_corners.se then
            drag_point = true
        end
    end

    for i, mark in ipairs(self.marks) do
        if same_xy(mark, xy2pos(x, y)) then
            drag_point = true
        end
    end

    if self.mirror_point and same_xy(self.mirror_point, xy2pos(x, y)) then
        drag_point = true
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
    if (self.shape.basic_shape and #self.marks == self.shape.max_points) or
        (not self.shape.basic_shape and not self.placing_mark.active and #self.marks > 0) then
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
    local pen_key = self:gen_pen_key(n, s, e, w, drag_point, mouse_over, get_point, extra_point)


    -- Determine the cursor to use based on the input parameters
    local cursor = nil
    if pen_key and not PENS[pen_key] then
        if get_point and not n and not w and not e and not s then cursor = CURSORS.INSIDE
        elseif get_point and n and w and not e and not s then cursor = CURSORS.NW
        elseif get_point and n and not w and not e and not s then cursor = CURSORS.NORTH
        elseif get_point and n and e and not w and not s then cursor = CURSORS.NE
        elseif get_point and not n and w and not e and not s then cursor = CURSORS.WEST
        elseif get_point and not n and not w and e and not s then cursor = CURSORS.EAST
        elseif get_point and not n and w and not e and s then cursor = CURSORS.SW
        elseif get_point and not n and not w and not e and s then cursor = CURSORS.SOUTH
        elseif get_point and not n and not w and e and s then cursor = CURSORS.SE
        elseif get_point and n and w and e and not s then cursor = CURSORS.N_NUB
        elseif get_point and n and not w and e and s then cursor = CURSORS.E_NUB
        elseif get_point and n and w and not e and s then cursor = CURSORS.W_NUB
        elseif get_point and not n and w and e and s then cursor = CURSORS.S_NUB
        elseif get_point and not n and w and e and not s then cursor = CURSORS.VERT_NS
        elseif get_point and n and not w and not e and s then cursor = CURSORS.VERT_EW
        elseif get_point and n and w and e and s then cursor = CURSORS.POINT
        elseif drag_point and not get_point then cursor = CURSORS.INSIDE
        elseif extra_point then cursor = CURSORS.INSIDE
        else cursor = nil
        end
    end

    -- Create the pen if the cursor is set
    if cursor then PENS[pen_key] = self:make_pen(cursor, drag_point, mouse_over, get_point, extra_point) end

    -- Return the pen for the caller
    return PENS[pen_key]
end

function Dig:init()
    self:addviews {
        ActionPanel {
            view_id = "action_panel",
            dig_panel = self,
            get_extra_pt_count = function()
                return #self.extra_points
            end,
        },
        MarksPanel {
            view_id = "marks_panel",
            dig_panel = self,
        },
        GenericOptionsPanel {
            view_id = "generic_panel",
            dig_panel = self,
        }
    }
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

    self:addviews {
        widgets.WrappedLabel {
            view_id = "shape_option_label",
            text_to_wrap = "Shape Settings:\n",
        }
    }

    for key, option in pairs(self.shape.options) do
        if option.type == "bool" then
            self:addviews {
                widgets.ToggleHotkeyLabel {
                    view_id = "shape_option_" .. option.name,
                    key = option.key,
                    label = option.name,
                    active = true,
                    enabled = function()
                        if not option.enabled then
                            return true
                        else
                            return self.shape.options[option.enabled[1]].value == option.enabled[2]
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
                        if option.enabled then
                            if self.shape.options[option.enabled[1]].value ~= option.enabled[2] then
                                return false
                            end
                        end
                        return not min or
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
                        if option.enabled then
                            if self.shape.options[option.enabled[1]].value ~= option.enabled[2] then
                                return false
                            end
                        end
                        return not max or
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

function Dig:on_transform(val)
    local center_x, center_y = self.shape:get_center()
    -- if self.mirror_point then
    --     center_x, center_y = self.mirror_point.x, self.mirror_point.y
    -- end

    -- Save mirrored points first
    if self.mirror_point then
        local points = self:get_mirrored_points(self.marks)
        self.marks = points
        self.mirror_point = nil
    end

    -- Transform marks
    for i, mark in ipairs(self.marks) do
        local x, y = mark.x, mark.y
        if val == 'cw' then
            x, y = center_x - (y - center_y), center_y + (x - center_x)
        elseif val == 'ccw' then
            x, y = center_x + (y - center_y), center_y - (x - center_x)
        elseif val == 'fliph' then
            x = center_x - (x - center_x)
        elseif val == 'flipv' then
            y = center_y - (y - center_y)
        end
        self.marks[i] = { x = math.floor(x + 0.5), y = math.floor(y + 0.5), z = self.marks[i].z }
    end

    -- Transform extra points
    for i, point in ipairs(self.extra_points) do
        local x, y = point.x, point.y
        if val == 'cw' then
            x, y = center_x - (y - center_y), center_y + (x - center_x)
        elseif val == 'ccw' then
            x, y = center_x + (y - center_y), center_y - (x - center_x)
        elseif val == 'fliph' then
            x = center_x - (x - center_x)
        elseif val == 'flipv' then
            y = center_y - (y - center_y)
        end
        self.extra_points[i] = { x = math.floor(x + 0.5), y = math.floor(y + 0.5), z = self.extra_points[i].z }
    end

    -- Calculate center point after transformation
    self.shape:update(self.marks, self.extra_points)
    local new_center_x, new_center_y = self.shape:get_center()

    -- Calculate delta between old and new center points
    local delta_x = center_x - new_center_x
    local delta_y = center_y - new_center_y

    -- Adjust marks and extra points based on delta
    for i, mark in ipairs(self.marks) do
        self.marks[i].x = self.marks[i].x + delta_x
        self.marks[i].y = self.marks[i].y + delta_y
    end
    for i, point in ipairs(self.extra_points) do
        self.extra_points[i].x = self.extra_points[i].x + delta_x
        self.extra_points[i].y = self.extra_points[i].y + delta_y
    end

    self:updateLayout()
    self.needs_update = true
end

function Dig:get_view_bounds()
    if #self.marks == 0 then return nil end

    local min_x = self.marks[1].x
    local max_x = self.marks[1].x
    local min_y = self.marks[1].y
    local max_y = self.marks[1].y
    local min_z = self.marks[1].z
    local max_z = self.marks[1].z

    local marks_plus_next = copyall(self.marks)
    local mouse_pos = dfhack.gui.getMousePos()
    if mouse_pos then
        table.insert(marks_plus_next, mouse_pos)
    end

    for _, mark in ipairs(marks_plus_next) do
        min_x = math.min(min_x, mark.x)
        max_x = math.max(max_x, mark.x)
        min_y = math.min(min_y, mark.y)
        max_y = math.max(max_y, mark.y)
        min_z = math.min(min_z, mark.z)
        max_z = math.max(max_z, mark.z)
    end

    return { x1 = min_x, y1 = min_y, z1 = min_z, x2 = max_x, y2 = max_y, z2 = max_z }
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
    if is_corner then ret = ret + (1 << PEN_MASK.DRAG_POINT) end
    if is_mouse_over then ret = ret + (1 << PEN_MASK.MOUSEOVER) end
    if inshape then ret = ret + (1 << PEN_MASK.INSHAPE) end
    if extra_point then ret = ret + (1 << PEN_MASK.EXTRA_POINT) end

    return ret
end

-- TODO Function is too long
function Dig:onRenderFrame(dc, rect)

    if (SHOW_DEBUG_WINDOW) then
        self.parent_view.debug_window:updateLayout()
    end

    Dig.super.onRenderFrame(self, dc, rect)

    if not self.shape then
        self.shape = shapes.all_shapes[self.subviews.shape_name:getOptionValue()]
    end

    local mouse_pos = dfhack.gui.getMousePos()

    self.subviews.marks_panel:update_mark_labels()

    local function get_overlay_pen(pos)
        return self:get_pen(pos.x, pos.y, mouse_pos)
    end

    if self.placing_mark.active and self.placing_mark.index then
        self.marks[self.placing_mark.index] = mouse_pos
    end

    -- Set main points
    local points = copyall(self.marks)

    -- Set the pos of the currently moving extra point
    if self.placing_extra.active then
        self.extra_points[self.placing_extra.index] = { x = mouse_pos.x, y = mouse_pos.y }
    end

    if self.placing_mirror and mouse_pos then
        if not self.mirror_point or (mouse_pos.x ~= self.mirror_point.x or mouse_pos.y ~= self.mirror_point.y) then
            self.needs_update = true
        end
        self.mirror_point = mouse_pos
    end

    -- Check if moving center, if so shift the shape by the delta between the previous and current points
    if self.prev_center and
        (self.shape.basic_shape and #self.marks == self.shape.max_points
            or not self.shape.basic_shape and not self.placing_mark.active) then
        if mouse_pos and (self.prev_center.x ~= mouse_pos.x or self.prev_center.y ~= mouse_pos.y or
            self.prev_center.z ~= mouse_pos.z) then
            self.needs_update = true
            local transform = { x = mouse_pos.x - self.prev_center.x, y = mouse_pos.y - self.prev_center.y,
                z = mouse_pos.z - self.prev_center.z }

            for i, _ in ipairs(self.marks) do
                self.marks[i].x = self.marks[i].x + transform.x
                self.marks[i].y = self.marks[i].y + transform.y
                self.marks[i].z = self.marks[i].z + transform.z
            end

            for i, point in ipairs(self.extra_points) do
                self.extra_points[i].x = self.extra_points[i].x + transform.x
                self.extra_points[i].y = self.extra_points[i].y + transform.y
            end

            if self.mirror_point then
                self.mirror_point.x = self.mirror_point.x + transform.x
                self.mirror_point.y = self.mirror_point.y + transform.y
            end

            self.prev_center = mouse_pos
        end
    end

    if self.mirror_point then
        points = self:get_mirrored_points(points)
    end

    if self:shape_needs_update() then
        self.shape:update(points, self.extra_points)
        self.last_mouse_point = mouse_pos
        self.needs_update = false
    end

    self:add_shape_options()

    -- Generate bounds based on the shape's dimensions
    local bounds = self:get_view_bounds()
    if self.shape and bounds then
        local top_left, bot_right = self.shape:get_view_dims(self.extra_points, self.mirror_point)
        if not top_left or not bot_right then return end
        bounds.x1 = top_left.x
        bounds.x2 = bot_right.x
        bounds.y1 = top_left.y
        bounds.y2 = bot_right.y
    end

    -- Show mouse guidelines
    if self.show_guides and mouse_pos then
        local map_x, map_y, map_z = dfhack.maps.getTileSize()
        local horiz_bounds = { x1 = 0, x2 = map_x, y1 = mouse_pos.y, y2 = mouse_pos.y, z1 = mouse_pos.z, z2 = mouse_pos.z }
        guidm.renderMapOverlay(function() return guide_tile_pen end, horiz_bounds)
        local vert_bounds = { x1 = mouse_pos.x, x2 = mouse_pos.x, y1 = 0, y2 = map_y, z1 = mouse_pos.z, z2 = mouse_pos.z }
        guidm.renderMapOverlay(function() return guide_tile_pen end, vert_bounds)
    end

    -- Show Mirror guidelines
    if self.mirror_point then
        local mirror_horiz_value = self.subviews.mirror_horiz_label:getOptionValue()
        local mirror_diag_value = self.subviews.mirror_diag_label:getOptionValue()
        local mirror_vert_value = self.subviews.mirror_vert_label:getOptionValue()

        local map_x, map_y, _ = dfhack.maps.getTileSize()

        if mirror_horiz_value ~= 1 or mirror_diag_value ~= 1 then
            local horiz_bounds = {
                x1 = 0, x2 = map_x,
                y1 = self.mirror_point.y, y2 = self.mirror_point.y,
                z1 = self.mirror_point.z, z2 = self.mirror_point.z
            }
            guidm.renderMapOverlay(function() return mirror_guide_pen end, horiz_bounds)
        end

        if mirror_vert_value ~= 1 or mirror_diag_value ~= 1 then
            local vert_bounds = {
                x1 = self.mirror_point.x, x2 = self.mirror_point.x,
                y1 = 0, y2 = map_y,
                z1 = self.mirror_point.z, z2 = self.mirror_point.z
            }
            guidm.renderMapOverlay(function() return mirror_guide_pen end, vert_bounds)
        end
    end

    guidm.renderMapOverlay(get_overlay_pen, bounds)

    self:updateLayout()
end

-- TODO function too long
function Dig:onInput(keys)
    if Dig.super.onInput(self, keys) then
        return true
    end

    -- Secret shortcut to kill the panel if it becomes
    -- unresponsive during development, should not release
    -- if keys.CUSTOM_M then
    --     self.parent_view:dismiss()
    --     return
    -- end

    if keys.LEAVESCREEN or keys._MOUSE_R_DOWN then
        -- If center draggin, put the shape back to the original center
        if self.prev_center then
            local transform = { x = self.start_center.x - self.prev_center.x,
                y = self.start_center.y - self.prev_center.y,
                z = self.start_center.z - self.prev_center.z }

            for i, _ in ipairs(self.marks) do
                self.marks[i].x = self.marks[i].x + transform.x
                self.marks[i].y = self.marks[i].y + transform.y
                self.marks[i].z = self.marks[i].z + transform.z
            end

            for i, point in ipairs(self.extra_points) do
                self.extra_points[i].x = self.extra_points[i].x + transform.x
                self.extra_points[i].y = self.extra_points[i].y + transform.y
            end

            self.prev_center = nil
            self.start_center = nil
            self.needs_update = true
            return true
        end -- TODO

        -- If extra points, clear them and return
        if self.shape then
            if #self.extra_points > 0 or self.placing_extra.active then
                self.extra_points = {}
                self.placing_extra.active = false
                self.prev_center = nil
                self.start_center = nil
                self.placing_extra.index = 0
                self.needs_update = true
                self:updateLayout()
                return true
            end
        end

        -- If marks are present, pop the last mark
        if #self.marks > 1 then
            self.placing_mark.index = #self.marks - ((self.placing_mark.active) and 1 or 0)
            self.placing_mark.active = true
            self.needs_update = true
            table.remove(self.marks, #self.marks)
        else
            -- nothing left to remove, so dismiss
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
        -- TODO Refactor this a bit
        if self.shape.max_points and #self.marks == self.shape.max_points and self.placing_mark.active then
            self.marks[self.placing_mark.index] = pos
            self.placing_mark.index = self.placing_mark.index + 1
            self.placing_mark.active = false
            -- The statement after the or is to allow the 1x1 special case for easy doorways
            self.needs_update = true
            if self.autocommit or (same_xy(self.marks[1], self.marks[2])) then
                self:commit()
            end
        elseif not self.placing_extra.active and self.placing_mark.active then
            self.marks[self.placing_mark.index] = pos
            if self.placing_mark.continue then
                self.placing_mark.index = self.placing_mark.index + 1
            else
                self.placing_mark.index = nil
                self.placing_mark.active = false
            end
            self.needs_update = true
        elseif self.placing_extra.active then
            self.needs_update = true
            self.placing_extra.active = false
        elseif self.placing_mirror then
            self.mirror_point = pos
            self.placing_mirror = false
            self.needs_update = true
        else
            if self.shape.basic_shape and #self.marks == self.shape.max_points then
                -- Clicking a corner of a basic shape
                local shape_top_left, shape_bot_right = self.shape:get_point_dims()
                local corner_drag_info = {
                    { pos = shape_top_left, opposite_x = shape_bot_right.x, opposite_y = shape_bot_right.y, corner = "nw" },
                    { pos = xy2pos(shape_bot_right.x, shape_top_left.y), opposite_x = shape_top_left.x,
                        opposite_y = shape_bot_right.y, corner = "ne" },
                    { pos = xy2pos(shape_top_left.x, shape_bot_right.y), opposite_x = shape_bot_right.x,
                        opposite_y = shape_top_left.y, corner = "sw" },
                    { pos = shape_bot_right, opposite_x = shape_top_left.x, opposite_y = shape_top_left.y, corner = "se" }
                }

                for _, info in ipairs(corner_drag_info) do
                    if same_xy(pos, info.pos) and self.shape.drag_corners[info.corner] then
                        self.marks[1] = xyz2pos(info.opposite_x, info.opposite_y, self.marks[1].z)
                        table.remove(self.marks, 2)
                        self.placing_mark = { active = true, index = 2 }
                        break
                    end
                end
            else
                for i, point in ipairs(self.marks) do
                    if same_xy(pos, point) then
                        self.placing_mark = { active = true, index = i, continue = false }
                    end
                end
            end

            -- Clicking an extra point
            for i = 1, #self.extra_points do
                if same_xy(pos, self.extra_points[i]) then
                    self.placing_extra = { active = true, index = i }
                    self.needs_update = true
                    return true
                end
            end

            -- Clicking center point
            if #self.marks > 0 then
                local center_x, center_y = self.shape:get_center()
                if same_xy(pos, xy2pos(center_x, center_y)) and not self.prev_center then
                    self.start_center = pos
                    self.prev_center = pos
                    return true
                elseif self.prev_center then
                    self.start_center = nil
                    self.prev_center = nil
                    return true
                end
            end

            if same_xy(self.mirror_point, pos) then
                self.placing_mirror = true
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
        elseif view_bounds and z == math.abs(view_bounds.z1 - view_bounds.z2) then
            local pos = xyz2pos(view_bounds.x1 + x, view_bounds.y1 + y, view_bounds.z1 + z)
            local tile_type = dfhack.maps.getTileType(pos)
            local tile_shape = tile_type and tile_attrs[tile_type].shape or nil
            local designation = dfhack.maps.getTileFlags(pos)

            -- If top of the view_bounds is down stair, 'auto' should change it to up/down to match vanilla stair logic
            local up_or_updown_dug = (
                tile_shape == df.tiletype_shape.STAIR_DOWN or tile_shape == df.tiletype_shape.STAIR_UPDOWN)
            local up_or_updown_desig = designation and (designation.dig == df.tile_dig_designation.UpStair or
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

    -- Means mo marks set
    if not view_bounds then return end

    -- Generates the params for quickfort API
    local function generate_params(grid, position)
        -- local top_left, bot_right = self.shape:get_true_dims()
        for zlevel = 0, math.abs(view_bounds.z1 - view_bounds.z2) do
            data[zlevel] = {}
            for row = 0, math.abs(bot_right.y - top_left.y) do
                data[zlevel][row] = {}
                for col = 0, math.abs(bot_right.x - top_left.x) do
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

    -- Special case for 1x1 to ease doorway marking
    if same_xy(top_left, bot_right) then
        grid = {}
        grid[0] = {}
        grid[0][0] = true
    end

    local params = generate_params(grid, start)
    quickfort.apply_blueprint(params)

    -- Only clear points if we're autocommit, or if we're doing a complex shape and still placing
    if (self.autocommit and self.shape.basic_shape) or
        (not self.shape.basic_shape and
            (self.placing_mark.active or (self.autocommit and self.shape.max_points == #self.marks))) then
        self.marks = {}
        self.placing_mark = { active = true, index = 1, continue = true }
        self.placing_extra = { active = false, index = nil }
        self.extra_points = {}
        self.prev_center = nil
        self.start_center = nil
    end

    self:updateLayout()
end

function Dig:get_mirrored_points(points)
    local mirrored_points = {}
    for i, point in ipairs(points) do
        local mirror_horiz_value = self.subviews.mirror_horiz_label:getOptionValue()
        local mirror_diag_value = self.subviews.mirror_diag_label:getOptionValue()
        local mirror_vert_value = self.subviews.mirror_vert_label:getOptionValue()

        -- 1 maps to "Off"
        if mirror_horiz_value ~= 1 then
            local mirrored_y = self.mirror_point.y + ((self.mirror_point.y - point.y))

            -- if Mirror (even), then increase mirror amount by 1
            if mirror_horiz_value == 3 then
                if mirrored_y > self.mirror_point.y then
                    mirrored_y = mirrored_y + 1
                else
                    mirrored_y = mirrored_y - 1
                end
            end

            table.insert(mirrored_points, { z = point.z, x = point.x, y = mirrored_y })
        end
        if mirror_diag_value ~= 1 then
            local mirrored_y = self.mirror_point.y + ((self.mirror_point.y - point.y))
            local mirrored_x = self.mirror_point.x + ((self.mirror_point.x - point.x))

            -- if Mirror (even), then increase mirror amount by 1
            if mirror_diag_value == 3 then
                if mirrored_y > self.mirror_point.y then
                    mirrored_y = mirrored_y + 1
                    mirrored_x = mirrored_x + 1
                else
                    mirrored_y = mirrored_y - 1
                    mirrored_x = mirrored_x - 1
                end
            end

            table.insert(mirrored_points, { z = point.z, x = mirrored_x, y = mirrored_y })
        end
        if mirror_vert_value ~= 1 then
            local mirrored_x = self.mirror_point.x + ((self.mirror_point.x - point.x))

            -- if Mirror (even), then increase mirror amount by 1
            if mirror_vert_value == 3 then
                if mirrored_x > self.mirror_point.x then
                    mirrored_x = mirrored_x + 1
                else
                    mirrored_x = mirrored_x - 1
                end
            end

            table.insert(mirrored_points, { z = point.z, x = mirrored_x, y = point.y })
        end
    end

    for i, point in ipairs(mirrored_points) do
        table.insert(points, mirrored_points[i])
    end

    -- Sorts the points by angle relative to the mirror point to connect points sequentially
    -- TODO, this whole thing can probably be avoided by connecting the points better beforehand
    table.sort(points, function(a, b)
        local atan_a = math.atan(a.y - self.mirror_point.y, a.x - self.mirror_point.x)
        local atan_b = math.atan(b.y - self.mirror_point.y, b.x - self.mirror_point.x)
        return atan_a < atan_b
    end)

    return points
end

--
-- DigScreen
--

DigScreen = defclass(DigScreen, gui.ZScreen)
DigScreen.ATTRS {
    focus_path = "dig",
    pass_pause = true,
    pass_movement_keys = true,
    dig_window = DEFAULT_NIL,
    debug_window = DEFAULT_NIL
}

function DigScreen:init()

    self.dig_window = Dig {}
    self:addviews { self.dig_window }
    if SHOW_DEBUG_WINDOW then
        self.debug_window = DigDebugWindow { dig_window = self.dig_window }
        self:addviews { self.debug_window }
    end
    -- self:addviews { Dig {} }
end

function DigScreen:onDismiss()
    view = nil
end

if dfhack_flags.module then return end

if not dfhack.isMapLoaded() then
    qerror("This script requires a fortress map to be loaded")
end

view = view and view:raise() or DigScreen {}:show()
