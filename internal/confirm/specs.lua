--@module = true

-- if adding a new spec, just run `confirm` to load it and make it live
--
-- remember to reload the overlay when adding/changing specs that have
-- intercept_frames defined

local json = require('json')

local CONFIG_FILE = 'dfhack-config/confirm.json'

-- populated by ConfirmSpec constructor below
REGISTRY = {}

ConfirmSpec = defclass(ConfirmSpec)
ConfirmSpec.ATTRS{
    id=DEFAULT_NIL,
    title='DFHack confirm',
    message='Are you sure?',
    intercept_keys={},
    intercept_frame=DEFAULT_NIL,
    debug_frame=false, -- set to true when doing original positioning
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

local mi = df.global.game.main_interface

local function trade_goods_any_selected(which)
    for _, sel in ipairs(mi.trade.goodflag[which]) do
        if sel == 1 then return true end
    end
end

local function trade_goods_all_selected(which)
    for _, sel in ipairs(mi.trade.goodflag[which]) do
        if sel ~= 1 then return false end
    end
    return true
end

local function trade_agreement_items_any_selected()
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
    predicate=function() return trade_goods_any_selected(0) or trade_goods_any_selected(1) end,
}

ConfirmSpec{
    id='trade-mark-all-fort',
    title='Mark all fortress goods',
    message='Are you sure you want mark all fortress goods at the depot? Your current fortress goods selections will be lost.',
    intercept_keys='_MOUSE_L',
    intercept_frame={r=46, b=7, w=14, h=3},
    context='dwarfmode/Trade',
    predicate=function() return trade_goods_any_selected(1) and not trade_goods_all_selected(1) end,
    pausable=true,
}

ConfirmSpec{
    id='trade-unmark-all-fort',
    title='Unmark all fortress goods',
    message='Are you sure you want unmark all fortress goods at the depot? Your current fortress goods selections will be lost.',
    intercept_keys='_MOUSE_L',
    intercept_frame={r=30, b=7, w=14, h=3},
    context='dwarfmode/Trade',
    predicate=function() return trade_goods_any_selected(1) and not trade_goods_all_selected(1) end,
    pausable=true,
}

ConfirmSpec{
    id='trade-mark-all-merchant',
    title='Mark all merchant goods',
    message='Are you sure you want mark all merchant goods at the depot? Your current merchant goods selections will be lost.',
    intercept_keys='_MOUSE_L',
    intercept_frame={l=0, r=72, b=7, w=14, h=3},
    context='dwarfmode/Trade',
    predicate=function() return trade_goods_any_selected(0) and not trade_goods_all_selected(0) end,
    pausable=true,
}

ConfirmSpec{
    id='trade-unmark-all-merchant',
    title='Mark all merchant goods',
    message='Are you sure you want mark all merchant goods at the depot? Your current merchant goods selections will be lost.',
    intercept_keys='_MOUSE_L',
    intercept_frame={l=0, r=40, b=7, w=14, h=3},
    context='dwarfmode/Trade',
    predicate=function() return trade_goods_any_selected(0) and not trade_goods_all_selected(0) end,
    pausable=true,
}

ConfirmSpec{
    id='diplomacy-request',
    title='Cancel trade agreement',
    message='Are you sure you want to leave this screen? The trade agreement selection will not be saved until you hit the "Done" button at the bottom of the screen.',
    intercept_keys={'LEAVESCREEN', '_MOUSE_R'},
    context='dwarfmode/Diplomacy/Requests',
    predicate=trade_agreement_items_any_selected,
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

uniform_delete = defconf('uniform-delete')
function uniform_delete.intercept_key(key)
    return key == keys.D_MILITARY_DELETE_UNIFORM and
        screen.page == screen._type.T_page.Uniforms and
        #screen.equip.uniforms > 0 and
        not screen.equip.in_name_uniform
end
uniform_delete.title = "Delete uniform"
uniform_delete.message = "Are you sure you want to delete this uniform?"

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
