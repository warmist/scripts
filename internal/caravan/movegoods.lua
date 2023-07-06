--@ module = true

local common = reqscript('internal/caravan/common')
local dialogs = require('gui.dialogs')
local gui = require('gui')
local overlay = require('plugins.overlay')
local utils = require('utils')
local widgets = require('gui.widgets')

-- -------------------
-- MoveGoods
--

MoveGoods = defclass(MoveGoods, widgets.Window)
MoveGoods.ATTRS {
    frame_title='Select trade goods',
    frame={w=84, h=45},
    resizable=true,
    resize_min={w=81,h=35},
    pending_item_ids=DEFAULT_NIL,
}

local STATUS_COL_WIDTH = 7
local VALUE_COL_WIDTH = 8
local QTY_COL_WIDTH = 5

local function sort_noop(a, b)
    -- this function is used as a marker and never actually gets called
    error('sort_noop should not be called')
end

local function sort_base(a, b)
    return a.data.desc < b.data.desc
end

local function sort_by_name_desc(a, b)
    if a.search_key == b.search_key then
        return sort_base(a, b)
    end
    return a.search_key < b.search_key
end

local function sort_by_name_asc(a, b)
    if a.search_key == b.search_key then
        return sort_base(a, b)
    end
    return a.search_key > b.search_key
end

local function sort_by_value_desc(a, b)
    local value_field = a.item_id and 'per_item_value' or 'total_value'
    if a.data[value_field] == b.data[value_field] then
        return sort_by_name_desc(a, b)
    end
    return a.data[value_field] > b.data[value_field]
end

local function sort_by_value_asc(a, b)
    local value_field = a.item_id and 'per_item_value' or 'total_value'
    if a.data[value_field] == b.data[value_field] then
        return sort_by_name_desc(a, b)
    end
    return a.data[value_field] < b.data[value_field]
end

local function sort_by_status_desc(a, b)
    local a_unselected = a.data.selected == 0 or (a.item_id and not a.data.items[a.item_id].pending)
    local b_unselected = b.data.selected == 0 or (b.item_id and not b.data.items[b.item_id].pending)
    if a_unselected == b_unselected then
        return sort_by_value_desc(a, b)
    end
    return not a_unselected
end

local function sort_by_status_asc(a, b)
    local a_unselected = a.data.selected == 0 or (a.item_id and not a.data.items[a.item_id].pending)
    local b_unselected = b.data.selected == 0 or (b.item_id and not b.data.items[b.item_id].pending)
    if a_unselected == b_unselected then
        return sort_by_value_desc(a, b)
    end
    return not b_unselected
end

local function sort_by_quantity_desc(a, b)
    if a.data.quantity == b.data.quantity then
        return sort_by_value_desc(a, b)
    end
    return a.data.quantity > b.data.quantity
end

local function sort_by_quantity_asc(a, b)
    if a.data.quantity == b.data.quantity then
        return sort_by_value_desc(a, b)
    end
    return a.data.quantity < b.data.quantity
end

local function is_active_caravan(caravan)
    local trade_state = caravan.trade_state
    return caravan.time_remaining > 0 and
        (trade_state == df.caravan_state.T_trade_state.Approaching or
         trade_state == df.caravan_state.T_trade_state.AtDepot)
end

local function is_tree_lover_caravan(caravan)
    local caravan_he = df.historical_entity.find(caravan.entity);
    if not caravan_he then return false end
    local wood_ethic = caravan_he.entity_raw.ethic[df.ethic_type.KILL_PLANT]
    return wood_ethic == df.ethic_response.MISGUIDED or
        wood_ethic == df.ethic_response.SHUN or
        wood_ethic == df.ethic_response.APPALLING or
        wood_ethic == df.ethic_response.PUNISH_REPRIMAND or
        wood_ethic == df.ethic_response.PUNISH_SERIOUS or
        wood_ethic == df.ethic_response.PUNISH_EXILE or
        wood_ethic == df.ethic_response.PUNISH_CAPITAL or
        wood_ethic == df.ethic_response.UNTHINKABLE
end

local function is_animal_lover_caravan(caravan)
    local caravan_he = df.historical_entity.find(caravan.entity);
    if not caravan_he then return false end
    local animal_ethic = caravan_he.entity_raw.ethic[df.ethic_type.KILL_ANIMAL]
    return animal_ethic == df.ethic_response.JUSTIFIED_IF_SELF_DEFENSE or
        animal_ethic == df.ethic_response.JUSTIFIED_IF_EXTREME_REASON or
        animal_ethic == df.ethic_response.MISGUIDED or
        animal_ethic == df.ethic_response.SHUN or
        animal_ethic == df.ethic_response.APPALLING or
        animal_ethic == df.ethic_response.PUNISH_REPRIMAND or
        animal_ethic == df.ethic_response.PUNISH_SERIOUS or
        animal_ethic == df.ethic_response.PUNISH_EXILE or
        animal_ethic == df.ethic_response.PUNISH_CAPITAL or
        animal_ethic == df.ethic_response.UNTHINKABLE
end

