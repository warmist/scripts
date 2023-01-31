-- A GUI front-end for the dig plugin
--@ module = true

-- local plugin = require('plugins.dig')
local dialogs = require('gui.dialogs')
local gui = require('gui')
local guidm = require('gui.dwarfmode')
local utils = require('utils')
local widgets = require('gui.widgets')

reload('gui.dwarfmode')

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
    if self.is_setting_start_pos_fn() then
        text = text .. 'playback start'
    elseif self.get_mark_fn() then
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
    return ('%dx%dx%d (%d tile%s)'):format(width, height, depth, tiles, plural)
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
            is_setting_start_pos_fn = self:callback('is_setting_start_pos')
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

local to_pen = dfhack.pen.parse
local PENS = {
    CORNER = { 5, 22 },
    INSIDE = { 1, 2 },
    NORTH = { 1, 1 },
    N_NUB = { 3, 2 },
    NE = { 2, 1 },
    NW = { 0, 1 },
    WEST = { 1, 2 },
    EAST = { 2, 2 },
    SW = { 0, 3 },
    SOUTH = { 1, 3 },
    SE = { 2, 3 }
}

function getpen(direction)
    return to_pen { ch = 'X', fg = COLOR_GREEN,
        tile = dfhack.screen.findGraphicsTile('CURSORS', direction[1], direction[2]) }
end


Shape = defclass(Shape)
Shape.ATTRS {
    mark_corners = true,
    mark_center = true,
    arr = {}
}
function Shape:init()
    print("Creating shape")
    self.arr = {}
end

function Shape:update(width, height)
    print("Updating shape")
    self.width = width
    self.height = height
    self.arr = {}
    for x = 0, self.width do
        self.arr[x] = {}
        for y = 0, self.height do
            self.arr[x][y] = self:hasPoint(x, y)
        end
    end
end

function Shape:hasPoint(x, y)
    local center_x, center_y = self.width / 2, self.height / 2
    local point_x, point_y = x - center_x, y - center_y
    if (point_x / (self.width / 2)) ^ 2 + (point_y / (self.height / 2)) ^ 2 <= 1 then
        return true
    else
        return false
    end
end

function Shape:getPen(x, y)
    if self.arr[x][y] == true then
        return getpen(PENS.INSIDE)
    elseif (x == 0 and y == 0) or (x == #self.arr and y == 0) or (x == 0 and y == #self.arr[x]) or (x == #self.arr and y == #self.arr[x]) then
        return self.mark_corners and getpen(PENS.CORNER) or nil
    else
        return nil
    end
end


function Dig:onRenderFrame(dc, rect)
    Dig.super.onRenderFrame(self, dc, rect)
    if self.shape == nil then self.shape = Shape{} end

    if not dfhack.screen.inGraphicsMode() and not gui.blink_visible(500) then
        return
    end

    local bounds = self:get_bounds()
    if bounds and self.mark then
        local function get_overlay_pen(pos)
            if pos.x >= bounds.x1 and pos.x <= bounds.x2 and pos.y >= bounds.y1 and pos.y <= bounds.y2 then
                if not self.shape or (bounds.x2 - bounds.x1 ~= self.shape.width or bounds.y2 - bounds.y1 ~= self.shape.height) then
                    if self.shape then print(string.format("%d - %d ~= %d ... %d - %d ~= %d", bounds.x2, bounds.x1, self.shape.width, bounds.y2, bounds.y1, self.shape.height)) end
                    self.shape:update( bounds.x2 - bounds.x1, bounds.y2 - bounds.y1)
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
            -- self:commit(pos)
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

    local params = { tostring(width), tostring(height), tostring(depth), name }

    local phases_view = self.subviews.phases
    if phases_view:getOptionValue() == 'Custom' then
        local some_phase_is_set = false
        for _, sv in pairs(self.subviews.phases_panel.subviews) do
            if sv.options and sv:getOptionLabel() == 'On' then
                table.insert(params, sv.label)
                some_phase_is_set = true
            end
        end
        if not some_phase_is_set then
            dialogs.MessageBox {
                frame_title = 'Error',
                text = 'Ensure at least one phase is enabled or enable autodetect'
            }:show()
            return
        end
    end

    -- set cursor to top left corner of the *uppermost* z-level
    local bounds = self:get_bounds()
    table.insert(params, ('--cursor=%d,%d,%d')
        :format(bounds.x1, bounds.y1, bounds.z2))

    if self.subviews.engrave:getOptionValue() then
        table.insert(params, '--engrave')
    end

    if self.subviews.smooth:getOptionValue() then
        table.insert(params, '--smooth')
    end

    local format = self.subviews.format:getOptionValue()
    if format ~= 'minimal' then
        table.insert(params, ('--format=%s'):format(format))
    end

    local meta = self.subviews.meta:getOptionValue()
    if not meta then
        table.insert(params, ('--nometa'))
    end

    local splitby = self.subviews.splitby:getOptionValue()
    if splitby ~= 'none' then
        table.insert(params, ('--splitby=%s'):format(splitby))
    end

    print('running: Dig ' .. table.concat(params, ' '))
    -- local files = plugin.run(table.unpack(params))

    -- local text = 'No files generated (see console for any error output)'
    -- if files and #files > 0 then
    --     text = 'Generated dig file(s):\n'
    --     for _,fname in ipairs(files) do
    --         text = text .. ('  %s\n'):format(fname)
    --     end
    -- end

    dialogs.MessageBox {
        frame_title = 'dig completed',
        text = text,
        on_close = function() self.parent_view:dismiss() end,
    }:show()
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
    self:addviews { Dig { presets = presets } }
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
