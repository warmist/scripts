-- View whether tiles on the map can be pathed to
--@module = true

local gui = require('gui')
local overlay = require('plugins.overlay')
local plugin = require('plugins.pathable')
local widgets = require('gui.widgets')

Pathable = defclass(Pathable, overlay.OverlayWidget)
Pathable.ATTRS{
    viewscreens='dwarfmode',
    default_pos={x=-3, y=20},
    frame_title='Pathability viewer',
    frame_style=gui.GREY_LINE_FRAME,
    frame_background=gui.CLEAR_PEN,
    frame={w=32, h=11},
    draggable=true,
    drag_anchors={title=true, body=true},
    resizable=true,
    frame_inset=1,
    always_enabled=true,
}

function Pathable:init()
    self:addviews{
        widgets.ToggleHotkeyLabel{
            view_id='lock',
            frame={t=0, l=0},
            key='CUSTOM_CTRL_L',
            label='Lock target',
            initial_option=false,
        },
        widgets.ToggleHotkeyLabel{
            view_id='draw',
            frame={t=1, l=0},
            key='CUSTOM_CTRL_D',
            label='Draw',
            initial_option=true,
        },
        widgets.ToggleHotkeyLabel{
            view_id='skip',
            frame={t=2, l=0},
            key='CUSTOM_CTRL_U',
            label='Skip unrevealed',
            initial_option=true,
        },
        widgets.EditField{
            view_id='group',
            frame={t=4, l=0},
            label_text='Pathability group: ',
            active=false,
        },
        widgets.HotkeyLabel{
            frame={t=6, l=0},
            key='LEAVESCREEN',
            label='Close',
            on_activate=self:callback('overlay_trigger'),
        },
    }
end

function Pathable:overlay_trigger()
    if not dfhack.isMapLoaded() then
        if not self.triggered then
            dfhack.printerr('gui/pathable requires a fortress map to be loaded')
        end
        self.triggered = false
        return
    end

    self.subviews.lock.option_idx = 2
    self.triggered = not self.triggered
end

function Pathable:render(dc)
    if not self.triggered then return end
    Pathable.super.render(self, dc)
end

function Pathable:onRenderBody()
    local target = self.subviews.lock:getOptionValue() and
            self.saved_target or dfhack.gui.getMousePos()
    self.saved_target = target

    local group = self.subviews.group
    local skip = self.subviews.skip:getOptionValue()

    if not target then
        group:setText('')
        return
    elseif skip and not dfhack.maps.isTileVisible(target) then
        group:setText('Hidden')
        return
    end

    local block = dfhack.maps.getTileBlock(target)
    local walk_group = block.walkable[target.x % 16][target.y % 16]
    group:setText(walk_group == 0 and 'None' or tostring(walk_group))

    if self.subviews.draw:getOptionValue() then
        plugin.paintScreen(target, skip)
    end
end

function Pathable:onInput(keys)
    if not self.triggered then return end

    if keys._MOUSE_R_DOWN then
        self:overlay_trigger()
        return true
    end

    return Pathable.super.onInput(self, keys)
end

OVERLAY_WIDGETS = {overlay=Pathable}

if dfhack_flags.module then
    return
end

dfhack.run_command('overlay trigger gui/pathable.overlay')