local function get_ethics_restrictions()
    local animal_ethics, wood_ethics = false, false
    for _,caravan in ipairs(df.global.plotinfo.caravans) do
        if is_active_caravan(caravan) then
            animal_ethics = animal_ethics or is_animal_lover_caravan(caravan)
            wood_ethics = wood_ethics or is_tree_lover_caravan(caravan)
        end
    end
    return animal_ethics, wood_ethics
end

local function get_ethics_token(animal_ethics, wood_ethics)
    local restrictions = {}
    if animal_ethics or wood_ethics then
        if animal_ethics then table.insert(restrictions, "Animals") end
        if wood_ethics then table.insert(restrictions, "Trees") end
    end
    return {
        gap=2,
        text=#restrictions == 0 and 'None' or table.concat(restrictions, ', '),
        pen=#restrictions ~= 0 and COLOR_LIGHTRED or COLOR_GREY,
    }
end

-- works for both mandates and unit preferences
-- adds spec to registry, but only if not in filter
local function register_item_type(registry, spec, filter)
    if not safe_index(filter, spec.item_type, spec.item_subtype) then
        ensure_keys(registry, spec.item_type)[spec.item_subtype] = true
    end
end

local function get_banned_items()
    local banned_items = {}
    for _, mandate in ipairs(df.global.world.mandates) do
        if mandate.mode == df.mandate.T_mode.Export then
            register_item_type(banned_items, mandate)
        end
    end
    return banned_items
end

local function analyze_noble(unit, risky_items, banned_items)
    for _, preference in ipairs(unit.status.current_soul.preferences) do
        if preference.type == df.unit_preference.T_type.LikeItem and
            preference.active
        then
            register_item_type(risky_items, preference, banned_items)
        end
    end
end

local function get_mandate_noble_roles()
    local roles = {}
    for _, link in ipairs(df.global.world.world_data.active_site[0].entity_links) do
        local he = df.historical_entity.find(link.entity_id);
        if not he or
            (he.type ~= df.historical_entity_type.SiteGovernment and
             he.type ~= df.historical_entity_type.Civilization)
        then
            goto continue
        end
        for _, position in ipairs(he.positions.own) do
            if position.mandate_max > 0 then
                table.insert(roles, position.code)
            end
        end
        ::continue::
    end
    return roles
end

local function get_risky_items(banned_items)
    local risky_items = {}
    for _, role in ipairs(get_mandate_noble_roles()) do
        for _, unit in ipairs(dfhack.units.getUnitsByNobleRole(role)) do
            analyze_noble(unit, risky_items, banned_items)
        end
    end
    return risky_items
end

local function make_item_description(item_type, subtype)
    local itemdef = dfhack.items.getSubtypeDef(item_type, subtype)
    return itemdef and string.lower(itemdef.name_plural) or
        string.lower(df.item_type[item_type]):gsub('_', ' ')
end

local function get_banned_token(banned_items)
    if not next(banned_items) then
        return {
            gap=2,
            text='None',
            pen=COLOR_GREY,
        }
    end
    local strs = {}
    for item_type, subtypes in pairs(banned_items) do
        for subtype in pairs(subtypes) do
            table.insert(strs, make_item_description(item_type, subtype))
        end
    end
    return {
        gap=2,
        text=table.concat(strs, ', '),
        pen=COLOR_LIGHTRED,
    }
end

local function get_export_agreements()
    local export_agreements = {}
    for _,caravan in ipairs(df.global.plotinfo.caravans) do
        if caravan.buy_prices and is_active_caravan(caravan) then
            table.insert(export_agreements, caravan.buy_prices)
        end
    end
    return export_agreements
end

local function show_export_agreements(export_agreements)
    local strs = {}
    for _, agreement in ipairs(export_agreements) do
        for idx, price in ipairs(agreement.price) do
            local desc = make_item_description(agreement.items.item_type[idx], agreement.items.item_subtype[idx])
            local percent = (price * 100) // 256
            table.insert(strs, ('%20s %d%%'):format(desc..':', percent))
        end
    end
    dialogs.showMessage('Price agreement for exported items', table.concat(strs, '\n'))
end

