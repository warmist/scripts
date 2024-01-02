--@ module = true

local gui = require('gui')
local json = require('json')
local overlay = require('plugins.overlay')
local widgets = require("gui.widgets")

local CONFIG_FILE = 'dfhack-config/confirm.json'

registry = registry or {}

------------------------
-- Confirmation configs

ConfirmConf = defclass(ConfirmConf)
ConfirmConf.ATTRS{
    id=DEFAULT_NIL,
    title='DFHack confirm',
    message='Are you sure?',
    intercept_keys={},
    context=DEFAULT_NIL,
    predicate=DEFAULT_NIL,
    pausable=false,
    intercept_frame=DEFAULT_NIL,
}

function ConfirmConf:init()
    if not self.id then
        error('must set id to a unique string')
    end
    if type(self.intercept_keys) ~= 'table' then
        self.intercept_keys = {self.intercept_keys}
    end
    for _, key in ipairs(self.intercept_keys) do
        if key ~= '_MOUSE_L' and key ~= '_MOUSE_R' and not df.interface_key[key] then
            error('Invalid key: ' .. tostring(key))
        end
    end
    if not self.context then
        error('context must be set to a bounding focus string')
    end

    -- auto-register
    registry[self.id] = self
end

local function trade_goods_selected()
    local function goods_selected(vec)
        for _, sel in ipairs(vec) do
            if sel == 1 then return true end
        end
    end

    return goods_selected(df.global.game.main_interface.trade.goodflag[0]) or
        goods_selected(df.global.game.main_interface.trade.goodflag[1])
end

local function trade_agreement_items_selected()
    local diplomacy = df.global.game.main_interface.diplomacy
    for _, tab in ipairs(diplomacy.environment.meeting.sell_requests.priority) do
        for _, priority in ipairs(tab) do
            if priority ~= 0 then
                return true
            end
        end
    end
end

local function has_caravans()
    for _, caravan in pairs(df.global.plotinfo.caravans) do
        if caravan.time_remaining > 0 then
            return true
        end
    end
end

ConfirmConf{
    id='trade-cancel',
    title='Cancel trade',
    message='Are you sure you want leave this screen? Selected items will not be saved.',
    intercept_keys={'LEAVESCREEN', '_MOUSE_R'},
    context='dwarfmode/Trade',
    predicate=trade_goods_selected,
}

ConfirmConf{
    id='diplomacy-request',
    title='Cancel trade agreement',
    message='Are you sure you want to leave this screen? The trade agreement selection will not be saved until you hit the "Done" button at the bottom of the screen.',
    intercept_keys={'LEAVESCREEN', '_MOUSE_R'},
    context='dwarfmode/Diplomacy/Requests',
    predicate=trade_agreement_items_selected,
}

ConfirmConf{
    id='haul-delete-route',
    title='Delete hauling route',
    message='Are you sure you want to delete this route?',
    intercept_keys='_MOUSE_L',
    context='dwarfmode/Hauling',
    predicate=function() return df.global.game.main_interface.current_hover == 180 end,
    pausable=true,
}

ConfirmConf{
    id='haul-delete-stop',
    title='Delete hauling stop',
    message='Are you sure you want to delete this stop?',
    intercept_keys='_MOUSE_L',
    context='dwarfmode/Hauling',
    predicate=function() return df.global.game.main_interface.current_hover == 185 end,
    pausable=true,
}

ConfirmConf{
    id='depot-remove',
    title='Remove depot',
    message='Are you sure you want to remove this depot? Merchants are present and will lose profits.',
    intercept_keys='_MOUSE_L',
    context='dwarfmode/ViewSheets/BUILDING/TradeDepot',
    predicate=function()
        return df.global.game.main_interface.current_hover == 301 and has_caravans()
    end,
}

ConfirmConf{
    id='squad-disband',
    title='Disband squad',
    message='Are you sure you want to disband this squad?',
    intercept_keys='_MOUSE_L',
    context='dwarfmode/Squads',
    predicate=function() return df.global.game.main_interface.current_hover == 343 end,
    pausable=true,
}

