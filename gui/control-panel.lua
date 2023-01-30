local dialogs = require('gui.dialogs')
local gui = require('gui')
local helpdb = require('helpdb')
local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')

local SETTINGS_INIT_FILE = 'dfhack-config/init/dfhack.control-panel.init'
local REFRESH_MS = 10000

-- eventually this should be queryable from script-manager
local FORT_SERVICES = {
    'autobutcher',
    'autochop',
    'autoclothing',
    'autofarm',
    'autofish',
    'autoslab',
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
    ['gui']={
        DEFAULT_INITIAL_PAUSE={type='bool',
         desc='Whether to pause the game when a DFHack tool is shown.'},
    },
    ['gui.widgets']={
        DOUBLE_CLICK_MS={type='int', min=50,
         desc='How long to wait for the second click of a double click, in ms.'},
        SCROLL_INITIAL_DELAY_MS={type='int', min=5,
         desc='The delay before scrolling quickly when holding the mouse button down on a scrollbar, in ms.'},
        SCROLL_DELAY_MS={type='int', min=5,
         desc='The delay between events when holding the mouse button down on a scrollbar, in ms.'},
    },
}

local function get_icon_pens()
    local start = dfhack.textures.getOnOffTexposStart()
    local enabled_pen = dfhack.pen.parse{
            tile=(start>0) and (start+0) or nil,
            ch=string.byte('+'), fg=COLOR_LIGHTGREEN}
    local disabled_pen = dfhack.pen.parse{
            tile=(start>0) and (start+1) or nil,
            ch=string.byte('-'), fg=COLOR_RED}
    return enabled_pen, disabled_pen
end
local ENABLED_ICON_PEN, DISABLED_ICON_PEN = get_icon_pens()

--
-- ConfigPanel
--