function MoveGoods:init()
    self.value_pending = 0

    local export_agreements = get_export_agreements()
    local animal_ethics, wood_ethics = get_ethics_restrictions()
    local banned_items = get_banned_items()
    self.risky_items = get_risky_items(banned_items)

    self:addviews{
        widgets.CycleHotkeyLabel{
            view_id='sort',
            frame={l=0, t=0, w=21},
            label='Sort by:',
            key='CUSTOM_SHIFT_S',
            options={
                {label='status'..common.CH_DN, value=sort_by_status_desc},
                {label='status'..common.CH_UP, value=sort_by_status_asc},
                {label='value'..common.CH_DN, value=sort_by_value_desc},
                {label='value'..common.CH_UP, value=sort_by_value_asc},
                {label='qty'..common.CH_DN, value=sort_by_quantity_desc},
                {label='qty'..common.CH_UP, value=sort_by_quantity_asc},
                {label='name'..common.CH_DN, value=sort_by_name_desc},
                {label='name'..common.CH_UP, value=sort_by_name_asc},
            },
            initial_option=sort_by_status_desc,
            on_change=self:callback('refresh_list', 'sort'),
        },
        widgets.EditField{
            view_id='search',
            frame={l=26, t=0},
            label_text='Search: ',
            on_char=function(ch) return ch:match('[%l -]') end,
        },
        widgets.ToggleHotkeyLabel{
            view_id='hide_forbidden',
            frame={t=2, l=0, w=27},
            label='Hide forbidden items:',
            key='CUSTOM_SHIFT_F',
            options={
                {label='Yes', value=true, pen=COLOR_GREEN},
                {label='No', value=false}
            },
           initial_option=false,
            on_change=function() self:refresh_list() end,
        },
        widgets.Panel{
            frame={t=4, l=0, w=41, h=2},
            subviews={
                widgets.Label{
                    frame={t=0, l=0},
                    text={
                        'Merchant export agreements:',
                        {gap=1, text='None', pen=COLOR_GREY},
                    },
                },
                widgets.HotkeyLabel{
                    frame={t=0, l=28},
                    key='CUSTOM_SHIFT_H',
                    label='[details]',
                    text_pen=COLOR_LIGHTRED,
                    on_activate=function() show_export_agreements(export_agreements) end,
                    visible=#export_agreements > 0,
                },
                widgets.ToggleHotkeyLabel{
                    view_id='only_agreement',
                    frame={t=1, l=0},
                    label='Show only requested items:',
                    key='CUSTOM_SHIFT_A',
                    options={
                        {label='Yes', value=true, pen=COLOR_GREEN},
                        {label='No', value=false}
                    },
                    initial_option=false,
                    on_change=function() self:refresh_list() end,
                    visible=#export_agreements > 0,
                },
            },
        },
        widgets.Panel{
            frame={t=7, l=0, r=40, h=3},
            subviews={
                widgets.Label{
                    frame={t=0, l=0},
                    text={
                        'Merchant ethical restrictions:', NEWLINE,
                        get_ethics_token(animal_ethics, wood_ethics),
                    },
                },
                widgets.CycleHotkeyLabel{
                    view_id='ethical',
                    frame={t=2, l=0},
                    key='CUSTOM_SHIFT_G',
                    options={
                        {label='Show only ethically acceptable items', value='only', pen=COLOR_GREEN},
                        {label='Ignore ethical restrictions', value='show'},
                        {label='Show only ethically unacceptable items', value='hide', pen=COLOR_RED},
                    },
                    initial_option='only',
                    option_gap=0,
                    visible=animal_ethics or wood_ethics,
                    on_change=function() self:refresh_list() end,
                },
            },
        },
        widgets.Panel{
            frame={t=11, l=0, r=40, h=5},
            subviews={
                widgets.Label{
                    frame={t=0, l=0},
                    text={
                        'Items banned by export mandates:', NEWLINE,
                        get_banned_token(banned_items), NEWLINE,
                        'Additional items at risk of mandates:', NEWLINE,
                        get_banned_token(self.risky_items),
                    },
                },
                widgets.CycleHotkeyLabel{
                    view_id='banned',
                    frame={t=4, l=0},
                    key='CUSTOM_SHIFT_D',
                    options={
                        {label='Hide banned and risky items', value='both', pen=COLOR_GREEN},
                        {label='Hide banned items', value='banned_only', pen=COLOR_YELLOW},
                        {label='Ignore mandate restrictions', value='ignore', pen=COLOR_RED},
                    },
                    initial_option='both',
                    option_gap=0,
                    visible=next(banned_items) or next(self.risky_items),
                    on_change=function() self:refresh_list() end,
                },
            },
        },
        widgets.Panel{
            frame={t=2, r=0, w=38, h=4},
            subviews={
                widgets.CycleHotkeyLabel{
                    view_id='min_condition',
                    frame={l=0, t=0, w=18},
                    label='Min condition:',
                    label_below=true,
                    key_back='CUSTOM_SHIFT_C',
                    key='CUSTOM_SHIFT_V',
                    options={
                        {label='XXTatteredXX', value=3},
                        {label='XFrayedX', value=2},
                        {label='xWornx', value=1},
                        {label='Pristine', value=0},
                    },
                    initial_option=3,
                    on_change=function(val)
                        if self.subviews.max_condition:getOptionValue() > val then
                            self.subviews.max_condition:setOption(val)
                        end
                        self:refresh_list()
                    end,
                },
                widgets.CycleHotkeyLabel{
                    view_id='max_condition',
                    frame={r=1, t=0, w=18},
                    label='Max condition:',
                    label_below=true,
                    key_back='CUSTOM_SHIFT_E',
                    key='CUSTOM_SHIFT_R',
                    options={
                        {label='XXTatteredXX', value=3},
                        {label='XFrayedX', value=2},
                        {label='xWornx', value=1},
                        {label='Pristine', value=0},
                    },
                    initial_option=0,
                    on_change=function(val)
                        if self.subviews.min_condition:getOptionValue() < val then
                            self.subviews.min_condition:setOption(val)
                        end
                        self:refresh_list()
                    end,
                },
                widgets.RangeSlider{
                    frame={l=0, t=3},
                    num_stops=4,
                    get_left_idx_fn=function()
                        return 4 - self.subviews.min_condition:getOptionValue()
                    end,
                    get_right_idx_fn=function()
                        return 4 - self.subviews.max_condition:getOptionValue()
                    end,
                    on_left_change=function(idx) self.subviews.min_condition:setOption(4-idx, true) end,
                    on_right_change=function(idx) self.subviews.max_condition:setOption(4-idx, true) end,
                },
            },
        },
        widgets.Panel{
            frame={t=7, r=0, w=38, h=4},
            subviews={
                widgets.CycleHotkeyLabel{
                    view_id='min_quality',
                    frame={l=0, t=0, w=18},
                    label='Min quality:',
                    label_below=true,
                    key_back='CUSTOM_SHIFT_Z',
                    key='CUSTOM_SHIFT_X',
                    options={
                        {label='Ordinary', value=0},
                        {label='-Well Crafted-', value=1},
                        {label='+Finely Crafted+', value=2},
                        {label='*Superior*', value=3},
                        {label=common.CH_EXCEPTIONAL..'Exceptional'..common.CH_EXCEPTIONAL, value=4},
                        {label=common.CH_MONEY..'Masterful'..common.CH_MONEY, value=5},
                        {label='Artifact', value=6},
                    },
                    initial_option=0,
                    on_change=function(val)
                        if self.subviews.max_quality:getOptionValue() < val then
                            self.subviews.max_quality:setOption(val)
                        end
                        self:refresh_list()
                    end,
                },
                widgets.CycleHotkeyLabel{
                    view_id='max_quality',
                    frame={r=1, t=0, w=18},
                    label='Max quality:',
                    label_below=true,
                    key_back='CUSTOM_SHIFT_Q',
                    key='CUSTOM_SHIFT_W',
                    options={
                        {label='Ordinary', value=0},
                        {label='-Well Crafted-', value=1},
                        {label='+Finely Crafted+', value=2},
                        {label='*Superior*', value=3},
                        {label=common.CH_EXCEPTIONAL..'Exceptional'..common.CH_EXCEPTIONAL, value=4},
                        {label=common.CH_MONEY..'Masterful'..common.CH_MONEY, value=5},
                        {label='Artifact', value=6},
                    },
                    initial_option=6,
                    on_change=function(val)
                        if self.subviews.min_quality:getOptionValue() > val then
                            self.subviews.min_quality:setOption(val)
                        end
                        self:refresh_list()
                    end,
                },
                widgets.RangeSlider{
                    frame={l=0, t=3},
                    num_stops=7,
                    get_left_idx_fn=function()
                        return self.subviews.min_quality:getOptionValue() + 1
                    end,
                    get_right_idx_fn=function()
                        return self.subviews.max_quality:getOptionValue() + 1
                    end,
                    on_left_change=function(idx) self.subviews.min_quality:setOption(idx-1, true) end,
                    on_right_change=function(idx) self.subviews.max_quality:setOption(idx-1, true) end,
                },
            },
        },
        widgets.Panel{
            frame={t=12, r=0, w=38, h=4},
            subviews={
                widgets.CycleHotkeyLabel{
                    view_id='min_value',
                    frame={l=0, t=0, w=18},
                    label='Min value:',
                    label_below=true,
                    key_back='CUSTOM_SHIFT_B',
                    key='CUSTOM_SHIFT_N',
                    options={
                        {label='1'..common.CH_MONEY, value={index=1, value=1}},
                        {label='20'..common.CH_MONEY, value={index=2, value=20}},
                        {label='50'..common.CH_MONEY, value={index=3, value=50}},
                        {label='100'..common.CH_MONEY, value={index=4, value=100}},
                        {label='500'..common.CH_MONEY, value={index=5, value=500}},
                        {label='1000'..common.CH_MONEY, value={index=6, value=1000}},
                        -- max "min" value is less than max "max" value since the range of inf - inf is not useful
                        {label='5000'..common.CH_MONEY, value={index=7, value=5000}},
                    },
                    initial_option=1,
                    on_change=function(val)
                        if self.subviews.max_value:getOptionValue().value < val.value then
                            self.subviews.max_value:setOption(val.index)
                        end
                        self:refresh_list()
                    end,
                },
                widgets.CycleHotkeyLabel{
                    view_id='max_value',
                    frame={r=1, t=0, w=18},
                    label='Max value:',
                    label_below=true,
                    key_back='CUSTOM_SHIFT_T',
                    key='CUSTOM_SHIFT_Y',
                    options={
                        {label='1'..common.CH_MONEY, value={index=1, value=1}},
                        {label='20'..common.CH_MONEY, value={index=2, value=20}},
                        {label='50'..common.CH_MONEY, value={index=3, value=50}},
                        {label='100'..common.CH_MONEY, value={index=4, value=100}},
                        {label='500'..common.CH_MONEY, value={index=5, value=500}},
                        {label='1000'..common.CH_MONEY, value={index=6, value=1000}},
                        {label='Max', value={index=7, value=math.huge}},
                    },
                    initial_option=7,
                    on_change=function(val)
                        if self.subviews.min_value:getOptionValue().value > val.value then
                            self.subviews.min_value:setOption(val.index)
                        end
                        self:refresh_list()
                    end,
                },
                widgets.RangeSlider{
                    frame={l=0, t=3},
                    num_stops=7,
                    get_left_idx_fn=function()
                        return self.subviews.min_value:getOptionValue().index
                    end,
                    get_right_idx_fn=function()
                        return self.subviews.max_value:getOptionValue().index
                    end,
                    on_left_change=function(idx) self.subviews.min_value:setOption(idx, true) end,
                    on_right_change=function(idx) self.subviews.max_value:setOption(idx, true) end,
                },
            },
        },
        widgets.Panel{
            frame={t=17, l=0, r=0, b=6},
            subviews={
                widgets.CycleHotkeyLabel{
                    view_id='sort_status',
                    frame={l=0, t=0, w=7},
                    options={
                        {label='status', value=sort_noop},
                        {label='status'..common.CH_DN, value=sort_by_status_desc},
                        {label='status'..common.CH_UP, value=sort_by_status_asc},
                    },
                    initial_option=sort_by_status_desc,
                    option_gap=0,
                    on_change=self:callback('refresh_list', 'sort_status'),
                },
                widgets.CycleHotkeyLabel{
                    view_id='sort_value',
                    frame={l=STATUS_COL_WIDTH+2, t=0, w=6},
                    options={
                        {label='value', value=sort_noop},
                        {label='value'..common.CH_DN, value=sort_by_value_desc},
                        {label='value'..common.CH_UP, value=sort_by_value_asc},
                    },
                    option_gap=0,
                    on_change=self:callback('refresh_list', 'sort_value'),
                },
                widgets.CycleHotkeyLabel{
                    view_id='sort_quantity',
                    frame={l=STATUS_COL_WIDTH+2+VALUE_COL_WIDTH+2, t=0, w=4},
                    options={
                        {label='qty', value=sort_noop},
                        {label='qty'..common.CH_DN, value=sort_by_quantity_desc},
                        {label='qty'..common.CH_UP, value=sort_by_quantity_asc},
                    },
                    option_gap=0,
                    on_change=self:callback('refresh_list', 'sort_quantity'),
                },
                widgets.CycleHotkeyLabel{
                    view_id='sort_name',
                    frame={l=STATUS_COL_WIDTH+2+VALUE_COL_WIDTH+2+QTY_COL_WIDTH+2, t=0, w=5},
                    options={
                        {label='name', value=sort_noop},
                        {label='name'..common.CH_DN, value=sort_by_name_desc},
                        {label='name'..common.CH_UP, value=sort_by_name_asc},
                    },
                    option_gap=0,
                    on_change=self:callback('refresh_list', 'sort_name'),
                },
                widgets.FilteredList{
                    view_id='list',
                    frame={l=0, t=2, r=0, b=0},
                    icon_width=2,
                    on_submit=self:callback('toggle_item'),
                    on_submit2=self:callback('toggle_range'),
                    on_select=self:callback('select_item'),
                },
            }
        },
        widgets.Label{
            frame={l=0, b=4, h=1, r=0},
            text={
                'Total value of trade items:',
                {gap=1,
                 text=function() return common.obfuscate_value(self.value_pending) end},
            },
        },
        widgets.HotkeyLabel{
            frame={l=0, b=2},
            label='Select all/none',
            key='CUSTOM_CTRL_A',
            on_activate=self:callback('toggle_visible'),
            auto_width=true,
        },
        widgets.ToggleHotkeyLabel{
            view_id='disable_buckets',
            frame={l=26, b=2},
            label='Show individual items:',
            key='CUSTOM_CTRL_I',
            options={
                {label='Yes', value=true, pen=COLOR_GREEN},
                {label='No', value=false}
            },
            initial_option=false,
            on_change=function() self:refresh_list() end,
        },
        widgets.WrappedLabel{
            frame={b=0, l=0, r=0},
            text_to_wrap='Click to mark/unmark for trade. Shift click to mark/unmark a range of items.',
        },
    }

    -- replace the FilteredList's built-in EditField with our own
    self.subviews.list.list.frame.t = 0
    self.subviews.list.edit.visible = false
    self.subviews.list.edit = self.subviews.search
    self.subviews.search.on_change = self.subviews.list:callback('onFilterChange')

    self.subviews.list:setChoices(self:get_choices())