ConfirmConf{
    id='order-remove',
    title='Remove manger order',
    message='Are you sure you want to remove this manager order?',
    intercept_keys='_MOUSE_L',
    context='dwarfmode/Info/WORK_ORDERS/Default',
    predicate=function() return df.global.game.main_interface.current_hover == 222 end,
    pausable=true,
}

ConfirmConf{
    id='zone-remove',
    title='Remove zone',
    message='Are you sure you want to remove this zone?',
    intercept_keys='_MOUSE_L',
    context='dwarfmode/Zone',
    predicate=function() return df.global.game.main_interface.current_hover == 130 end,
    pausable=true,
}

ConfirmConf{
    id='burrow-remove',
    title='Remove burrow',
    message='Are you sure you want to remove this burrow?',
    intercept_keys='_MOUSE_L',
    context='dwarfmode/Burrow',
    predicate=function()
        return df.global.game.main_interface.current_hover == 171 or
            df.global.game.main_interface.current_hover == 168
    end,
    pausable=true,
}

ConfirmConf{
    id='stockpile-remove',
    title='Remove stockpile',
    message='Are you sure you want to remove this stockpile?',
    intercept_keys='_MOUSE_L',
    context='dwarfmode/Stockpile',
    predicate=function() return df.global.game.main_interface.current_hover == 118 end,
    pausable=true,
}

-- these confirmations have more complex button detection requirements
--[[
trade = defconf('trade')
function trade.intercept_key(key)
    dfhack.gui.matchFocusString("dwarfmode/Trade") and key == MOUSE_LEFT and hovering over trade button?
end
trade.title = "Confirm trade"
function trade.get_message()
    if trader_goods_selected() and broker_goods_selected() then
        return "Are you sure you want to trade the selected goods?"
    elseif trader_goods_selected() then
        return "You are not giving any items. This is likely\n" ..
            "to irritate the merchants.\n" ..
            "Attempt to trade anyway?"
    elseif broker_goods_selected() then
        return "You are not receiving any items. You may want to\n" ..
            "offer these items instead or choose items to receive.\n" ..
            "Attempt to trade anyway?"
    else
        return "No items are selected. This is likely\n" ..
            "to irritate the merchants.\n" ..
            "Attempt to trade anyway?"
    end
end

trade_seize = defconf('trade-seize')
function trade_seize.intercept_key(key)
    return screen.in_edit_count == 0 and
        trader_goods_selected() and
        key == keys.TRADE_SEIZE
end
trade_seize.title = "Confirm seize"
trade_seize.message = "Are you sure you want to seize these goods?"

trade_offer = defconf('trade-offer')
function trade_offer.intercept_key(key)
    return screen.in_edit_count == 0 and
        broker_goods_selected() and
        key == keys.TRADE_OFFER
end
trade_offer.title = "Confirm offer"
trade_offer.message = "Are you sure you want to offer these goods?\nYou will receive no payment."

trade_select_all = defconf('trade-select-all')
function trade_select_all.intercept_key(key)
    if screen.in_edit_count == 0 and key == keys.SEC_SELECT then
        if screen.in_right_pane and broker_goods_selected() and not broker_goods_all_selected() then
            return true
        elseif not screen.in_right_pane and trader_goods_selected() and not trader_goods_all_selected() then
            return true
        end
    end
    return false
end
trade_select_all.title = "Confirm selection"
trade_select_all.message = "Selecting all goods will overwrite your current selection\n" ..
        "and cannot be undone. Continue?"

uniform_delete = defconf('uniform-delete')
function uniform_delete.intercept_key(key)
    return key == keys.D_MILITARY_DELETE_UNIFORM and
        screen.page == screen._type.T_page.Uniforms and
        #screen.equip.uniforms > 0 and
        not screen.equip.in_name_uniform
end
uniform_delete.title = "Delete uniform"
uniform_delete.message = "Are you sure you want to delete this uniform?"

note_delete = defconf('note-delete')
function note_delete.intercept_key(key)
    return key == keys.D_NOTE_DELETE and
        ui.main.mode == df.ui_sidebar_mode.NotesPoints and
        not ui.waypoints.in_edit_name_mode and
        not ui.waypoints.in_edit_text_mode
end
note_delete.title = "Delete note"
note_delete.message = "Are you sure you want to delete this note?"

route_delete = defconf('route-delete')
function route_delete.intercept_key(key)
    return key == keys.D_NOTE_ROUTE_DELETE and
        ui.main.mode == df.ui_sidebar_mode.NotesRoutes and
        not ui.waypoints.in_edit_name_mode
end
route_delete.title = "Delete route"
route_delete.message = "Are you sure you want to delete this route?"

convict = defconf('convict')
convict.title = "Confirm conviction"
function convict.intercept_key(key)
    return key == keys.SELECT and
        screen.cur_column == df.viewscreen_justicest.T_cur_column.ConvictChoices
end
function convict.get_message()
    name = dfhack.TranslateName(dfhack.units.getVisibleName(screen.convict_choices[screen.cursor_right]))
    if name == "" then
        name = "this creature"
    end
    return "Are you sure you want to convict " .. name .. "?\n" ..
        "This action is irreversible."
end
]]--

