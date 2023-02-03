-- A GUI front-end for the digging designations
--@ module = false

-- TODOS ====================


-- Must Haves
-----------------------------
-- Figure out why pause/unpause doesn't work
-- Line 'shape' between two points with thickness (currently tricky with how shapes are defined as within bounds rectangle)
--   A totally vertical line with thickness of e.g. 3 would end up with tiles outside the bounds/view rectangle
--   Could also allow 'multi-point' line that would produce curves
-- Need to support classic mode? Might just be double checking non-graphics 'pen' settings

-- Should Haves
-----------------------------
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
-- Add logic to set thickness.max for applicable shapes based on dimensions
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
    get_mark_fn = DEFAULT_NIL,
    is_setting_start_pos_fn = DEFAULT_NIL,
    autoarrange_subviews = true,
}

function ActionPanel:init()
    self:addviews { widgets.WrappedLabel {
        view_id = "action_label",
        text_to_wrap = self:callback("get_action_text"),
    },
        widgets.TooltipLabel {
            view_id = "selected_area",
            indent = 1,
            text = { { text = self:callback("get_area_text") } },
            show_tooltip = self.get_mark_fn,
        } }
end

function ActionPanel:get_action_text()
    local text = "Select the "
    if self.get_mark_fn() then
        text = text .. "second corner"
    else
        text = text .. "first corner"
    end
    return text .. " with the mouse."
end

function ActionPanel:get_area_text()
    local mark = self.get_mark_fn()
    if not mark then
        return ""
    end
    local other = dfhack.gui.getMousePos() or {
        x = mark.x,
        y = mark.y,
        z = df.global.window_z,
    }
    local width, height, depth = get_dims(mark, other)
    local tiles = width * height * depth
    local plural = tiles > 1 and "s" or ""
    return ("%dx%dx%d (%d tile%s) mark: %d, %d, %d"):format(
        width,
        height,
        depth,
        tiles,
        plural,
        other.x,
        other.y,
        other.z
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

    self:addviews { widgets.WrappedLabel {
        view_id = "settings_label",
        text_to_wrap = "General Settings:\n",
    },
        widgets.CycleHotkeyLabel {
            view_id = "shape_name",
            key = "CUSTOM_E",
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
            enabled = true,
            disabled = false,
            show_tooltip = true,
            initial_option = false,
            on_change = function(new, old)
                self.dig_panel.shape.invert = new
                self.dig_panel.dirty = true
            end,
        },
        widgets.CycleHotkeyLabel {
            view_id = "mode_name",
            key = "CUSTOM_F",
            label = "Mode: ",
            label_width = 8,
            active = true,
            enabled = true,
            options = { {
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
                } },
            disabled = false,
            show_tooltip = true,
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
                self.dig_panel.dirty = true
            end,
        },
        widgets.HotkeyLabel {
            view_id = "commit_label",
            key = "CUSTOM_CTRL_C",
            label = "Commit Designation",
            active = true,
            enabled = function()
                return self.dig_panel.saved_cursor and self.dig_panel.mark
            end,
            disabled = false,
            show_tooltip = true,
            on_activate = function()
                self.dig_panel:commit()
            end,
        } }
end

function GenericOptionsPanel:change_shape(new, old)
    self.dig_panel.shape = shapes.all_shapes[new]
    self.dig_panel:add_shape_options()
    self.dig_panel:updateLayout()
end

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
    resize_min = { h = 10 },
    autoarrange_subviews = true,
    autoarrange_gap = 1,
    presets = DEFAULT_NIL,
    shape = DEFAULT_NIL,
    dirty = true,
    prio = 4,
    autocommit = true,
    cur_shape = 1,
}