end

function MoveGoods:refresh_list(sort_widget, sort_fn)
    sort_widget = sort_widget or 'sort'
    sort_fn = sort_fn or self.subviews.sort:getOptionValue()
    if sort_fn == sort_noop then
        self.subviews[sort_widget]:cycle()
        return
    end
    for _,widget_name in ipairs{'sort', 'sort_status', 'sort_value', 'sort_quantity', 'sort_name'} do
        self.subviews[widget_name]:setOption(sort_fn)
    end
    local list = self.subviews.list
    local saved_filter = list:getFilter()
    list:setFilter('')
    list:setChoices(self:get_choices(), list:getSelected())
    list:setFilter(saved_filter)
end

local function is_tradeable_item(item, depot)
    if item.flags.hostile or
        item.flags.in_inventory or
        item.flags.removed or
        item.flags.dead_dwarf or
        item.flags.spider_web or
        item.flags.construction or
        item.flags.encased or
        item.flags.unk12 or
        item.flags.murder or
        item.flags.trader or
        item.flags.owned or
        item.flags.garbage_collect or
        item.flags.on_fire or
        item.flags.in_chest
    then
        return false
    end
    if item.flags.in_job then
        local spec_ref = dfhack.items.getSpecificRef(item, df.specific_ref_type.JOB)
        if not spec_ref then return true end
        return spec_ref.data.job.job_type == df.job_type.BringItemToDepot
    end
    if item.flags.in_building then
        if dfhack.items.getHolderBuilding(item) ~= depot then return false end
        for _, contained_item in ipairs(depot.contained_items) do
            if contained_item.use_mode == 0 then return true end
            -- building construction materials
            if item == contained_item.item then return false end
        end
    end
    return dfhack.maps.canWalkBetween(xyz2pos(dfhack.items.getPosition(item)),
        xyz2pos(depot.centerx, depot.centery, depot.z))