-- locations cannot be retired currently
--[[
location_retire = defconf('location-retire')
function location_retire.intercept_key(key)
    return key == keys.LOCATION_RETIRE and
        (screen.menu == df.viewscreen_locationsst.T_menu.Locations or
            screen.menu == df.viewscreen_locationsst.T_menu.Occupations) and
        screen.in_edit == df.viewscreen_locationsst.T_in_edit.None and
        screen.locations[screen.location_idx]
end
location_retire.title = "Retire location"
location_retire.message = "Are you sure you want to retire this location?"
]]--

-- End of confirmation definitions

------------------------
-- API

local function get_config()
    local f = json.open(CONFIG_FILE)
    local updated = false
    -- scrub any invalid data
    for id, conf in pairs(f.data) do
        if not registry[id] then
            updated = true
            f.data[id] = nil
        end
    end
    -- add any missing confirmation ids
    for id in pairs(registry) do
        if not f.data[id] then
            updated = true
            f.data[id] = {
                id=id,
                enabled=true,
            }
        end
    end
    if updated then
        f:write()
    end
    return f
end

config = config or get_config()

function get_state()
    return config.data
end

function set_enabled(id, enabled)
    for _, conf in pairs(config.data) do
        if conf.id == id then
            if conf.enabled ~= enabled then
                conf.enabled = enabled
                config:write()
            end
            break
        end
    end
end

------------------------
-- Overlay

PromptWindow = defclass(PromptWindow, widgets.Window)
PromptWindow.ATTRS {
    frame={w=47, h=12},
    conf=DEFAULT_NIL,
    propagate_fn=DEFAULT_NIL,
}

function PromptWindow:init()
    self:addviews{
        widgets.WrappedLabel{
            frame={t=0, l=0, r=0},
            text_to_wrap=self.conf.message,
        },
        widgets.HotkeyLabel{
            frame={b=1, l=0},
            label='Yes, proceed',
            key='SELECT',
            auto_width=true,
            on_activate=self:callback('proceed'),
        },
        widgets.HotkeyLabel{
            frame={b=1, l=32},
            label='Settings',
            key='CUSTOM_SHIFT_S',
            auto_width=true,
            on_activate=self:callback('settings'),
        },
        widgets.HotkeyLabel{
            frame={b=0, l=0},
            label='Pause confirmations while on this screen',
            key='CUSTOM_SHIFT_P',
            auto_width=true,
            visible=self.conf.pausable,
            on_activate=self:callback('pause'),
        },
    }
end

function PromptWindow:proceed()
    self.parent_view:dismiss()
    self.propagate_fn()
end

function PromptWindow:settings()
    self.parent_view:dismiss()
    dfhack.run_script('gui/confirm', self.conf.id)
end

function PromptWindow:pause()
    self.parent_view:dismiss()
    self.propagate_fn(true)
end

