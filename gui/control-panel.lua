local gui = require('gui')
local helpdb = require('helpdb')
local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')

local REFRESH_MS = 10000

-- eventually this should be queryable from script-manager
local FORT_SERVICES = {
    'autobutcher',
    'autochop',
    'autoclothing',
    'autofarm',
    'autofish',
    'autounsuspend',
    'channel-safely',
    'emigration',
    'fastdwarf',
    'misery',
    'nestboxes',
    'prioritize',
    'seedwatch',
    'starvingdead',
    'tailor',
}

-- eventually this should be queryable from script-manager
local SYSTEM_SERVICES = {
    'RemoteFortressReader',
    'automelt',
    'buildingplan',
    'overlay',
    'reveal',
}

local SETTINGS = {
    ['gui.widgets']={
        {id='DEFAULT_INITIAL_PAUSE', type='bool',
         desc='Whether to pause the game when a DFHack tool is shown. You can always pause and unpause after the tool window comes up.'},
        {id='DOUBLE_CLICK_MS', type='int', min=50,
         desc='How long to wait for the second click of a double click. Larger values allow you to click slower.'},
        {id='SCROLL_INITIAL_DELAY_MS', type='int', min=5,
         desc='The delay before the second scroll event when holding the mouse button down on a scrollbar. Larger values make the scrollbar slower.'},
        {id='SCROLL_DELAY_MS', type='int', min=5,
         desc='The delay between scroll events when holding the mouse button down on a scrollbar. Larger values make the scrollbar slower.'},
    },
}

local function get_icon_pens()
    -- these need to be dynamic because they can change between script
    -- invocations
    local start = dfhack.textures.getIconsTexposStart()
    local enabled_pen = dfhack.pen.parse{
            tile=(start>0) and (start+1) or nil,
            ch='+', fg=COLOR_LIGHTGREEN}
    local disabled_pen = dfhack.pen.parse{
            tile=(start>0) and (start+0) or nil,
            ch='-', fg=COLOR_RED}
    return enabled_pen, disabled_pen
end

--
-- ConfigPanel
--

ConfigPanel = defclass(ConfigPanel, widgets.Panel)
ConfigPanel.ATTRS{
    intro_text=DEFAULT_NIL,
    is_enableable=DEFAULT_NIL,
}

function ConfigPanel:init()
    self:addviews{
        widgets.Panel{
            frame={t=0, b=7},
            autoarrange_subviews=true,
            autoarrange_gap=1,
            subviews={
                widgets.WrappedLabel{
                    frame={t=0},
                    text_to_wrap=self.intro_text,
                },
                widgets.FilteredList{
                    frame={t=5},
                    view_id='list',
                    on_select=self:callback('on_select'),
                    icon_width=2,
                },
            },
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
            enabled=self.is_enableable,
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
            enabled=self.is_enableable,
            on_activate=self:callback('launch_config'),
        },
    }
end

function ConfigPanel:onInput(keys)
    local handled = ConfigPanel.super.onInput(self, keys)
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

function ConfigPanel:refresh()
    local enabled_icon_pen, disabled_icon_pen = get_icon_pens()
    local choices = {}
    for _,choice in ipairs(self:get_choices()) do
        local command = choice.command or choice.target
        local gui_config = 'gui/' .. command
        local has_gui_config = helpdb.is_entry(gui_config)
        local text = {
            '[help] ',
            {text=('%11s '):format(has_gui_config and '[configure]' or ''),
             pen=not self.is_enableable() and COLOR_DARKGREY or nil},
            choice.target,
        }
        local desc = helpdb.is_entry(command) and
                helpdb.get_entry_short_help(command) or ''
        local icon_pen = choice.enabled and enabled_icon_pen or disabled_icon_pen
        table.insert(choices,
                {text=text, command=choice.command, target=choice.target, desc=desc,
                 search_key=choice.target, icon=icon_pen.tile, icon_pen=icon_pen,
                 gui_config=has_gui_config and gui_config})
    end
    self.subviews.list:setChoices(choices)
    self.subviews.list.edit:setFocus(true)
end

function ConfigPanel:on_select(idx, choice)
    local desc = self.subviews.desc
    desc.text_to_wrap = choice and choice.desc or ''
    if desc.frame_body then
        desc:updateLayout()
    end
    if choice then
        self.subviews.launch.enabled = self.is_enableable() and not not choice.gui_config
    end
end