end

local function get_entry_icon(data, item_id)
    if data.selected == 0 then return nil end
    if item_id then
        return data.items[item_id].pending and common.ALL_PEN or nil
    end
    if data.quantity == data.selected then return common.ALL_PEN end
    return common.SOME_PEN
end

local function make_choice_text(desc, value, quantity)
    return {
        {width=STATUS_COL_WIDTH+VALUE_COL_WIDTH-3, rjustify=true, text=common.obfuscate_value(value)},
        {gap=3, width=QTY_COL_WIDTH, rjustify=true, text=quantity},
        {gap=4, text=desc},
    }
end

local function match_risky(item, risky_items)
    for item_type, subtypes in pairs(risky_items) do
        for subtype in pairs(subtypes) do
            if item_type == item:getType() and (subtype == -1 or subtype == item:getSubtype()) then
                return true
            end
        end
    end
    return false
end

-- returns is_banned, is_risky
local function scan_banned(item, risky_items)
    if not dfhack.items.checkMandates(item) then return true, true end
    if match_risky(item, risky_items) then return false, true end
    for _,contained_item in ipairs(dfhack.items.getContainedItems(item)) do
        if not dfhack.items.checkMandates(contained_item) then return true, true end
        if match_risky(contained_item, risky_items) then return false, true end
    end
    return false, false
