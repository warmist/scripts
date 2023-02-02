-- A GUI front-end for the dig plugin
--@ module = true

-- local plugin = require('plugins.dig')
local dialogs = require('gui.dialogs')
local gui = require('gui')
local guidm = require('gui.dwarfmode')
local utils = require('utils')
local widgets = require('gui.widgets')
local quickfort = reqscript('quickfort')
local shapes = reqscript('internal/dig/shapes')

reload('gui.dwarfmode') -- TODO remove

local function get_dims(pos1, pos2)
    local width, height, depth = math.abs(pos1.x - pos2.x) + 1,
        math.abs(pos1.y - pos2.y) + 1,
        math.abs(pos1.z - pos2.z) + 1
    return width, height, depth
end

ActionPanel = defclass(ActionPanel, widgets.ResizingPanel)
ActionPanel.ATTRS {
    get_mark_fn = DEFAULT_NIL,
    is_setting_start_pos_fn = DEFAULT_NIL,
    autoarrange_subviews = true,
}
function ActionPanel:init()
    self:addviews {
        widgets.WrappedLabel {
            view_id = 'action_label',
            text_to_wrap = self:callback('get_action_text')
        },
        widgets.TooltipLabel {
            view_id = 'selected_area',
            indent = 1,
            text = { { text = self:callback('get_area_text') } },
            show_tooltip = self.get_mark_fn
        }
    }
end

function ActionPanel:get_action_text()
    local text = 'Select the '
    if self.get_mark_fn() then
        text = text .. 'second corner'
    else
        text = text .. 'first corner'
    end
    return text .. ' with the mouse.'
end

function ActionPanel:get_area_text()
    local mark = self.get_mark_fn()
    if not mark then return '' end
    local other = dfhack.gui.getMousePos()
        or { x = mark.x, y = mark.y, z = df.global.window_z }
    local width, height, depth = get_dims(mark, other)
    local tiles = width * height * depth
    local plural = tiles > 1 and 's' or ''
    return ('%dx%dx%d (%d tile%s) mark: %d, %d, %d'):format(width, height, depth, tiles, plural, other.x, other.y,
        other.z)
end

NamePanel = defclass(NamePanel, widgets.ResizingPanel)
NamePanel.ATTRS {
    name = DEFAULT_NIL,
    autoarrange_subviews = true,
    dig_panel = DEFAULT_NIL,
    on_layout_change = DEFAULT_NIL,
}
function NamePanel:init()
    self:addviews {
        widgets.CycleHotkeyLabel {
            view_id = 'shape_name',
            key = 'CUSTOM_P',
            label = "Shape: ",
            active=true,
            enabled=true,
            options = {{label = shapes.all_shapes[1]{}.name, value = 1}, {label = shapes.all_shapes[2]{}.name, value = 2}},
            disabled = false, -- function() return self.has_name_collision end,
            show_tooltip = true,
            initial_option = 1,
            on_change = self:callback('change_shape')
        },
    }

end

function NamePanel:change_shape(new, old)
    self.dig_panel.shape = shapes.all_shapes[new]{}
    self:updateLayout()
end

--
-- Dig
--

Dig = defclass(Dig, widgets.Window)
Dig.ATTRS {
    frame_title = 'Dig',
    frame = { w = 47, h = 40, r = 2, t = 18 },
    resizable = true,
    resize_min = { h = 10 },
    autoarrange_subviews = true,
    autoarrange_gap = 1,
    presets = DEFAULT_NIL,
    shape = DEFAULT_NIL,
}

function Dig:preinit(info)
    if not info.presets then
        local presets = {}
        -- plugin.parse_gui_commandline(presets, {})
        info.presets = presets
    end
end

function Dig:init()
    self:addviews {
        ActionPanel {
            get_mark_fn = function() return self.mark end,
            is_setting_start_pos_fn = self:callback('is_setting_start_pos'),
            },

            NamePanel {
            view_id='name_panel',
                dig_panel = self
                -- on_layout_change=self:callback('updateLayout')
            },
        }
end

function Dig:onShow()
    Dig.super.onShow(self)
    local start = self.presets.start
    if not start or not dfhack.maps.isValidTilePos(start) then
        return
    end
    guidm.setCursorPos(start)
    dfhack.gui.revealInDwarfmodeMap(start, true)
    self:on_mark(start)
