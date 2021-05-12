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

function BlueprintUI:onAboutToShow()
    if not dfhack.isMapLoaded() then
        qerror('Please load a fortress map.')
    end
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
        for y=y_start,y_end do for x=x_start,x_end do
            local pos = xyz2pos(x, y, cursor.z)
            if x == cursor.x and y == cursor.y then
                -- don't overwrite the cursor
                goto continue
            end
            local stile = vp:tileToScreen(pos)
            dc:map(true):seek(stile.x, stile.y):pen(fg, bg):char('X'):map(false)
            ::continue::
        end end
    end
end

function BlueprintUI:onInput(keys)
    if self:inputToSubviews(keys) then return true end

    if keys.SELECT then
        local pos = guidm.getCursorPos()
        if self.mark then
            self:commit(pos)
            self:dismiss()
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
    local basename = "blueprint"
    local cmd = {'blueprint',
                 tostring(width), tostring(height), tostring(depth),
                 basename}

    -- set cursor to top left corner of the *uppermost* z-level
    local x, y, z = math.min(mark.x, pos.x), math.min(mark.y, pos.y),
            math.max(mark.z, pos.z)
    table.insert(cmd, ('--cursor=%d,%d,%d'):format(x, y, z))

    print('running: ' .. table.concat(cmd, ' '))
    dfhack.run_command(cmd)
end

if not dfhack_flags.module then
    BlueprintUI{}:show()
end