end

local function is_wood_based(mat_type, mat_index)
    if mat_type == df.builtin_mats.LYE or
        mat_type == df.builtin_mats.GLASS_CLEAR or
        mat_type == df.builtin_mats.GLASS_CRYSTAL or
        (mat_type == df.builtin_mats.COAL and mat_index == 1) or
        mat_type == df.builtin_mats.POTASH or
        mat_type == df.builtin_mats.ASH or
        mat_type == df.builtin_mats.PEARLASH
    then
        return true
    end

    local mi = dfhack.matinfo.decode(mat_type, mat_index)
    return mi and mi.material and
        (mi.material.flags.WOOD or
         mi.material.flags.STRUCTURAL_PLANT_MAT or
         mi.material.flags.SOAP)
end

local function has_wood(item)
    if item.flags2.grown then return false end

    if is_wood_based(item:getMaterial(), item:getMaterialIndex()) then
        return true
    end

    if item:hasImprovements() then
        for _, imp in ipairs(item.improvements) do
            if is_wood_based(imp.mat_type, imp.mat_index) then
                return true
            end
        end
    end

    return false
end

local function is_ethical_product(item, fn)
    if item.flags.container then
        local contained_items = dfhack.items.getContainedItems(item)
        if df.item_binst:is_instance(item) then
            -- ignore the safety of the bin itself (unless the bin is empty)
            -- so items inside can still be traded
            local has_items = false
            for _, contained_item in ipairs(contained_items) do
                has_items = true
                if not contained_item:isAnimalProduct() and not has_wood(contained_item) then
                    return true
                end
            end
            if has_items then
                -- no contained items are safe
                return false
            end
        else
            -- for other types of containers, any contamination makes it untradeable
            for _, contained_item in ipairs(contained_items) do
                if contained_item:isAnimalProduct() or has_wood(contained_item) then
                    return false
                end
            end
        end
    end

    return not item:isAnimalProduct() and not has_wood(item)
end

local function is_ethical_animal_product(item)
    return is_ethical_product(item, function(it) return it:isAnimalProduct() end)
end

local function is_ethical_wood_product(item)
    return is_ethical_product(item, function(it) return has_wood(it) end)
end

