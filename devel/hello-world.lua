-- A basic example to start your own gui script from.
--@ module = true

local gui = require('gui')
local widgets = require('gui.widgets')

local HOVER_FRAME = copyall(gui.BOUNDARY_FRAME)
HOVER_FRAME.signature_pen = false

HelloWorld = defclass(HelloWorld, gui.Screen)

function HelloWorld:init()
    local window = widgets.Window{
        frame={w=20, h=15},
        frame_title='Hello World',
        autoarrange_subviews=true,
        autoarrange_gap=1,
    }
    window:addviews{
        widgets.Label{text={{text='Hello, world!', pen=COLOR_LIGHTGREEN}}},
        widgets.Label{frame={l=0, t=0}, text="Hover target:"},
        widgets.Panel{
            view_id='hover',
            frame={w=5, h=5},
            frame_style=HOVER_FRAME,
            on_render=function() 
                self.subviews.hover:getMousePos()
                local hover = self.subviews.hover
                if hover:getMousePos() then
                    hover.frame_background = dfhack.pen.parse{
                        ch=32, fg=COLOR_LIGHTGREEN, bg=COLOR_LIGHTGREEN}
                else
                    hover.frame_background = nil
                end
            end},
    }
    self:addviews{window}
end

function HelloWorld:onDismiss()
    view = nil
end

function HelloWorld:onInput(keys)
    if self:inputToSubviews(keys) then
        return true
    elseif keys.LEAVESCREEN or keys.SELECT then
        self:dismiss()
        return true
    end
end

function HelloWorld:onRenderFrame(dc, rect)
    -- since we're not taking up the entire screen
    self:renderParent()
end

if dfhack_flags.module then
    return
end

view = view or HelloWorld{}:show()
