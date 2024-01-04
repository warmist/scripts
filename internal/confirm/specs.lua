--@module = true

-- remember to reload the overlay when adding/changing specs that have
-- intercept_frames defined

local json = require('json')

local CONFIG_FILE = 'dfhack-config/confirm.json'

REGISTRY = {}

ConfirmSpec = defclass(ConfirmSpec)
ConfirmSpec.ATTRS{
    id=DEFAULT_NIL,
    title='DFHack confirm',
    message='Are you sure?',
    intercept_keys={},
    intercept_frame=DEFAULT_NIL,
    context=DEFAULT_NIL,
    predicate=DEFAULT_NIL,
    pausable=false,
}

function ConfirmSpec:init()
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

    -- protect against copy-paste errors when defining new specs
    if REGISTRY[self.id] then
        error('id already registered: ' .. tostring(self.id))
    end

    -- auto-register
    REGISTRY[self.id] = self
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

ConfirmSpec{
    id='trade-cancel',
    title='Cancel trade',
    message='Are you sure you want leave this screen? Selected items will not be saved.',
    intercept_keys={'LEAVESCREEN', '_MOUSE_R'},
    context='dwarfmode/Trade',
    predicate=trade_goods_selected,
}

ConfirmSpec{
    id='diplomacy-request',
    title='Cancel trade agreement',
    message='Are you sure you want to leave this screen? The trade agreement selection will not be saved until you hit the "Done" button at the bottom of the screen.',
    intercept_keys={'LEAVESCREEN', '_MOUSE_R'},
    context='dwarfmode/Diplomacy/Requests',
    predicate=trade_agreement_items_selected,
}

ConfirmSpec{
    id='haul-delete-route',
    title='Delete hauling route',
    message='Are you sure you want to delete this route?',
    intercept_keys='_MOUSE_L',
    context='dwarfmode/Hauling',
    predicate=function() return df.global.game.main_interface.current_hover == 180 end,
    pausable=true,
}

ConfirmSpec{
    id='haul-delete-stop',
    title='Delete hauling stop',
    message='Are you sure you want to delete this stop?',
    intercept_keys='_MOUSE_L',
    context='dwarfmode/Hauling',
    predicate=function() return df.global.game.main_interface.current_hover == 185 end,
    pausable=true,
}

ConfirmSpec{
    id='depot-remove',
    title='Remove depot',
    message='Are you sure you want to remove this depot? Merchants are present and will lose profits.',
    intercept_keys='_MOUSE_L',
    context='dwarfmode/ViewSheets/BUILDING/TradeDepot',
    predicate=function()
        return df.global.game.main_interface.current_hover == 301 and has_caravans()
    end,
}

ConfirmSpec{
    id='squad-disband',
    title='Disband squad',
    message='Are you sure you want to disband this squad?',
    intercept_keys='_MOUSE_L',
    context='dwarfmode/Squads',
    predicate=function() return df.global.game.main_interface.current_hover == 343 end,
    pausable=true,
}

ConfirmSpec{
    id='order-remove',
    title='Remove manger order',
    message='Are you sure you want to remove this manager order?',
    intercept_keys='_MOUSE_L',
    context='dwarfmode/Info/WORK_ORDERS/Default',
    predicate=function() return df.global.game.main_interface.current_hover == 222 end,
    pausable=true,
}

ConfirmSpec{
    id='zone-remove',
    title='Remove zone',
    message='Are you sure you want to remove this zone?',
    intercept_keys='_MOUSE_L',
    context='dwarfmode/Zone',
    intercept_frame={l=40, t=8, w=4, h=3},
    pausable=true,
}

ConfirmSpec{
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

ConfirmSpec{
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

local function get_config()
    local f = json.open(CONFIG_FILE)
    local updated = false
    -- scrub any invalid data
    for id in pairs(f.data) do
        if not REGISTRY[id] then
            updated = true
            f.data[id] = nil
        end
    end
    -- add any missing confirmation ids
    for id in pairs(REGISTRY) do
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

config = get_config()