function MoveGoods:cache_choices(disable_buckets)
    if self.choices then return self.choices[disable_buckets] end

    local animal_ethics, wood_ethics = get_ethics_restrictions()

    local depot = dfhack.gui.getSelectedBuilding(true)
    local pending = self.pending_item_ids
    local buckets = {}
    for _, item in ipairs(df.global.world.items.all) do
        local item_id = item.id
        if not item or not is_tradeable_item(item, depot) then goto continue end
        local value = common.get_perceived_value(item)
        if value <= 0 then goto continue end
        local is_pending = not not pending[item_id] or item.flags.in_building
        local is_forbidden = item.flags.forbid
        local is_banned, is_risky = scan_banned(item, self.risky_items)
        local is_requested = dfhack.items.isRequestedTradeGood(item)
        local wear_level = item:getWear()
        local desc = item.flags.artifact and common.get_artifact_name(item) or
            dfhack.items.getDescription(item, 0, true)
        if wear_level == 1 then desc = ('x%sx'):format(desc)
        elseif wear_level == 2 then desc = ('X%sX'):format(desc)
        elseif wear_level == 3 then desc = ('XX%sXX'):format(desc)
        end
        local key = ('%s/%d'):format(desc, value)
        if buckets[key] then
            local bucket = buckets[key]
            bucket.data.items[item_id] = {item=item, pending=is_pending, banned=is_banned, requested=is_requested}
            bucket.data.quantity = bucket.data.quantity + 1
            bucket.data.selected = bucket.data.selected + (is_pending and 1 or 0)
            bucket.data.has_forbidden = bucket.data.has_forbidden or is_forbidden
            bucket.data.has_banned = bucket.data.has_banned or is_banned
            bucket.data.has_risky = bucket.data.has_risky or is_risky
            bucket.data.has_requested = bucket.data.has_requested or is_requested
        else
            local is_ethical = (not animal_ethics or is_ethical_animal_product(item)) and
                (not wood_ethics or is_ethical_wood_product(item))
            local data = {
                desc=desc,
                per_item_value=value,
                items={[item_id]={item=item, pending=is_pending, banned=is_banned, risky=is_risky, requested=is_requested}},
                item_type=item:getType(),
                item_subtype=item:getSubtype(),
                quantity=1,
                quality=item.flags.artifact and 6 or item:getQuality(),
                wear=wear_level,
                selected=is_pending and 1 or 0,
                has_forbidden=is_forbidden,
                has_banned=is_banned,
                has_risky=is_risky,
                has_requested=is_requested,
                ethical=is_ethical,
                dirty=false,
            }
            local entry = {
                search_key=common.make_search_key(desc),
                icon=curry(get_entry_icon, data),
                data=data,
            }
            buckets[key] = entry
        end
        ::continue::
    end

    local bucket_choices, nobucket_choices = {}, {}
    for _, bucket in pairs(buckets) do
        local data = bucket.data
        for item_id in pairs(data.items) do
            local nobucket_choice = copyall(bucket)
            nobucket_choice.icon = curry(get_entry_icon, data, item_id)
            nobucket_choice.text = make_choice_text(data.desc, data.per_item_value, 1)
            nobucket_choice.item_id = item_id
            table.insert(nobucket_choices, nobucket_choice)
        end
        data.total_value = data.per_item_value * data.quantity
        bucket.text = make_choice_text(data.desc, data.total_value, data.quantity)
        table.insert(bucket_choices, bucket)
        self.value_pending = self.value_pending + (data.per_item_value * data.selected)
    end

    self.choices = {}
    self.choices[false] = bucket_choices
    self.choices[true] = nobucket_choices
    return self:cache_choices(disable_buckets)
end

function MoveGoods:get_choices()
    local raw_choices = self:cache_choices(self.subviews.disable_buckets:getOptionValue())
    local choices = {}
    local include_forbidden = not self.subviews.hide_forbidden:getOptionValue()
    local banned = self.subviews.banned:getOptionValue()
    local only_agreement = self.subviews.only_agreement:getOptionValue()
    local ethical = self.subviews.ethical:getOptionValue()
    local min_condition = self.subviews.min_condition:getOptionValue()
    local max_condition = self.subviews.max_condition:getOptionValue()
    local min_quality = self.subviews.min_quality:getOptionValue()
    local max_quality = self.subviews.max_quality:getOptionValue()
    local min_value = self.subviews.min_value:getOptionValue().value
    local max_value = self.subviews.max_value:getOptionValue().value
    for _,choice in ipairs(raw_choices) do
        local data = choice.data
        if ethical ~= 'show' then
            if ethical == 'hide' and data.ethical then goto continue end
            if ethical == 'only' and not data.ethical then goto continue end
        end
        if not include_forbidden then
            if choice.item_id then
                if data.items[choice.item_id].item.flags.forbid then
                    goto continue
                end
            elseif data.has_forbidden then
                goto continue
            end
        end
        if min_condition < data.wear then goto continue end
        if max_condition > data.wear then goto continue end
        if min_quality > data.quality then goto continue end
        if max_quality < data.quality then goto continue end
        if min_value > data.per_item_value then goto continue end
        if max_value < data.per_item_value then goto continue end
        if only_agreement then
            if choice.item_id then
                if not data.items[choice.item_id].requested then
                    goto continue
                end
            elseif not data.has_requested then
                goto continue
            end
        end
        if banned ~= 'ignore' then
            if choice.item_id then
                if data.items[choice.item_id].banned or (banned ~= 'banned_only' and data.items[choice.item_id].risky) then
                    goto continue
                end
            elseif data.has_banned or (banned ~= 'banned_only' and data.has_risky) then
                goto continue
            end
        end
        table.insert(choices, choice)
        ::continue::
    end
    table.sort(choices, self.subviews.sort:getOptionValue())
    return choices
end

