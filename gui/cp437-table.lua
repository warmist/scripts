-- An in-game CP437 table

local dialog = require('gui.dialogs')
local gui = require('gui')
local widgets = require('gui.widgets')

CPDialog = defclass(CPDialog, widgets.Window)
CPDialog.ATTRS {
    frame_title='CP437 table',
    frame={w=36, h=20},
}

function CPDialog:init(info)
    self:addviews{
        widgets.EditField{
            view_id='edit',
            frame={t=0, l=0},
        },
        widgets.Panel{
            view_id='board',
            frame={t=2, l=0, w=32, h=9},
        },
        widgets.Label{
            frame={b=4, l=0},
            text='Click characters or type',
        },
        widgets.HotkeyLabel{
            frame={b=2, l=0},
            key='SELECT',
            label='Send text to parent',
            on_activate=self:callback('submit'),
        },
        widgets.HotkeyLabel{
            frame={b=1, l=0},
            key='STRING_A000',
            label='Backspace',
            on_activate=function() self.subviews.edit:onInput{_STRING=0} end,
        },
        widgets.HotkeyLabel{
            frame={b=0, l=0},
            key='LEAVESCREEN',
            label='Cancel',
            on_activate=function() self.parent_view:dismiss() end,
        },
    }

    local board = self.subviews.board
    local edit = self.subviews.edit
    local hpen = dfhack.pen.parse{fg=COLOR_WHITE, bg=COLOR_RED}
    for ch = 0,255 do
        if dfhack.screen.charToKey(ch) then
            local chr = string.char(ch)
            board:addviews{
                widgets.Label{
                    frame={t=ch//32, l=ch%32, w=1, h=1},
                    auto_height=false,
                    text=chr,
                    text_hpen=hpen,
                    on_click=function() if ch ~= 0 then edit:insert(chr) end end,
                },
            }
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

    -- ensure clicks on "submit" don't bleed through
    df.global.enabler.mouse_lbut = 0
    df.global.enabler.mouse_lbut_down = 0
end

CPScreen = defclass(CPScreen, gui.ZScreen)
CPScreen.ATTRS {
    focus_path='cp437-table',
}

function CPScreen:init()
    self:addviews{CPDialog{}}
end

function CPScreen:onDismiss()
    view = nil
end

view = view and view:raise() or CPScreen{}:show()
