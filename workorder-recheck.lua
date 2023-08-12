-- Resets the selected work order to the `Checking` state

--@ module = true

local gui = require('gui')
local widgets = require('gui.widgets')
local overlay = require('plugins.overlay')

local function set_current_inactive()
    local scrConditions = df.global.game.main_interface.info.work_orders.conditions
    if scrConditions.open then
        local order = scrConditions.wq
        order.status.active = false
    else
        qerror("Order conditions is not open")
    end
end

-- -------------------
-- RecheckOverlay
--

local focusString = 'dwarfmode/Info/WORK_ORDERS/Conditions'

RecheckOverlay = defclass(RecheckOverlay, overlay.OverlayWidget)
RecheckOverlay.ATTRS{
    default_pos={x=6,y=2},
    default_enabled=true,
    viewscreens=focusString,
    frame={w=17, h=3},
    frame_style=gui.MEDIUM_FRAME,
    frame_background=gui.CLEAR_PEN,
}

function RecheckOverlay:init()
    self:addviews{
        widgets.HotkeyLabel{
            frame={t=0, l=0},
            label='recheck',
            key='CUSTOM_CTRL_A',
            on_activate=set_current_inactive,
        },
    }
end

-- -------------------

OVERLAY_WIDGETS = {
    recheck=RecheckOverlay,
}

if dfhack_flags.module then
    return
end

-- Check if on correct screen and perform the action if so
if not dfhack.gui.matchFocusString(focusString) then
    qerror('workorder-recheck must be run from the manager order conditions view')
end

set_current_inactive()
