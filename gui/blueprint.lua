-- A GUI front-end for the blueprint plugin
--@ module = true
--[====[

gui/blueprint
=============
The `blueprint` plugin records the structure of a portion of your fortress in
a blueprint file that you (or anyone else) can later play back with `quickfort`.

This script provides a visual, interactive interface to make configuring and
using the blueprint plugin much easier.

Usage:

    gui/blueprint [<name> [<phases>]] [<options>]

All parameters are optional. Anything you specify will override the initial
values set in the interface. See the `blueprint` documentation for information
on the possible parameters and options.
]====]

local blueprint = require('plugins.blueprint')
local dialogs = require('gui.dialogs')
local gui = require('gui')
local guidm = require('gui.dwarfmode')
local widgets = require('gui.widgets')

ResizingPanel = defclass(ResizingPanel, widgets.Panel)
function ResizingPanel:init()
    if not self.frame then self.frame = {} end
end
function ResizingPanel:postUpdateLayout()
    local h = 0
    for _,subview in ipairs(self.subviews) do
        if subview.visible then
            h = h + subview.frame.h
        end
    end
    self.frame.h = h
end

local function get_dims(pos1, pos2)
    local width, height, depth = math.abs(pos1.x - pos2.x) + 1,
            math.abs(pos1.y - pos2.y) + 1,
            math.abs(pos1.z - pos2.z) + 1
    return width, height, depth
end

ActionPanel = defclass(ActionPanel, ResizingPanel)
ActionPanel.ATTRS{
    get_mark_fn=DEFAULT_NIL,
}
function ActionPanel:init()
    self:addviews{
        widgets.Label{
            text={{text=self:callback('get_action_text')}},
            frame={t=0},
        },
        widgets.Label{
            text='with the cursor or mouse.',
            frame={t=1},
        },
        widgets.Label{
            view_id='selected_area',
            text={{text=self:callback('get_area_text')}},
            frame={t=2,l=1},
        },
    }
end
function ActionPanel:preUpdateLayout()
    self.subviews.selected_area.visible = self.get_mark_fn() ~= nil
end
function ActionPanel:get_action_text()
    if self.get_mark_fn() then
        return 'Select the second corner'
    end
    return 'Select the first corner'
end
function ActionPanel:get_area_text()
    local width, height, depth = get_dims(self.get_mark_fn(), df.global.cursor)
    local tiles = width * height * depth
    local plural = tiles > 1 and 's' or ''
    return ('%dx%dx%d (%d tile%s)'):format(width, height, depth, tiles, plural)
end

BlueprintUI = defclass(BlueprintUI, guidm.MenuOverlay)
BlueprintUI.ATTRS {
    presets={},
    frame_inset=1,
    focus_path='blueprint',
}
function BlueprintUI:init()
    local summary = {
        'Create quickfort blueprints\n',
        'from a live game map.'
    }

    self:addviews{
        widgets.Label{text='Blueprint'},
        widgets.Label{text=summary, text_pen=COLOR_GREY},
        ActionPanel{get_mark_fn=function() return self.mark end},
        widgets.Label{text={{text=function() return self:get_cancel_label() end,
                             key='LEAVESCREEN', key_sep=': ',
                             on_activate=function() self:on_cancel() end}}},
    }
end

function BlueprintUI:onAboutToShow()
    if not dfhack.isMapLoaded() then
        qerror('Please load a fortress map.')
    end

    self.saved_mode = df.global.ui.main.mode
    if dfhack.gui.getCurFocus(true):find('^dfhack/')
            or not guidm.SIDEBAR_MODE_KEYS[self.saved_mode] then
        self.saved_mode = df.ui_sidebar_mode.Default
    end
    guidm.enterSidebarMode(df.ui_sidebar_mode.LookAround)
end

function BlueprintUI:onDismiss()
    guidm.enterSidebarMode(self.saved_mode)
end

function BlueprintUI:on_mark(pos)
    self.mark = pos
    self:updateLayout()