function MoveGoods:toggle_item_base(choice, target_value)
    if choice.item_id then
        local item_data = choice.data.items[choice.item_id]
        if item_data.pending then
            self.value_pending = self.value_pending - choice.data.per_item_value
            choice.data.selected = choice.data.selected - 1
        end
        if target_value == nil then target_value = not item_data.pending end
        item_data.pending = target_value
        if item_data.pending then
            self.value_pending = self.value_pending + choice.data.per_item_value
            choice.data.selected = choice.data.selected + 1
        end
    else
        self.value_pending = self.value_pending - (choice.data.selected * choice.data.per_item_value)
        if target_value == nil then target_value = (choice.data.selected ~= choice.data.quantity) end
        for _, item_data in pairs(choice.data.items) do
            item_data.pending = target_value
        end
        choice.data.selected = target_value and choice.data.quantity or 0
        self.value_pending = self.value_pending + (choice.data.selected * choice.data.per_item_value)
    end
    choice.data.dirty = true
    return target_value
end

function MoveGoods:select_item(idx, choice)
    if not dfhack.internal.getModifiers().shift then
        self.prev_list_idx = self.subviews.list.list:getSelected()
    end
end

function MoveGoods:toggle_item(idx, choice)
    self:toggle_item_base(choice)
end

function MoveGoods:toggle_range(idx, choice)
    if not self.prev_list_idx then
        self:toggle_item(idx, choice)
        return
    end
    local choices = self.subviews.list:getVisibleChoices()
    local list_idx = self.subviews.list.list:getSelected()
    local target_value
    for i = list_idx, self.prev_list_idx, list_idx < self.prev_list_idx and 1 or -1 do
        target_value = self:toggle_item_base(choices[i], target_value)
    end
    self.prev_list_idx = list_idx
end

function MoveGoods:toggle_visible()
    local target_value
    for _, choice in ipairs(self.subviews.list:getVisibleChoices()) do
        target_value = self:toggle_item_base(choice, target_value)
    end
end

-- -------------------
-- MoveGoodsModal
--

MoveGoodsModal = defclass(MoveGoodsModal, gui.ZScreenModal)
MoveGoodsModal.ATTRS {
    focus_path='caravan/movegoods',
}

local function get_pending_trade_item_ids()
    local item_ids = {}
    for _,job in utils.listpairs(df.global.world.jobs.list) do
        if job.job_type == df.job_type.BringItemToDepot and #job.items > 0 then
            item_ids[job.items[0].item.id] = true
        end
    end
    return item_ids
end

function MoveGoodsModal:init()
    self.pending_item_ids = get_pending_trade_item_ids()
    self:addviews{MoveGoods{pending_item_ids=self.pending_item_ids}}
end

function MoveGoodsModal:onDismiss()
    -- mark/unmark selected goods for trade
    local depot = dfhack.gui.getSelectedBuilding(true)
    if not depot then return end
    local pending = self.pending_item_ids
    for _, choice in ipairs(self.subviews.list:getChoices()) do
        if not choice.data.dirty then goto continue end
        for item_id, item_data in pairs(choice.data.items) do
            local item = item_data.item
            if item_data.pending and not pending[item_id] then
                item.flags.forbid = false
                if dfhack.items.getHolderBuilding(item) then
                    item.flags.in_building = true
                else
                    dfhack.items.markForTrade(item, depot)
                end
            elseif not item_data.pending and pending[item_id] then
                local spec_ref = dfhack.items.getSpecificRef(item, df.specific_ref_type.JOB)
                if spec_ref then
                    dfhack.job.removeJob(spec_ref.data.job)
                end
            elseif not item_data.pending and item.flags.in_building then
                item.flags.in_building = false
            end
        end
        ::continue::
    end
end

-- -------------------
-- MoveGoodsOverlay
--

MoveGoodsOverlay = defclass(MoveGoodsOverlay, overlay.OverlayWidget)
MoveGoodsOverlay.ATTRS{
    default_pos={x=-64, y=10},
    default_enabled=true,
    viewscreens='dwarfmode/ViewSheets/BUILDING/TradeDepot',
    frame={w=31, h=1},
    frame_background=gui.CLEAR_PEN,
}

local function has_trade_depot_and_caravan()
    local bld = dfhack.gui.getSelectedBuilding(true)
    if not bld or bld:getBuildStage() < bld:getMaxBuildStage() then
        return false
    end
    if #bld.jobs == 1 and bld.jobs[0].job_type == df.job_type.DestroyBuilding then
        return false
    end

    for _, caravan in ipairs(df.global.plotinfo.caravans) do
        local trade_state = caravan.trade_state
        local time_remaining = caravan.time_remaining
        if time_remaining > 0 and
            (trade_state == df.caravan_state.T_trade_state.Approaching or
             trade_state == df.caravan_state.T_trade_state.AtDepot)
        then
            return true
        end
    end
    return false
end

function MoveGoodsOverlay:init()
    self:addviews{
        widgets.HotkeyLabel{
            frame={t=0, l=0},
            label='DFHack move trade goods',
            key='CUSTOM_CTRL_T',
            on_activate=function() MoveGoodsModal{}:show() end,
            enabled=has_trade_depot_and_caravan,
        },
    }
end
