-- An in-game CP437 table

local dialog = require('gui.dialogs')
local gui = require('gui')
local widgets = require('gui.widgets')

CPDialog = defclass(CPDialog, widgets.Window)
CPDialog.ATTRS {
    focus_path='cp437-table',
    frame_title='CP437 table',
    drag_anchors={frame=true, body=true},
    frame={w=36, h=17},
}

function CPDialog:init(info)
    self:addviews{
        widgets.EditField{
            view_id='edit',
            frame={t=0, l=0},
            on_submit=self:callback('submit'),
        },
        widgets.Panel{
            view_id='board',
            frame={t=2, l=0, w=32, h=9},
            on_render=self:callback('render_board'),
        },
        widgets.Label{
            frame={b=1, l=0},
            text='Click characters or type',
        },
        widgets.Label{
            frame={b=0, l=0},
            text={
                {key='LEAVESCREEN', text=': Cancel'},
                ' ',
                {key='SELECT', text=': Done'},
            },
        },
    }
end

function CPDialog:render_board(dc)
    for ch = 0,255 do
        if dfhack.screen.charToKey(ch) then
            dc:seek(ch % 32, math.floor(ch / 32)):char(ch)
        end
    end
end

function CPDialog:submit()
    local keys = {}
    local text = self.subviews.edit.text
    for i = 1,#text do
        local k = dfhack.screen.charToKey(string.byte(text:sub(i, i)))
        if not k then
            dialog.showMessage('Error',
                ('Invalid character at position %d: "%s"'):
                    format(i, text:sub(i, i)),
                COLOR_LIGHTRED)
            return
        end
        keys[i] = k
    end
    local screen = self.parent_view
    local parent = screen._native.parent
    dfhack.screen.hideGuard(screen, function()
        for i, k in pairs(keys) do
            gui.simulateInput(parent, k)
        end
    end)
    screen:dismiss()
end

function CPDialog:onInput(keys)
    local x, y = self.subviews.board:getMousePos()
    if keys._MOUSE_L_DOWN and x then
        local ch = x + (32 * y)
        if ch ~= 0 and dfhack.screen.charToKey(ch) then
            self.subviews.edit:insert(string.char(ch))
        end
        return true
    end
    return CPDialog.super.onInput(self, keys)
end

CPScreen = defclass(CPScreen, gui.ZScreen)
CPScreen.ATTRS {
    focus_path='cp437-table',
}

function CPScreen:init()
    self:addviews{CPDialog{view_id='main'}}
end

function CPScreen:isMouseOver()
    return self.subviews.main:getMouseFramePos()
end

function CPScreen:onDismiss()
    view = nil
end

view = view or CPScreen{}:show()