end

function BlueprintUI:get_cancel_label()
    if self.mark then
        return 'Cancel selection'
    end
    return 'Back'
end

function BlueprintUI:on_cancel()
    if self.mark then
        self.mark = nil
        self:updateLayout()
    else
        self:dismiss()
    end
end

function BlueprintUI:updateLayout(parent_rect)
    -- set frame boundaries and calculate subframe heights
    BlueprintUI.super.updateLayout(self, parent_rect)
    -- vertically lay out subviews, adding an extra line of space between each
    local y = 0
    for _,subview in ipairs(self.subviews) do
        subview.frame.t = y
        if subview.visible then
            y = y + subview.frame.h + 1
        end
    end
    -- recalculate widget frames
    self:updateSubviewLayout()
end

-- Sorts and returns the given arguments.
local function min_to_max(...)
    local args = {...}
    table.sort(args, function(a, b) return a < b end)
    return table.unpack(args)
end

local fg, bg = COLOR_GREEN, COLOR_BLACK

function BlueprintUI:onRenderBody()
    if not self.mark then return end

    local vp = self:getViewport()
    local dc = gui.Painter.new(self.df_layout.map)

    if gui.blink_visible(500) then
        local cursor = df.global.cursor
        -- clip blinking region to viewport
        local _,y_start,y_end = min_to_max(self.mark.y, cursor.y, vp.y1, vp.y2)
        local _,x_start,x_end = min_to_max(self.mark.x, cursor.x, vp.x1, vp.x2)
        for y=y_start,y_end do
            for x=x_start,x_end do
                local pos = xyz2pos(x, y, cursor.z)
                -- don't overwrite the cursor so the user can still see it
                if not same_xyz(cursor, pos) then
                    local stile = vp:tileToScreen(pos)
                    dc:map(true):seek(stile.x, stile.y):
                            pen(fg, bg):char('X'):map(false)
                end
            end
        end
    end
end

function BlueprintUI:onInput(keys)
    if self:inputToSubviews(keys) then return true end

    local pos = nil
    if keys._MOUSE_L then
        local x, y = dfhack.screen.getMousePos()
        if gui.is_in_rect(guidm.getPanelLayout().map, x, y) then
            pos = xyz2pos(df.global.window_x + x - 1,
                          df.global.window_y + y - 1,
                          df.global.window_z)
            guidm.setCursorPos(pos)
        end
    elseif keys.SELECT then
        pos = guidm.getCursorPos()
    end

    if pos then
        if self.mark then
            self:commit(pos)
        else
            self:on_mark(pos)
        end
        return true
    end

    return self:propagateMoveKeys(keys)
end

-- assemble and execute the blueprint commandline
function BlueprintUI:commit(pos)
    local mark = self.mark
    local width, height, depth = get_dims(mark, pos)
    if depth > 1 then
        -- when there are multiple levels, process them top to bottom
        depth = -depth
    end

    local name = 'blueprint'
    local params = {tostring(width), tostring(height), tostring(depth), name}

    -- set cursor to top left corner of the *uppermost* z-level
    local x, y, z = math.min(mark.x, pos.x), math.min(mark.y, pos.y),
            math.max(mark.z, pos.z)
    table.insert(params, ('--cursor=%d,%d,%d'):format(x, y, z))

    print('running: blueprint ' .. table.concat(params, ' '))
    local files = blueprint.run(table.unpack(params))

    local text = 'No files generated'
    if files and #files > 0 then
        text = 'Generated blueprint file(s):\n'
        for _,fname in ipairs(files) do
            text = text .. ('  %s\n'):format(fname)
        end
    end

    dialogs.MessageBox{
        frame_title='Blueprint completed',
        text=text,
        on_close=self:callback('dismiss'),
    }:show()
end

if dfhack_flags.module then
    return
end

if active_screen then
    active_screen:dismiss()
end

active_screen = BlueprintUI{}
active_screen:show()
