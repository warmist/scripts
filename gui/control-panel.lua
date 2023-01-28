local gui = require('gui')
local helpdb = require('helpdb')
local widgets = require('gui.widgets')

local ICONS_START = dfhack.textures.getIconsTexposStart()
local ENABLED_ICON = ICONS_START > 0 and ICONS_START + 1 or '+'
local ICON_PEN = dfhack.pen.parse{ch=string.byte('+'), fg=COLOR_LIGHTGREEN}
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

local function is_fort_mode()
    return dfhack.world.isFortressMode()
end

FortServices = defclass(FortServices, widgets.Panel)

function FortServices:init()
    self:addviews{
        widgets.Panel{
            frame={t=0, b=7},
            autoarrange_subviews=true,
            autoarrange_gap=1,
            subviews={
                widgets.WrappedLabel{
                    frame={t=0},
                    text_to_wrap='These automation tools can only be enabled when you'..
                        ' have a fort loaded, but once you enable them, they will'..
                        ' stay enabled when you save and reload your fort.',
                },
                widgets.Panel{
                    frame={t=5},
                    subviews={
                        widgets.FilteredList{
                            view_id='list',
                            frame={t=0, b=0},
                            on_select=self:callback('on_select'),
                            icon_width=2,
                            icon_pen=ICON_PEN,
                        },
                        widgets.Label{
                            frame={t=0, l=0},
                            text={{tile=ENABLED_ICON}},
                        },
                    },
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
            enabled=is_fort_mode,
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
            enabled=is_fort_mode,
            on_activate=self:callback('launch_config'),
        },
    }
end

function FortServices:onInput(keys)
    local handled = FortServices.super.onInput(self, keys)
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

function FortServices:refresh()
    local enabled_map = get_enabled_map()
    local choices = {}
    for _,service in ipairs(FORT_SERVICES) do
        local gui_config = 'gui/'..service
        local has_gui_config = helpdb.is_entry(gui_config)
        local text = ('[help] %11s %s')
                :format(has_gui_config and '[configure]' or '', service)
        local desc = helpdb.is_entry(service) and
                helpdb.get_entry_short_help(service) or ''
        local icon = enabled_map[service] and ENABLED_ICON or nil
        table.insert(choices,
                {text=text, command=service, desc=desc, icon=icon,
                 gui_config=has_gui_config and gui_config, search_key=service})
    end
    self.subviews.list:setChoices(choices)
end

function FortServices:on_select(idx, choice)
    local desc = self.subviews.desc
    desc.text_to_wrap = choice and choice.desc or ''
    if desc.frame_body then
        desc:updateLayout()
    end
    if choice then
        self.subviews.launch.enabled = not not choice.gui_config
    end
end

function FortServices:toggle_enabled()
    if not is_fort_mode() then return false end
    _,choice = self.subviews.list:getSelected()
    if not choice then return end
    dfhack.run_command(choice.icon and 'disable' or 'enable', choice.command)
    self:refresh()
end

function FortServices:show_help()
    _,choice = self.subviews.list:getSelected()
    if not choice then return end
    dfhack.run_command('gui/launcher', choice.command..' ')
end

function FortServices:launch_config()
    if not is_fort_mode() then return false end
    _,choice = self.subviews.list:getSelected()
    if not choice or not choice.gui_config then return end
    dfhack.run_command(choice.gui_config)
end

--
-- Overlays
--

Overlays = defclass(Overlays, widgets.Panel)

function Overlays:init()
    self:addviews{
    }
end

function Overlays:refresh()
end

--
-- SystemServices
--

SystemServices = defclass(SystemServices, widgets.Panel)

function SystemServices:init()
    self:addviews{
    }
end

function SystemServices:refresh()
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