function ConfigPanel:toggle_enabled()
    if not self.is_enableable() then return false end
    _,choice = self.subviews.list:getSelected()
    if not choice then return end
    local is_enabled = choice.icon == get_icon_pens().tile
    local tokens = {}
    table.insert(tokens, choice.command)
    table.insert(tokens, is_enabled and 'disable' or 'enable')
    table.insert(tokens, choice.target)
    dfhack.run_command(tokens)
    self:refresh()
end

function ConfigPanel:show_help()
    _,choice = self.subviews.list:getSelected()
    if not choice then return end
    dfhack.run_command('gui/launcher', (choice.command or choice.target) .. ' ')
end

function ConfigPanel:launch_config()
    if not self.is_enableable() then return false end
    _,choice = self.subviews.list:getSelected()
    if not choice or not choice.gui_config then return end
    dfhack.run_command(choice.gui_config)
end

--
-- Services
--

Services = defclass(Services, ConfigPanel)
Services.ATTRS{
    services_list=DEFAULT_NIL,
}

local function get_enabled_map()
    local enabled_map = {}
    local output = dfhack.run_command_silent('enable'):split('\n+')
    for _,line in ipairs(output) do
        local _,_,command,enabled_str,extra = line:find('%s*(%S+):%s+(%S+)%s*(.*)')
        if enabled_str then
            enabled_map[command] = enabled_str == 'on'
        end
    end
    return enabled_map
end

function Services:get_choices()
    local enabled_map = get_enabled_map()
    local choices = {}
    for _,service in ipairs(self.services_list) do
        table.insert(choices, {target=service, enabled=enabled_map[service]})
    end
    return choices
end

--
-- FortServices
--

FortServices = defclass(FortServices, Services)
FortServices.ATTRS{
    is_enableable=function() return dfhack.world.isFortressMode() end,
    intro_text='These automation tools can only be enabled when you'..
                ' have a fort loaded, but once you enable them, they will'..
                ' stay enabled when you save and reload your fort.',
    services_list=FORT_SERVICES,
}

--
-- SystemServices
--

SystemServices = defclass(SystemServices, Services)
SystemServices.ATTRS{
    is_enableable=function() return true end,
    intro_text='These are DFHack system services that should generally not'..
                ' be turned off. If you do turn them off, they may'..
                ' automatically re-enable themselves when you restart DF.',
    services_list=SYSTEM_SERVICES,
}

--
-- Overlays
--

Overlays = defclass(Overlays, ConfigPanel)
Overlays.ATTRS{
    is_enableable=function() return true end,
    intro_text='These are DFHack overlays that add information and'..
                ' functionality to various DF screens.',
}

function Overlays:get_choices()
    local choices = {}
    local state = overlay.get_state()
    for _,name in ipairs(state.index) do
        table.insert(choices, {command='overlay',
                               target=name,
                               enabled=state.config[name].enabled})
    end
    return choices
end

--
-- Preferences
--

Preferences = defclass(Preferences, widgets.Panel)

function Preferences:init()
    self:addviews{
    }
end

function Preferences:refresh()
end

--
-- ControlPanel
--

ControlPanel = defclass(ControlPanel, widgets.Window)
ControlPanel.ATTRS {
    frame_title='DFHack Control Panel',
    frame={w=55, h=45},
    resizable=true,
    resize_min={w=45, h=20},
}

function ControlPanel:init()
    self:addviews{
        widgets.CycleHotkeyLabel{
            frame={t=0, l=0},
            label='Showing:',
            key='CUSTOM_CTRL_N',
            options={
                {label='Fort services', value='fort'},
                {label='Overlays', value='overlays'},
                {label='System preferences', value='prefs'},
                {label='System services', value='system'},
            },
            on_change=self:callback('set_page'),
        },
        widgets.Pages{
            view_id='pages',
            frame={t=2, l=0, b=0, r=0},
            subviews={
                FortServices{view_id='fort'},
                Overlays{view_id='overlays'},
                Preferences{view_id='prefs'},
                SystemServices{view_id='system'},
            },
        },
    }

    self:refresh_page()
end

function ControlPanel:refresh_page()
    self.subviews.pages:getSelectedPage():refresh()
    self.next_refresh_ms = dfhack.getTickCount() + REFRESH_MS
end

function ControlPanel:set_page(val)
    self.subviews.pages:setSelected(val)
    self:refresh_page()
end

-- refreshes data every 10 seconds or so
function ControlPanel:onRenderBody()
    if self.next_refresh_ms <= dfhack.getTickCount() then
        self:refresh_page()
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
