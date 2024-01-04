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

local function get_num_uniforms()
    local site = df.global.world.world_data.active_site[0]
    for _, entity_site_link in ipairs(site.entity_links) do
        local he = df.historical_entity.find(entity_site_link.entity_id)
        if he and he.type == df.historical_entity_type.SiteGovernment then
            return #he.uniforms
        end
    end
    return 0
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
    id='uniform-delete',
    title='Delete uniform',
    message='Are you sure you want to delete this uniform?',
    intercept_keys='_MOUSE_L',
    intercept_frame={r=131, t=23, w=6, h=27},
    context='dwarfmode/AssignUniform',
    predicate=function(mouse_offset)
        local num_uniforms = get_num_uniforms()
        if num_uniforms == 0 then return false end
        -- adjust detection area depending on presence of scrollbar
        if num_uniforms > 8 and mouse_offset.x > 2 then
            return false
        elseif num_uniforms <= 8 and mouse_offset.x <= 1 then
            return false
        end
        -- exclude the "No uniform" option (which has no delete button)
        return mouse_offset.y // 3 < num_uniforms - mi.assign_uniform.scroll_position
    end,
    pausable=true,
}

local selected_convict_name = 'this creature'
ConfirmSpec{
    id='convict',
    title='Confirm conviction',
    message=function()
        return ('Are you sure you want to convict %s? This action is irreversible.'):format(selected_convict_name)
    end,
    intercept_keys='_MOUSE_L',
    intercept_frame={r=31, t=14, w=11, b=5},
    context='dwarfmode/Info/JUSTICE/Convicting',
    predicate=function(mouse_offset)
        local justice = mi.info.justice
        local num_choices = #justice.conviction_list
        if num_choices == 0 then return false end
        local sw, sh = dfhack.screen.getWindowSize()
        local y_offset = sw >= 155 and 0 or 4
        local max_visible_buttons = (sh - (19 + y_offset)) // 3
        -- adjust detection area depending on presence of scrollbar
        if num_choices > max_visible_buttons and mouse_offset.x > 9 then
            return false
        elseif num_choices <= max_visible_buttons and mouse_offset.x <= 1 then
            return false
        end
        local num_visible_buttons = math.min(num_choices, max_visible_buttons)
        local selected_button_offset = (mouse_offset.y - y_offset) // 3
        if selected_button_offset >= num_visible_buttons then
            return false
        end
        local unit = justice.conviction_list[selected_button_offset + justice.scroll_position_conviction]
        selected_convict_name = dfhack.TranslateName(dfhack.units.getVisibleName(unit))
        if selected_convict_name == '' then
            selected_convict_name = 'this creature'
        end
        return true
    end,
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

ConfirmSpec{
    id='embark-site-finder',
    title='Re-run finder',
    message='Are you sure you want to re-run the site finder? Your current map highlights will be lost.',
    intercept_keys='_MOUSE_L',
    intercept_frame={r=2, t=36, w=7, h=3},
    context='choose_start_site/SiteFinder',
    predicate=function()
        return dfhack.gui.getDFViewscreen(true).find_results ~= df.viewscreen_choose_start_sitest.T_find_results.None
    end,
    pausable=true,
}

--------------------------
-- Config file management
--

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