function Dig:init()
    self:addviews { ActionPanel {
        view_id = "action_panel",
        get_mark_fn = function()
            return self.mark
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
    if self.subviews ~= nil then
        for i, view in ipairs(self.subviews) do
            if string.sub(view.view_id, 1, string.len(prefix)) == prefix then
                self.subviews[i] = nil
            end
        end
    end
    if self.shape then
        if self.shape.options ~= nil then
            self:addviews { widgets.WrappedLabel {
                view_id = "shape_option_label",
                text_to_wrap = "Shape Settings:\n",
            } }

            for key, option in pairs(self.shape.options) do
                if option.type == "bool" then
                    self:addviews { widgets.ToggleHotkeyLabel {
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
                            self.dirty = true
                        end,
                    } }
                elseif option.type == "plusminus" then
                    self:addviews { widgets.HotkeyLabel {
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
                            return self.shape.options[key].min == nil or
                                (self.shape.options[key].value > self.shape.options[key].min)
                        end,
                        disabled = false,
                        show_tooltip = true,
                        on_activate = function()
                            self.shape.options[key].value =
                            self.shape.options[key].value - 1
                            self.dirty = true
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
                                return self.shape.options[key].max == nil or
                                    (self.shape.options[key].value <= self.shape.options[key].max)
                            end,
                            disabled = false,
                            show_tooltip = true,
                            on_activate = function()
                                self.shape.options[key].value =
                                self.shape.options[key].value + 1
                                self.dirty = true
                            end,
                        } }
                end
            end
        end
    end
end

function Dig:save_cursor_pos()
    self.saved_cursor = copyall(df.global.cursor)
end

function Dig:on_mark(pos)
    self.mark = pos
    self:updateLayout()
end

function Dig:get_bounds()
    local cur = self.saved_cursor or dfhack.gui.getMousePos()
    if not cur then return end
    local mark = self.mark or cur

    return {
        x1 = math.min(cur.x, mark.x),
        x2 = math.max(cur.x, mark.x),
        y1 = math.min(cur.y, mark.y),
        y2 = math.max(cur.y, mark.y),
        z1 = math.min(cur.z, mark.z),
        z2 = math.max(cur.z, mark.z),
    }
end

function Dig:onRenderFrame(dc, rect)
    Dig.super.onRenderFrame(self, dc, rect)
    if self.shape == nil then
        self.shape =
        shapes.all_shapes[self.subviews.shape_name:getOptionValue()]
    end

    local bounds = self:get_bounds()
    if bounds and self.mark then
        
        local function get_overlay_pen(pos)
            -- Check if we need to update the shape dimensions. Either there isn't a shape, we've marked it dirty, or the bounds have changed
            if self.dirty or (pos.x >= bounds.x1 and pos.x <= bounds.x2 and pos.y >= bounds.y1 and pos.y <= bounds.y2) then
                if not self.shape or self.dirty or
                    (bounds.x2 - bounds.x1 ~= self.shape.width or bounds.y2 - bounds.y1 ~= self.shape.height) then
                    self.shape:update(
                        bounds.x2 - bounds.x1,
                        bounds.y2 - bounds.y1
                    )
                    self.dirty = false
                end

                local mouse_pos = dfhack.gui.getMousePos()
                if mouse_pos ~= nil then
                    mouse_pos.x = mouse_pos.x - bounds.x1
                    mouse_pos.y = mouse_pos.y - bounds.y1
                end
                
                -- Get the pen from the base Shape class based on if the point is in the shape or not
                -- Send mouse position for stuff like corner anchor mouse over, etc...
                return self.shape:get_pen(
                    pos.x - bounds.x1,
                    pos.y - bounds.y1,
                    mouse_pos
                )
            else
                return nil
            end
        end

        guidm.renderMapOverlay(get_overlay_pen, bounds)
    end
end

function Dig:onInput(keys)
    if Dig.super.onInput(self, keys) then
        return true
    end

    if keys.LEAVESCREEN or keys._MOUSE_R_DOWN then
        if self.mark then
            self.mark = nil
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
        if self.mark and not self.saved_cursor then
            self.saved_cursor = pos
            -- The statement after the or is to allow the 1x1 special case for easy doors
            if self.autocommit or (self.mark.x == self.saved_cursor and self.mark.y == self.saved_cursor.y) then
                self:commit()
            end
        elseif not self.mark then
            self:on_mark(pos)
        else
            -- These check if the user is trying to change a non-commited shape
            -- by clicking and dragging the corner anchors. Basically just flips the
            -- marks around by setting the mark to the opposite corner
            if pos.x == self:get_bounds().x1 and pos.y == self:get_bounds().y1 then
                self.mark =
                xyz2pos(
                    self:get_bounds().x2,
                    self:get_bounds().y2,
                    self.mark.z
                )
            elseif pos.x == self:get_bounds().x2 and pos.y == self:get_bounds().y1 then
                self.mark =
                xyz2pos(
                    self:get_bounds().x1,
                    self:get_bounds().y2,
                    self.mark.z
                )
            elseif pos.x == self:get_bounds().x1 and pos.y == self:get_bounds().y2 then
                self.mark =
                xyz2pos(
                    self:get_bounds().x2,
                    self:get_bounds().y1,
                    self.mark.z
                )
            elseif pos.x == self:get_bounds().x2 and pos.y == self:get_bounds().y2 then
                self.mark =
                xyz2pos(
                    self:get_bounds().x1,
                    self:get_bounds().y1,
                    self.mark.z
                )
            end

            self.saved_cursor = nil
        end

        return true
    end

    -- send movement keys through, but otherwise we're a modal dialog
    return not guidm.getMapKey(keys)
end

-- Commit the shape using quickfort API
function Dig:commit()
    local data = {}

    -- Put any special logic for designation type here
    -- Right now it's setting the stair type based on the z-level
    function getDesignation(x, y, z)
        
        -- Nice stairs
        if self.subviews.mode_name:getOptionValue() == "i" then
            if math.abs(self:get_bounds().z1 - self:get_bounds().z2) == 0 then
                return "`" -- return nothing, they need to specify more than one z-level
            end
            if z == 0 then
                return "u" -- up stair
            elseif z == math.abs(
                self:get_bounds().z1 - self:get_bounds().z2
            ) then
                return "j" -- down stair
            else
                return "i" -- up/down stair
            end
        end

        -- Fell through, pass through the option directly from the options value
        return self.subviews.mode_name:getOptionValue()
    end

    -- Generates the params for quickfort API
    local function generate_params(grid, position)
        for zlevel = 0, math.abs(self:get_bounds().z1 - self:get_bounds().z2) do
            data[zlevel] = {}
            for row = 0, math.abs(
                self:get_bounds().y1 - self:get_bounds().y2
            ) do
                data[zlevel][row] = {}
                for col = 0, math.abs(
                    self:get_bounds().x1 - self:get_bounds().x2
                ) do
                    if grid[col][row] then
                        local desig = getDesignation(col, row, zlevel)
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

    local bounds = self:get_bounds()
    local start = {
        x = bounds.x1,
        y = bounds.y1,
        z = math.min(bounds.z1, bounds.z2),
    }
    local grid = self.shape.arr

    -- Special case for 1x1 to ease doorway marking
    if bounds.x1 == bounds.x2 and bounds.y1 == bounds.y2 then
        grid = {}
        grid[0] = {}
        grid[0][0] = true
    end

    local params = generate_params(grid, start)
    quickfort.apply_blueprint(params)
    self.mark = nil
    self.saved_cursor = nil
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
    presets = DEFAULT_NIL,
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
