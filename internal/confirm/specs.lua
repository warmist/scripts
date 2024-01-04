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
    local diplomacy = mi.diplomacy
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
    intercept_frame={r=47, b=7, w=12, h=3},
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
    intercept_frame={l=0, r=72, b=7, w=12, h=3},
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
    id='trade-confirm-trade',
    title='Confirm trade',
    message="Are you sure you want to trade the selected goods?",
    intercept_keys='_MOUSE_L',
    intercept_frame={l=0, r=23, b=4, w=11, h=3},
    context='dwarfmode/Trade',
    predicate=function() return trade_goods_any_selected(0) and trade_goods_any_selected(1) end,
    pausable=true,
}

ConfirmSpec{
    id='trade-sieze',
    title='Sieze merchant goods',
    message='Are you sure you want size marked merchant goods? This will make the merchant unwilling to trade further and will damage relations with the merchant\'s civilization.',
    intercept_keys='_MOUSE_L',
    intercept_frame={l=0, r=73, b=4, w=11, h=3},
    context='dwarfmode/Trade',
    predicate=function() return mi.trade.mer.mood > 0 and trade_goods_any_selected(0) end,
    pausable=true,
}

ConfirmSpec{
    id='trade-offer',
    title='Offer fortress goods',
    message='Are you sure you want to offer these goods? You will receive no payment.',
    intercept_keys='_MOUSE_L',
    intercept_frame={l=40, r=5, b=4, w=19, h=3},
    context='dwarfmode/Trade',
    predicate=function() return trade_goods_any_selected(1) end,
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
    predicate=function() return mi.current_hover == 180 end,
    pausable=true,
}

ConfirmSpec{
    id='haul-delete-stop',
    title='Delete hauling stop',
    message='Are you sure you want to delete this stop?',
    intercept_keys='_MOUSE_L',
    context='dwarfmode/Hauling',
    predicate=function() return mi.current_hover == 185 end,
    pausable=true,
}

ConfirmSpec{
    id='depot-remove',
    title='Remove depot',
    message='Are you sure you want to remove this depot? Merchants are present and will lose profits.',
    intercept_keys='_MOUSE_L',
    context='dwarfmode/ViewSheets/BUILDING/TradeDepot',
    predicate=function()
        return mi.current_hover == 301 and has_caravans()
    end,
}

ConfirmSpec{
    id='squad-disband',
    title='Disband squad',
    message='Are you sure you want to disband this squad?',
    intercept_keys='_MOUSE_L',
    context='dwarfmode/Squads',
    predicate=function() return mi.current_hover == 343 end,
    pausable=true,
}

ConfirmSpec{
    id='order-remove',
    title='Remove manger order',
    message='Are you sure you want to remove this manager order?',
    intercept_keys='_MOUSE_L',
    context='dwarfmode/Info/WORK_ORDERS/Default',
    predicate=function() return mi.current_hover == 222 end,
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
        return mi.current_hover == 171 or mi.current_hover == 168
    end,
    pausable=true,
}

ConfirmSpec{
    id='stockpile-remove',
    title='Remove stockpile',
    message='Are you sure you want to remove this stockpile?',
    intercept_keys='_MOUSE_L',
    context='dwarfmode/Stockpile',
    predicate=function() return mi.current_hover == 118 end,
    pausable=true,
}

-- these confirmations have more complex button detection requirements
--[[


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
