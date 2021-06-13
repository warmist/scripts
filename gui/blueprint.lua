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

local function get_dims(pos1, pos2)
    local width, height, depth = math.abs(pos1.x - pos2.x) + 1,
            math.abs(pos1.y - pos2.y) + 1,
            math.abs(pos1.z - pos2.z) + 1
    return width, height, depth
end

ActionPanel = defclass(ActionPanel, widgets.Panel)
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
            text='with the cursor.',
            frame={t=1},
        },
    }
end
function ActionPanel:get_action_text()
    if self.get_mark_fn() then
        return 'Select the second corner'
    end
    return 'Select the first corner'
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
        widgets.Label{text='Blueprint', frame={t=0}},
        widgets.Label{text=summary, text_pen=COLOR_GREY, frame={t=2}},
        ActionPanel{get_mark_fn=function() return self.mark end, frame={t=5}},
        widgets.Label{text={{text=function() return self:get_cancel_label() end,
                             key='LEAVESCREEN', key_sep=': ',
                             on_activate=function() self:on_cancel() end}},
                             frame={t=8}},
    }
end

-- the sidebar modes that we know how to get back to
local basic_ui_sidebar_modes = {
    [df.ui_sidebar_mode.Default]='',
    [df.ui_sidebar_mode.QueryBuilding]='D_BUILDJOB',
    [df.ui_sidebar_mode.LookAround]='D_LOOK',
    [df.ui_sidebar_mode.BuildingItems]='D_BUILDITEM',
    [df.ui_sidebar_mode.Stockpiles]='D_STOCKPILES',
    [df.ui_sidebar_mode.Zones]='D_CIVZONE',
}

-- Send ESC keycodes until we get to dwarfmode/Default and then enter the
-- specified sidebar mode. If we don't get to Default after 10 presses of ESC,
-- error. The target sidebar mode must be a member of basic_ui_sidebar_modes.
local function switch_ui_sidebar_mode(sidebar_mode)
    for i=1,10 do
        if df.global.ui.main.mode == df.ui_sidebar_mode.Default and
                dfhack.gui.getCurFocus(true) == 'dwarfmode/Default' then
            if sidebar_mode ~= df.ui_sidebar_mode.Default then
                gui.simulateInput(dfhack.gui.getCurViewscreen(true),
                                basic_ui_sidebar_modes[sidebar_mode])
            end
            return
        end
        gui.simulateInput(dfhack.gui.getCurViewscreen(true), 'LEAVESCREEN')
    end
    qerror('Unable to get into target sidebar mode from current UI viewscreen.')
end

function BlueprintUI:onAboutToShow()
    if not dfhack.isMapLoaded() then
        qerror('Please load a fortress map.')
    end

    self.saved_mode = df.global.ui.main.mode
    switch_ui_sidebar_mode(df.ui_sidebar_mode.LookAround)
end

function BlueprintUI:onDismiss()
    if not basic_ui_sidebar_modes[self.saved_mode] then
        self.saved_mode = df.ui_sidebar_mode.Default
    end
    switch_ui_sidebar_mode(self.saved_mode)
end

function BlueprintUI:on_mark(pos)
    self.mark = pos
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
    else
        self:dismiss()
    end
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

    if keys.SELECT then
        local pos = guidm.getCursorPos()
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

if not dfhack_flags.module then
    BlueprintUI{}:show()
end
