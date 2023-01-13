local gui = require('gui')
local helpdb = require('helpdb')
local widgets = require('gui.widgets')

local ICONS_START = dfhack.textures.getIconsTexposStart()
local ENABLED_ICON = ICONS_START > 0 and ICONS_START + 1 or '+'
local ICON_PEN = dfhack.pen.parse{ch=string.byte('+'), fg=COLOR_LIGHTGREEN}
local REFRESH_MS = 10000

-- eventually this should be queryable from script-manager
local FORT_SERVICES = {

}

-- eventually this should be queryable from script-manager
local SYSTEM_SERVICES = {

}

local SETTINGS = {
    ['gui.widgets']={
        {id='DEFAULT_INITIAL_PAUSE', type='bool',
         desc='Whether to pause the game when a DFHack tool is shown.'},
        {id='DOUBLE_CLICK_MS', type='int', min=50,
         desc='How long to wait for the second click of a double click. Larger values allow you to click slower.'},
        {id='SCROLL_INITIAL_DELAY_MS', type='int', min=5,
         desc='The delay before the second scroll event when holding the mouse button down on a scrollbar. Larger values make the scrollbar slower.'},
        {id='SCROLL_DELAY_MS', type='int', min=5,
         desc='The delay between scroll events when holding the mouse button down on a scrollbar. Larger values make the scrollbar slower.'},
    },
}

--
-- FortServices
--


--
-- SystemServices
--

--
-- DFHackConfig
--

DFHackConfig = defclass(DFHackConfig, widgets.Panel)

function DFHackConfig:init()
    self:addviews{
        widgets.Label{
            frame={t=0, l=0},
            text='',
        }
    }
end

--
-- ControlPanel
--

ControlPanel = defclass(ControlPanel, widgets.Window)
ControlPanel.ATTRS {
    frame_title='DFHack Control Panel',
    frame={w=45, h=20},
    resizable=true,
}

function ControlPanel:init()
    self:addviews{
        widgets.CycleHotkeyLabel{
        },
        widgets.FilteredList{
            view_id='list',
            frame={t=0, b=7},
            on_select=self:callback('on_select'),
            icon_width=2,
            icon_pen=ICON_PEN,
        },
        widgets.WrappedLabel{
            view_id='desc',
            frame={b=4, h=2},
            auto_height=false,
        },
        widgets.HotkeyLabel{
            frame={b=2, l=0},
            label='Toggle enabled',
            key='SELECT',
            on_activate=self:callback('toggle_enabled')
        },
        widgets.HotkeyLabel{
            frame={b=1, l=0},
            label='Show tool help or run commands',
            key='CUSTOM_CTRL_H',
            on_activate=self:callback('show_help')
        },
        widgets.HotkeyLabel{
            view_id='launch',
            frame={b=0, l=0},
            label='Launch config UI',
            key='CUSTOM_CTRL_G',
            on_activate=self:callback('launch_config'),
        },
    }

    self:refresh_list()
end

function ControlPanel:refresh_list()
    local output = dfhack.run_command_silent('enable'):split('\n+')
    local choices = {}
    for _,line in ipairs(output) do
        local _,_,command,enabled_str,extra = line:find('%s*(%S+):%s+(%S+)%s*(.*)')
        if command and #extra == 0 then
            local gui_config = 'gui/'..command
            local has_gui_config = helpdb.is_entry(gui_config)
            local text = ('[help] %11s %s')
                    :format(has_gui_config and '[configure]' or '', command)
            local desc = helpdb.is_entry(command) and
                    helpdb.get_entry_short_help(command) or ''
            local icon = enabled_str == 'on' and ENABLED_ICON or nil
            table.insert(choices,
                    {text=text, command=command, desc=desc, icon=icon,
                     gui_config=has_gui_config and gui_config, search_key=command})
        end
    end
    self.subviews.list:setChoices(choices)
    self.next_refresh_ms = dfhack.getTickCount() + REFRESH_MS
end

function ControlPanel:onInput(keys)
    local handled = ControlPanel.super.onInput(self, keys)
    if keys._MOUSE_L_DOWN then
        local list = self.subviews.list.list
        local idx = list:getIdxUnderMouse()
        if idx then
            local x = list:getMousePos()
            if x == 0 then
                self:toggle_enabled()
                return true
            elseif x >= 2 and x <= 7 then
                self:show_help()
                return true
            elseif x >= 9 and x <= 19 then
                self:launch_config()
                return true
            end
        end
    end
    return handled
end

function ControlPanel:on_select(idx, choice)
    local desc = self.subviews.desc
    desc.text_to_wrap = choice and choice.desc or ''
    if desc.frame_body then
        desc:updateLayout()
    end
    self.subviews.launch.enabled = not not choice.gui_config
end

function ControlPanel:toggle_enabled()
    _,choice = self.subviews.list:getSelected()
    if not choice then return end
    dfhack.run_command(choice.icon and 'disable' or 'enable', choice.command)
    self:refresh_list()
end

function ControlPanel:show_help()
    _,choice = self.subviews.list:getSelected()
    if not choice then return end
    dfhack.run_command('gui/launcher', choice.command..' ')
end

function ControlPanel:launch_config()
    _,choice = self.subviews.list:getSelected()
    if not choice or not choice.gui_config then return end
    dfhack.run_command(choice.gui_config)
end

-- refreshes data every 10 seconds or so
function ControlPanel:onRenderBody()
    if self.next_refresh_ms <= dfhack.getTickCount() then
        self:refresh_list()
    end
end

--
-- ControlPanelScreen
--

ControlPanelScreen = defclass(ControlPanelScreen, gui.ZScreen)
ControlPanelScreen.ATTRS {
    focus_path='control-panel',
}

function ControlPanelScreen:init()
    self:addviews{ControlPanel{}}
end

function ControlPanelScreen:onDismiss()
    view = nil
end

view = view and view:raise() or ControlPanelScreen{}:show()