end

function Dig:save_cursor_pos()
    self.saved_cursor = copyall(df.global.cursor)
end

function Dig:is_setting_start_pos()
    -- return self.subviews.startpos:getOptionLabel() == 'Setting'
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
        z2 = math.max(cur.z, mark.z)
    }
end

function Dig:onRenderFrame(dc, rect)
    Dig.super.onRenderFrame(self, dc, rect)
    if self.shape == nil then self.shape = shapes.all_shapes[self.subviews.shape_name:getOptionValue()]{} end

    if not dfhack.screen.inGraphicsMode() and not gui.blink_visible(500) then
        return
    end

    local bounds = self:get_bounds()
    if bounds and self.mark then
        local function get_overlay_pen(pos)
            if pos.x >= bounds.x1 and pos.x <= bounds.x2 and pos.y >= bounds.y1 and pos.y <= bounds.y2 then
                if not self.shape or
                    (bounds.x2 - bounds.x1 ~= self.shape.width or bounds.y2 - bounds.y1 ~= self.shape.height) then
                    self.shape:update(bounds.x2 - bounds.x1, bounds.y2 - bounds.y1)
                end
                return self.shape:getPen(pos.x - bounds.x1, pos.y - bounds.y1)
            else
                return nil
            end
        end

        guidm.renderMapOverlay(get_overlay_pen, bounds)
    end
end

function Dig:onInput(keys)
    if Dig.super.onInput(self, keys) then return true end

    if keys.LEAVESCREEN or keys._MOUSE_R_DOWN then
        if self:is_setting_start_pos() then
            self.subviews.startpos.option_idx = 1
            self.saved_cursor = nil
            self:updateLayout()
        elseif self.mark then
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

    if pos then
        if self:is_setting_start_pos() then
            self.subviews.startpos:cycle()
            guidm.setCursorPos(self.saved_cursor)
            self.saved_cursor = nil
        elseif self.mark then
            self.saved_cursor = pos
            self:commit(pos)
        else
            self:on_mark(pos)
        end
        return true
    end

    -- send movement keys through, but otherwise we're a modal dialog
    return not guidm.getMapKey(keys)
end

-- assemble and execute the Dig commandline
function Dig:commit(pos)
    local mark = self.mark
    local width, height, depth = get_dims(mark, pos)
    if depth > 1 then
        -- when there are multiple levels, process them top to bottom
        depth = -depth
    end

    -- set cursor to top left corner of the *uppermost* z-level
    local bounds = self:get_bounds()
    local data = {}
    local function generate_params(grid, position)
        print(position.x, position.y, position.z)
        for zlevel = 0, math.abs(self:get_bounds().z1 - self:get_bounds().z2) do
            data[zlevel] = {}
            for row = 0, math.abs(self:get_bounds().y1 - self:get_bounds().y2) do
                data[zlevel][row] = {}
                for col = 0, math.abs(self:get_bounds().x1 - self:get_bounds().x2) do
                    if grid[col][row] then
                        data[zlevel][row][col] = "d(1x1)"
                    end
                end
            end
        end
        return { data = data, pos = position, mode = "dig" }
    end

    local bounds = self:get_bounds()
    local start = { x = bounds.x1, y = bounds.y1, z = math.min(bounds.z1, bounds.z2) }
    local params = generate_params(self.shape.arr, start)
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
    focus_path = 'dig',
    force_pause = true,
    pass_pause = false,
    pass_movement_keys = true,
    pass_mouse_clicks = false,
    presets = DEFAULT_NIL,
}

function DigScreen:init()
    self.saved_pause_state = df.global.pause_state
    df.global.pause_state = true
    self:addviews { Dig {} }
end

function DigScreen:onDismiss()
    view = nil
    df.global.pause_state = self.saved_pause_state
end

if dfhack_flags.module then
    return
end

if not dfhack.isMapLoaded() then
    qerror('This script requires a fortress map to be loaded')
end

-- local options, args = {}, {...}
-- local ok, err = dfhack.pcall(plugin.parse_gui_commandline, options, args)
-- if not ok then
--     dfhack.printerr(tostring(err))
--     options.help = true
-- end

-- if options.help then
--     print(dfhack.script_help())
--     return
-- end

view = view and view:raise() or DigScreen { presets = options }:show()