PromptScreen = defclass(PromptScreen, gui.ZScreenModal)
PromptScreen.ATTRS {
    focus_path='confirm/prompt',
    conf=DEFAULT_NIL,
    propagate_fn=DEFAULT_NIL,
}

function PromptScreen:init()
    self:addviews{
        PromptWindow{
            frame_title=self.conf.title,
            conf=self.conf,
            propagate_fn=self.propagate_fn,
        }
    }
end

local function get_contexts()
    local contexts, contexts_set = {}, {}
    for id, conf in pairs(registry) do
        if not contexts_set[id] then
            contexts_set[id] = true
            table.insert(contexts, conf.context)
        end
    end
    return contexts
end

ConfirmOverlay = defclass(ConfirmOverlay, overlay.OverlayWidget)
ConfirmOverlay.ATTRS{
    desc='Detects dangerous actions and prompts with confirmation dialogs.',
    default_pos={x=1,y=1},
    default_enabled=true,
    overlay_only=true,  -- not player-repositionable
    hotspot=true,       -- need to unpause when we're not in target contexts
    overlay_onupdate_max_freq_seconds=300,
    viewscreens=get_contexts(),
}

function ConfirmOverlay:init()
end

function ConfirmOverlay:preUpdateLayout()
    self.frame.w, self.frame.h = dfhack.screen.getWindowSize()
end

function ConfirmOverlay:overlay_onupdate()
    if self.paused_conf and
        not dfhack.gui.matchFocusString(self.paused_conf.context,
                dfhack.gui.getDFViewscreen(true))
    then
        self.paused_conf = nil
        self.overlay_onupdate_max_freq_seconds = 300
    end
end

local function matches_conf(conf, keys, scr)
    local matched_keys = false
    for _, key in ipairs(conf.intercept_keys) do
        if keys[key] then
            matched_keys = true
            break
        end
    end
    if not matched_keys then return false end
    if not dfhack.gui.matchFocusString(conf.context, scr) then return false end
    return not conf.predicate or conf.predicate()
end

function ConfirmOverlay:onInput(keys)
    if self.paused_conf or self.simulating then
        return false
    end
    local scr = dfhack.gui.getDFViewscreen(true)
    for id, conf in pairs(registry) do
        if config.data[id].enabled and matches_conf(conf, keys, scr) then
            local mouse_pos = xy2pos(dfhack.screen.getMousePos())
            local propagate_fn = function(pause)
                if pause then
                    self.paused_conf = conf
                    self.overlay_onupdate_max_freq_seconds = 0
                end
                if keys._MOUSE_L then
                    df.global.gps.mouse_x = mouse_pos.x
                    df.global.gps.mouse_y = mouse_pos.y
                end
                self.simulating = true
                gui.simulateInput(scr, keys)
                self.simulating = false
            end
            PromptScreen{conf=conf, propagate_fn=propagate_fn}:show()
            return true
        end
    end
end

OVERLAY_WIDGETS = {
    overlay=ConfirmOverlay,
}

------------------------
-- CLI

local function do_list()
    print('Available confirmation prompts:')
    local max_len = 10
    for id in pairs(registry) do
        max_len = math.max(max_len, #id)
    end
    for id, conf in pairs(registry) do
        local fmt = '%' .. tostring(max_len) .. 's: (%s) %s'
        print((fmt):format(id,
            config.data[id].enabled and 'enabled' or 'disabled',
            conf.title))
    end
end

local function do_enable_disable(args, enable)
    if args[1] == 'all' then
        for id in pairs(registry) do
            set_enabled(id, enable)
        end
    else
        for _, id in ipairs(args) do
            if not registry[id] then
                qerror('confirmation prompt id not found: ' .. tostring(id))
            end
            set_enabled(id, enable)
        end
    end
end

local function main(args)
    local command = table.remove(args, 1)

    if not command or command == 'list' then
        do_list()
    elseif command == 'enable' or command == 'disable' then
        do_enable_disable(args, command == 'enable')
    elseif command == 'help' then
        print(dfhack.script_help())
    else
        dfhack.printerr('unknown command: ' .. tostring(command))
    end
end

if not dfhack_flags.module then
    main{...}
end
