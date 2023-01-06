-- config ui for autochop

local gui = require('gui')
local widgets = require('gui.widgets')

Autochop = defclass(Autochop, widgets.Window)
Autochop.ATTRS {
    frame_title='Autochop',
    frame={w=50, h=45},
    resizable=true,
}

function Autochop:init()
    self:addviews{
    }
end

AutochopScreen = defclass(AutochopScreen, gui.ZScreen)
Autochop.ATTRS {
    focus_path='autochop',
}

function AutochopScreen:init()
    self:addviews{Autochop{view_id='main'}}
end

function Autochop:onDismiss()
    view = nil
end

view = view or AutochopScreen{}:show()