ConfigPanel = defclass(ConfigPanel, widgets.Panel)
ConfigPanel.ATTRS{
    intro_text=DEFAULT_NIL,
    is_enableable=DEFAULT_NIL,
    select_label='Toggle enabled',
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
            label=self.select_label,
            key='SELECT',
            enabled=self.is_enableable,
            on_activate=self:callback('on_submit')
        },
        widgets.HotkeyLabel{
            view_id='show_help_label',
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
                self:on_submit()
            elseif x >= 2 and x <= 7 then
                self:show_help()
            elseif x >= 9 and x <= 19 then
                self:launch_config()
            end
        end
    end
    return handled
end

function ConfigPanel:refresh()
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
        local icon_pen = choice.enabled and ENABLED_ICON_PEN or DISABLED_ICON_PEN
        table.insert(choices,
                {text=text, command=choice.command, target=choice.target, desc=desc,
                 search_key=choice.target, icon=icon_pen,
                 gui_config=has_gui_config and gui_config})
    end
    local list = self.subviews.list
    local filter = list:getFilter()
    local selected = list:getSelected()
    list:setChoices(choices)
    list:setFilter(filter, selected)
    list.edit:setFocus(true)
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

function ConfigPanel:on_submit()
    if not self.is_enableable() then return false end
    _,choice = self.subviews.list:getSelected()
    if not choice then return end
    local is_enabled = choice.icon == ENABLED_ICON_PEN
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

IntegerInputDialog = defclass(IntegerInputDialog, widgets.Window)
IntegerInputDialog.ATTRS{
    visible=false,
    frame={w=50, h=8},
    frame_title='Edit setting',
    frame_style=gui.PANEL_FRAME,
    on_hide=DEFAULT_NIL,
}

function IntegerInputDialog:init()
    self:addviews{
        widgets.Label{
            frame={t=0, l=0},
            text={
                'Please enter a new value for ',
                {text=function() return self.id or '' end},
                NEWLINE,
                {text=self:callback('get_spec_str')},
            },
        },
        widgets.EditField{
            view_id='input_edit',
            frame={t=3, l=0},
            on_char=function(ch) return ch:match('%d') end,
        },
    }
end

function IntegerInputDialog:get_spec_str()
    if not self.spec or (not self.spec.min and not self.spec.max) then
        return ''
    end
    local strs = {}
    if self.spec.min then
        table.insert(strs, ('at least %d'):format(self.spec.min))
    end
    if self.spec.max then
        table.insert(strs, ('at most %d'):format(self.spec.max))
    end
    return ('(%s)'):format(table.concat(strs, ', '))
end

function IntegerInputDialog:show(id, spec, initial)
    self.visible = true
    self.id, self.spec = id, spec
    local edit = self.subviews.input_edit
    edit:setText(tostring(initial))
    edit:setFocus(true)
    self:updateLayout()
end

function IntegerInputDialog:hide(val)
    self.visible = false
    self.on_hide(tonumber(val))
end

function IntegerInputDialog:onInput(keys)
    if IntegerInputDialog.super.onInput(self, keys) then
        return true
    end
    if keys.SELECT then
        self:hide(self.subviews.input_edit.text)
        return true
    elseif keys.LEAVESCREEN or keys._MOUSE_R_DOWN then
        self:hide()
        return true
    end
end

Preferences = defclass(Preferences, ConfigPanel)
Preferences.ATTRS{
    is_enableable=function() return true end,
    intro_text='These are the customizable DFHack system settings.',
    select_label='Edit setting',
}

function Preferences:init()
    self.subviews.show_help_label.visible = false
    self.subviews.launch.visible = false
    self:addviews{
        widgets.HotkeyLabel{
            frame={b=0, l=0},
            label='Save custom settings',
            key='CUSTOM_CTRL_G',
            on_activate=self:callback('do_save')
        },
        IntegerInputDialog{
            view_id='input_dlg',
            on_hide=self:callback('set_val'),
        },
    }
end

function Preferences:onInput(keys)
    -- call grandparent's onInput since we don't want ConfigPanel's processing
    local handled = Preferences.super.super.onInput(self, keys)
    if keys._MOUSE_L_DOWN then
        local list = self.subviews.list.list
        local idx = list:getIdxUnderMouse()
        if idx then
            local x = list:getMousePos()
            if x >= 2 and x <= 9 then
                self:on_submit()
            end
        end
    end
    return handled
end

function Preferences:refresh()
    if self.subviews.input_dlg.visible then return end
    local choices = {}
    for ctx_name,settings in pairs(SETTINGS) do
        local ctx_env = require(ctx_name)
        for id,spec in pairs(settings) do
            local text = {
                '[change] ',
                id,
                ' (',
                tostring(ctx_env[id]),
                ')',
            }
            table.insert(choices,
                {text=text, desc=spec.desc, search_key=id,
                 ctx_env=ctx_env, id=id, spec=spec})
        end
    end
    local list = self.subviews.list
    local filter = list:getFilter()
    local selected = list:getSelected()
    list:setChoices(choices)
    list:setFilter(filter, selected)
    list.edit:setFocus(true)
end

function Preferences:on_submit()
    _,choice = self.subviews.list:getSelected()
    if not choice then return end
    if choice.spec.type == 'bool' then
        choice.ctx_env[choice.id] = not choice.ctx_env[choice.id]
        self:refresh()
    elseif choice.spec.type == 'int' then
        self.subviews.input_dlg:show(choice.id, choice.spec,
                                     choice.ctx_env[choice.id])
    end
end

function Preferences:set_val(val)
    _,choice = self.subviews.list:getSelected()
    if not choice or not val then return end
    choice.ctx_env[choice.id] = val
    self:refresh()
end

function Preferences:do_save()
    local ok, f = pcall(io.open, SETTINGS_INIT_FILE, 'w')
    if not ok then
        dialogs.showMessage('Error',
            ('Cannot open settings file for writing: "%s"'):format(SETTINGS_INIT_FILE))
        return
    end
    f:write('# DO NOT EDIT THIS FILE\n')
    f:write('# Please use gui/control-panel to edit this file\n\n')
    for ctx_name,settings in pairs(SETTINGS) do
        local ctx_env = require(ctx_name)
        for id in pairs(settings) do
            f:write((':lua require("%s").%s=%s\n'):format(
                    ctx_name, id, tostring(ctx_env[id])))
        end
    end
    f:close()
    dialogs.showMessage('Success',
            ('Saved settings to "%s"'):format(SETTINGS_INIT_FILE))
end

--
-- ControlPanel
--

ControlPanel = defclass(ControlPanel, widgets.Window)
ControlPanel.ATTRS {
    frame_title='DFHack Control Panel',
    frame={w=55, h=35},
    resizable=true,
    resize_min={h=20},
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
