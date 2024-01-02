-- config ui for confirm

local confirm = reqscript('confirm')
local gui = require('gui')
local widgets = require('gui.widgets')

Confirm = defclass(Confirm, widgets.Window)
Confirm.ATTRS{
    frame_title='Confirmation dialogs',
    frame={w=36, h=17},
    initial_id=DEFAULT_NIL,
}

function Confirm:init()
    self:addviews{
        widgets.List{
            view_id='list',
            frame={t=0, l=0, b=2},
            on_submit=function(idx)
                self:toggle(idx)
                self:refresh()
            end,
        },
        widgets.HotkeyLabel{
            frame={b=0, l=0},
            label='Toggle',
            key='SELECT',
            on_activate=function()
                self:toggle(self.subviews.list:getSelected())
                self:refresh()
            end,
        },
        widgets.HotkeyLabel{
            frame={b=0, l=20},
            label='Toggle all',
            key='CUSTOM_CTRL_A',
            on_activate=function()
                self:toggle_all(self.subviews.list:getSelected())
                self:refresh()
            end,
        },
    }

    self:refresh()

    if self.initial_id then
        for i, choice in ipairs(self.subviews.list:getChoices()) do
            if choice.id == self.initial_id then
                self.subviews.list:setSelected(i)
                break
            end
        end
    end
end

function Confirm:refresh()
    self.data = confirm.get_state()
    local choices = {}
    for _, c in ipairs(self.data) do
        table.insert(choices, {
            id=c.id,
            enabled=c.enabled,
            text={
                c.id,
                ': ',
                {
                    text=c.enabled and 'Enabled' or 'Disabled',
                    pen=c.enabled and COLOR_GREEN or COLOR_RED,
                }
            }
        })
    end
    local list = self.subviews.list
    local selected = list:getSelected()
    list:setChoices(choices)
    list:setSelected(selected)
end

function Confirm:toggle(idx)
    local choice = self.data[idx]
    confirm.set_enabled(choice.id, not choice.enabled)
    self:refresh()
end

function Confirm:toggle_all(choice)
    local target_state = not self.data[1].enabled
    for _, c in pairs(self.data) do
        confirm.set_enabled(c.id, target_state)
    end
    self:refresh()
end

ConfirmScreen = defclass(ConfirmScreen, gui.ZScreen)
PromptScreen.ATTRS {
    focus_path='confirm/config',
    initial_id=DEFAULT_NIL,
}

function ConfirmScreen:init()
    self:addviews{Confirm{initial_id=self.initial_id}}
end

function ConfirmScreen:onDismiss()
    view = nil
end

if dfhack_flags.module then
    return
end

local initial_id = ({...})[1] -- set when called from confirm dialogs
view = view and view:raise() or ConfirmScreen{initial_id=initial_id}:show()
