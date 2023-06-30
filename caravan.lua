-- Adjusts properties of caravans and provides overlay for enhanced trading
--@ module = true

-- TODO: the category checkbox that indicates whether all items in the category
-- are selected can be incorrect after the overlay adjusts the container
-- selection. the state is in trade.current_type_a_flag, but figuring out which
-- index to modify is non-trivial.

local gui = require('gui')
local overlay = require('plugins.overlay')
local utils = require('utils')
local widgets = require('gui.widgets')

trader_selected_state = trader_selected_state or {}
broker_selected_state = broker_selected_state or {}
handle_ctrl_click_on_render = handle_ctrl_click_on_render or false
handle_shift_click_on_render = handle_shift_click_on_render or false

dfhack.onStateChange.caravanTradeOverlay = function(code)
    if code == SC_WORLD_UNLOADED then
        trader_selected_state = {}
        broker_selected_state = {}
        handle_ctrl_click_on_render = false
        handle_shift_click_on_render = false
    end
end

local GOODFLAG = {
    UNCONTAINED_UNSELECTED = 0,
    UNCONTAINED_SELECTED = 1,
    CONTAINED_UNSELECTED = 2,
    CONTAINED_SELECTED = 3,
    CONTAINER_COLLAPSED_UNSELECTED = 4,
    CONTAINER_COLLAPSED_SELECTED = 5,
}

local trade = df.global.game.main_interface.trade

local MARGIN_HEIGHT = 26 -- screen height *other* than the list

function set_height(list_index, delta)
    trade.i_height[list_index] = trade.i_height[list_index] + delta
    if delta >= 0 then return end
    _,screen_height = dfhack.screen.getWindowSize()
    -- list only increments in three tiles at a time
    local page_height = ((screen_height - MARGIN_HEIGHT) // 3) * 3
    trade.scroll_position_item[list_index] = math.max(0,
            math.min(trade.scroll_position_item[list_index],
                     trade.i_height[list_index] - page_height))
end

function select_shift_clicked_container_items(new_state, old_state, list_index)
    -- if ctrl is also held, collapse the container too
    local also_collapse = dfhack.internal.getModifiers().ctrl
    local collapsed_item_count, collapsing_container, in_container = 0, false, false
    for k, goodflag in ipairs(new_state) do
        if in_container then
            if goodflag <= GOODFLAG.UNCONTAINED_SELECTED
                    or goodflag >= GOODFLAG.CONTAINER_COLLAPSED_UNSELECTED then
                break
            end

            new_state[k] = GOODFLAG.CONTAINED_SELECTED

            if collapsing_container then
                collapsed_item_count = collapsed_item_count + 1
            end
            goto continue
        end

        if goodflag == old_state[k] then goto continue end
        local is_container = df.item_binst:is_instance(trade.good[list_index][k])
        if not is_container then goto continue end

        -- deselect the container itself
        if also_collapse or
                old_state[k] == GOODFLAG.CONTAINER_COLLAPSED_UNSELECTED or
                old_state[k] == GOODFLAG.CONTAINER_COLLAPSED_SELECTED then
            collapsing_container = goodflag == GOODFLAG.UNCONTAINED_SELECTED
            new_state[k] = GOODFLAG.CONTAINER_COLLAPSED_UNSELECTED
        else
            new_state[k] = GOODFLAG.UNCONTAINED_UNSELECTED
        end
        in_container = true

        ::continue::
    end

    if collapsed_item_count > 0 then
        set_height(list_index, collapsed_item_count * -3)
    end
end

local CTRL_CLICK_STATE_MAP = {
    [GOODFLAG.UNCONTAINED_UNSELECTED] = GOODFLAG.CONTAINER_COLLAPSED_UNSELECTED,
    [GOODFLAG.UNCONTAINED_SELECTED] = GOODFLAG.CONTAINER_COLLAPSED_SELECTED,
    [GOODFLAG.CONTAINER_COLLAPSED_UNSELECTED] = GOODFLAG.UNCONTAINED_UNSELECTED,
    [GOODFLAG.CONTAINER_COLLAPSED_SELECTED] = GOODFLAG.UNCONTAINED_SELECTED,
}

-- collapses uncollapsed containers and restores the selection state for the container
-- and contained items
function toggle_ctrl_clicked_containers(new_state, old_state, list_index)
    local toggled_item_count, in_container, is_collapsing = 0, false, false
    for k, goodflag in ipairs(new_state) do
        if in_container then
            if goodflag <= GOODFLAG.UNCONTAINED_SELECTED
                    or goodflag >= GOODFLAG.CONTAINER_COLLAPSED_UNSELECTED then
                break
            end
            toggled_item_count = toggled_item_count + 1
            new_state[k] = old_state[k]
            goto continue
        end

        if goodflag == old_state[k] then goto continue end
        local is_contained = goodflag == GOODFLAG.CONTAINED_UNSELECTED or goodflag == GOODFLAG.CONTAINED_SELECTED
        if is_contained then goto continue end
        local is_container = df.item_binst:is_instance(trade.good[list_index][k])
        if not is_container then goto continue end

        new_state[k] = CTRL_CLICK_STATE_MAP[old_state[k]]
        in_container = true
        is_collapsing = goodflag == GOODFLAG.UNCONTAINED_UNSELECTED or goodflag == GOODFLAG.UNCONTAINED_SELECTED

        ::continue::
    end

    if toggled_item_count > 0 then
        set_height(list_index, toggled_item_count * 3 * (is_collapsing and -1 or 1))
    end
end

function collapseTypes(types_list, list_index)
    local type_on_count = 0

    for k in ipairs(types_list) do
        local type_on = trade.current_type_a_on[list_index][k]
        if type_on then
            type_on_count = type_on_count + 1
        end
        types_list[k] = false
    end

    trade.i_height[list_index] = type_on_count * 3
    trade.scroll_position_item[list_index] = 0
end

function collapseAllTypes()
   collapseTypes(trade.current_type_a_expanded[0], 0)
   collapseTypes(trade.current_type_a_expanded[1], 1)
end

function collapseContainers(item_list, list_index)
    local num_items_collapsed = 0
    for k, goodflag in ipairs(item_list) do
        if goodflag == GOODFLAG.CONTAINED_UNSELECTED
                or goodflag == GOODFLAG.CONTAINED_SELECTED then
            goto continue
        end

        local item = trade.good[list_index][k]
        local is_container = df.item_binst:is_instance(item)
        if not is_container then goto continue end

        local collapsed_this_container = false
        if goodflag == GOODFLAG.UNCONTAINED_SELECTED then
            item_list[k] = GOODFLAG.CONTAINER_COLLAPSED_SELECTED
            collapsed_this_container = true
        elseif goodflag == GOODFLAG.UNCONTAINED_UNSELECTED then
            item_list[k] = GOODFLAG.CONTAINER_COLLAPSED_UNSELECTED
            collapsed_this_container = true
        end

        if collapsed_this_container then
            num_items_collapsed = num_items_collapsed + #dfhack.items.getContainedItems(item)
        end
        ::continue::
    end

    if num_items_collapsed > 0 then
        set_height(list_index, num_items_collapsed * -3)
    end
end

function collapseAllContainers()
    collapseContainers(trade.goodflag[0], 0)
    collapseContainers(trade.goodflag[1], 1)
end

function collapseEverything()
    collapseAllContainers()
    collapseAllTypes()
end

function copyGoodflagState()
    trader_selected_state = copyall(trade.goodflag[0])
    broker_selected_state = copyall(trade.goodflag[1])
end

CaravanTradeOverlay = defclass(CaravanTradeOverlay, overlay.OverlayWidget)
CaravanTradeOverlay.ATTRS{
    default_pos={x=-3,y=-12},
    default_enabled=true,
    viewscreens='dwarfmode/Trade',
    frame={w=27, h=13},
    frame_style=gui.MEDIUM_FRAME,
    frame_background=gui.CLEAR_PEN,
}

function CaravanTradeOverlay:init()
    self:addviews{
        widgets.Label{
            frame={t=0, l=0},
            text={
                {text='Shift+Click checkbox', pen=COLOR_LIGHTGREEN}, ':',
                NEWLINE,
                '  select items inside bin',
            },
        },
        widgets.Label{
            frame={t=3, l=0},
            text={
                {text='Ctrl+Click checkbox', pen=COLOR_LIGHTGREEN}, ':',
                NEWLINE,
                '  collapse/expand bin',
            },
        },
        widgets.HotkeyLabel{
            frame={t=6, l=0},
            label='collapse bins',
            key='CUSTOM_CTRL_C',
            on_activate=collapseAllContainers,
        },
        widgets.HotkeyLabel{
            frame={t=7, l=0},
            label='collapse all',
            key='CUSTOM_CTRL_X',
            on_activate=collapseEverything,
        },
        widgets.Label{
            frame={t=9, l=0},
            text = 'Shift+Scroll',
            text_pen=COLOR_LIGHTGREEN,
        },
        widgets.Label{
            frame={t=9, l=12},
            text = ': fast scroll',
        },
    }
end

-- do our alterations *after* the vanilla response to the click has registered. otherwise
-- it's very difficult to figure out which item has been clicked
function CaravanTradeOverlay:onRenderBody(dc)
    if handle_shift_click_on_render then
        handle_shift_click_on_render = false
        select_shift_clicked_container_items(trade.goodflag[0], trader_selected_state, 0)
        select_shift_clicked_container_items(trade.goodflag[1], broker_selected_state, 1)
    elseif handle_ctrl_click_on_render then
        handle_ctrl_click_on_render = false
        toggle_ctrl_clicked_containers(trade.goodflag[0], trader_selected_state, 0)
        toggle_ctrl_clicked_containers(trade.goodflag[1], broker_selected_state, 1)
    end
end

function CaravanTradeOverlay:onInput(keys)
    if CaravanTradeOverlay.super.onInput(self, keys) then return true end

    if keys._MOUSE_L_DOWN then
        if dfhack.internal.getModifiers().shift then
            handle_shift_click_on_render = true
            copyGoodflagState()
        elseif dfhack.internal.getModifiers().ctrl then
            handle_ctrl_click_on_render = true
            copyGoodflagState()
        end
    end
end

-- -------------------
-- DiplomacyOverlay
--

DiplomacyOverlay = defclass(DiplomacyOverlay, overlay.OverlayWidget)
DiplomacyOverlay.ATTRS{
    default_pos={x=45, y=-6},
    default_enabled=true,
    viewscreens='dwarfmode/Diplomacy/Requests',
    frame={w=25, h=3},
    frame_style=gui.MEDIUM_FRAME,
    frame_background=gui.CLEAR_PEN,
}

local diplomacy = df.global.game.main_interface.diplomacy
local function diplomacy_toggle_cat()
    local priority_idx = diplomacy.taking_requests_tablist[diplomacy.taking_requests_selected_tab]
    local priority = diplomacy.environment.meeting.sell_requests.priority[priority_idx]
    if #priority == 0 then return end
    local target_val = priority[0] == 0 and 4 or 0
    for i in ipairs(priority) do
        priority[i] = target_val
    end
end

function DiplomacyOverlay:init()
    self:addviews{
        widgets.HotkeyLabel{
            frame={t=0, l=0},
            label='Select all/none',
            key='CUSTOM_CTRL_A',
            on_activate=diplomacy_toggle_cat,
        },
    }
end

-- -------------------
-- MoveGoods
--

MoveGoods = defclass(MoveGoods, widgets.Window)
MoveGoods.ATTRS {
    frame_title='Select trade goods',
    frame={w=83, h=45},
    resizable=true,
    resize_min={h=27},
    pending_item_ids=DEFAULT_NIL,
}

local VALUE_COL_WIDTH = 8
local QTY_COL_WIDTH = 6

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

local function sort_by_quantity_desc(a, b)
    if a.data.quantity == b.data.quantity then
        return sort_by_name_desc(a, b)
    end
    return a.data.quantity > b.data.quantity
end

local function sort_by_quantity_asc(a, b)
    if a.data.quantity == b.data.quantity then
        return sort_by_name_desc(a, b)
    end
    return a.data.quantity < b.data.quantity
end

local function has_export_agreement()
    -- TODO: where are export agreements stored?
    return false
end

local function is_agreement_item(item_type)
    -- TODO: match export agreement with civs with active caravans
    return false
end

-- takes into account trade agreements
local function get_perceived_value(item)
    -- TODO: take trade agreements into account
    local value = dfhack.items.getValue(item)
    for _,contained_item in ipairs(dfhack.items.getContainedItems(item)) do
        value = value + dfhack.items.getValue(contained_item)
        for _,contained_contained_item in ipairs(dfhack.items.getContainedItems(contained_item)) do
            value = value + dfhack.items.getValue(contained_contained_item)
        end
    end
    return value
end

local function get_value_at_depot()
    local sum = 0
    -- if we're here, then the overlay has already determined that this is a depot
    local depot = dfhack.gui.getSelectedBuilding(true)
    for _, contained_item in ipairs(depot.contained_items) do
        if contained_item.use_mode ~= 0 then goto continue end
        local item = contained_item.item
        sum = sum + get_perceived_value(item)
        ::continue::
    end
    return sum
end

-- adapted from https://stackoverflow.com/a/50860705
local function sig_fig(num, figures)
    if num <= 0 then return 0 end
    local x = figures - math.ceil(math.log(num, 10))
    return math.floor(math.floor(num * 10^x + 0.5) * 10^-x)
end

local function obfuscate_value(value)
    -- TODO: respect skill of broker
    local num_sig_figs = 1
    local str = tostring(sig_fig(value, num_sig_figs))
    if #str > num_sig_figs then str = '~' .. str end
    return str
end

local CH_UP = string.char(30)
local CH_DN = string.char(31)

function MoveGoods:init()
    self.value_at_depot = get_value_at_depot()
    self.value_pending = 0

    self:addviews{
        widgets.CycleHotkeyLabel{
            view_id='sort',
            frame={l=0, t=0, w=21},
            label='Sort by:',
            key='CUSTOM_SHIFT_S',
            options={
                {label='value'..CH_DN, value=sort_by_value_desc},
                {label='value'..CH_UP, value=sort_by_value_asc},
                {label='qty'..CH_DN, value=sort_by_quantity_desc},
                {label='qty'..CH_UP, value=sort_by_quantity_asc},
                {label='name'..CH_DN, value=sort_by_name_desc},
                {label='name'..CH_UP, value=sort_by_name_asc},
            },
            initial_option=sort_by_value_desc,
            on_change=self:callback('refresh_list', 'sort'),
        },
        widgets.EditField{
            view_id='search',
            frame={l=26, t=0},
            label_text='Search: ',
            on_char=function(ch) return ch:match('[%l -]') end,
        },
        widgets.ToggleHotkeyLabel{
            view_id='show_forbidden',
            frame={t=2, l=0, w=27},
            label='Show forbidden items',
            key='CUSTOM_SHIFT_F',
            initial_option=true,
            on_change=function() self:refresh_list() end,
        },
        widgets.ToggleHotkeyLabel{
            view_id='show_banned',
            frame={t=3, l=0, w=43},
            label='Show items banned by export mandates',
            key='CUSTOM_SHIFT_B',
            initial_option=false,
            on_change=function() self:refresh_list() end,
        },
        widgets.ToggleHotkeyLabel{
            view_id='only_agreement',
            frame={t=4, l=0, w=52},
            label='Show only items requested by export agreement',
            key='CUSTOM_SHIFT_A',
            initial_option=false,
            on_change=function() self:refresh_list() end,
            enabled=has_export_agreement(),
        },
        widgets.Panel{
            frame={t=6, l=0, w=40, h=4},
            subviews={
                widgets.CycleHotkeyLabel{
                    view_id='min_condition',
                    frame={l=0, t=0, w=18},
                    label='Min condition:',
                    label_below=true,
                    key_back='CUSTOM_SHIFT_C',
                    key='CUSTOM_SHIFT_V',
                    options={
                        {label='Tattered (XX)', value=3},
                        {label='Frayed (X)', value=2},
                        {label='Worn (x)', value=1},
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
                        {label='Tattered (XX)', value=3},
                        {label='Frayed (X)', value=2},
                        {label='Worn (x)', value=1},
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
            frame={t=6, l=41, w=38, h=4},
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
                        {label='Well Crafted', value=1},
                        {label='Finely Crafted', value=2},
                        {label='Superior', value=3},
                        {label='Exceptional', value=4},
                        {label='Masterful', value=5},
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
                        {label='Well Crafted', value=1},
                        {label='Finely Crafted', value=2},
                        {label='Superior', value=3},
                        {label='Exceptional', value=4},
                        {label='Masterful', value=5},
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
            frame={t=11, l=0, r=0, b=6},
            subviews={
                widgets.CycleHotkeyLabel{
                    view_id='sort_value',
                    frame={l=2, t=0, w=7},
                    options={
                        {label='value', value=sort_noop},
                        {label='value'..CH_DN, value=sort_by_value_desc},
                        {label='value'..CH_UP, value=sort_by_value_asc},
                    },
                    initial_option=sort_by_value_desc,
                    on_change=self:callback('refresh_list', 'sort_value'),
                },
                widgets.CycleHotkeyLabel{
                    view_id='sort_quantity',
                    frame={l=2+VALUE_COL_WIDTH+2, t=0, w=5},
                    options={
                        {label='qty', value=sort_noop},
                        {label='qty'..CH_DN, value=sort_by_quantity_desc},
                        {label='qty'..CH_UP, value=sort_by_quantity_asc},
                    },
                    on_change=self:callback('refresh_list', 'sort_quantity'),
                },
                widgets.CycleHotkeyLabel{
                    view_id='sort_name',
                    frame={l=2+VALUE_COL_WIDTH+2+QTY_COL_WIDTH+2, t=0, w=6},
                    options={
                        {label='name', value=sort_noop},
                        {label='name'..CH_DN, value=sort_by_name_desc},
                        {label='name'..CH_UP, value=sort_by_name_asc},
                    },
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
                'Value of items at trade depot/being brought to depot/total:',
                {gap=1, text=obfuscate_value(self.value_at_depot)},
                '/',
                {text=function() return obfuscate_value(self.value_pending) end},
                '/',
                {text=function() return obfuscate_value(self.value_pending + self.value_at_depot) end}
            },
        },
        widgets.HotkeyLabel{
            frame={l=0, b=2},
            label='Select all/none',
            key='CUSTOM_CTRL_V',
            on_activate=self:callback('toggle_visible'),
            auto_width=true,
        },
        widgets.ToggleHotkeyLabel{
            view_id='disable_buckets',
            frame={l=26, b=2},
            label='Show individual items',
            key='CUSTOM_CTRL_I',
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
    for _,widget_name in ipairs{'sort', 'sort_value', 'sort_quantity', 'sort_name'} do
        self.subviews[widget_name]:setOption(sort_fn)
    end
    local list = self.subviews.list
    local saved_filter = list:getFilter()
    list:setFilter('')
    list:setChoices(self:get_choices(), list:getSelected())
    list:setFilter(saved_filter)
end

local function is_tradeable_item(item)
    if not item.flags.on_ground or
        item.flags.hostile or
        item.flags.in_inventory or
        item.flags.removed or
        item.flags.in_building or
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
    return true
end

local function make_search_key(str)
    local out = ''
    for c in str:gmatch("[%w%s]") do
        out = out .. c:lower()
    end
    return out
end

local to_pen = dfhack.pen.parse
local SOME_PEN = to_pen{ch=':', fg=COLOR_YELLOW}
local ALL_PEN = to_pen{ch='+', fg=COLOR_LIGHTGREEN}

local function get_entry_icon(data, item_id)
    if data.selected == 0 then return nil end
    if item_id then
        return data.items[item_id].pending and ALL_PEN or nil
    end
    if data.quantity == data.selected then return ALL_PEN end
    return SOME_PEN
end

local function make_choice_text(desc, value, quantity)
    return {
        {width=VALUE_COL_WIDTH, rjustify=true, text=obfuscate_value(value)},
        {gap=2, width=QTY_COL_WIDTH, rjustify=true, text=quantity},
        {gap=2, text=desc},
    }
end

-- returns true if the item or any contained item is banned
local function scan_banned(item)
    if not dfhack.items.checkMandates(item) then return true end
    for _,contained_item in ipairs(dfhack.items.getContainedItems(item)) do
        if not dfhack.items.checkMandates(contained_item) then return true end
    end
    return false
end

local function to_title_case(str)
    str = str:gsub('(%a)([%w_]*)',
        function (first, rest) return first:upper()..rest:lower() end)
    str = str:gsub('_', ' ')
    return str
end

local function get_item_type_str(item)
    local str = to_title_case(df.item_type[item:getType()])
    if str == 'Trapparts' then
        str = 'Mechanism'
    end
    return str
end

local function get_artifact_name(item)
    local gref = dfhack.items.getGeneralRef(item, df.general_ref_type.IS_ARTIFACT)
    if not gref then return end
    local artifact = df.artifact_record.find(gref.artifact_id)
    if not artifact then return end
    local name = dfhack.TranslateName(artifact.name)
    return ('%s (%s)'):format(name, get_item_type_str(item))
end

function MoveGoods:cache_choices(disable_buckets)
    if self.choices then return self.choices[disable_buckets] end

    local pending = self.pending_item_ids
    local buckets = {}
    for _, item in ipairs(df.global.world.items.all) do
        local item_id = item.id
        if not item or not is_tradeable_item(item) then goto continue end
        local value = get_perceived_value(item)
        if value <= 0 then goto continue end
        local is_pending = not not pending[item_id]
        local is_forbidden = item.flags.forbid
        local is_banned = scan_banned(item)
        local wear_level = item:getWear()
        local desc = item.flags.artifact and get_artifact_name(item) or
            dfhack.items.getDescription(item, 0, true)
        if wear_level == 1 then desc = ('x%sx'):format(desc)
        elseif wear_level == 2 then desc = ('X%sX'):format(desc)
        elseif wear_level == 3 then desc = ('XX%sXX'):format(desc)
        end
        local key = ('%s/%d'):format(desc, value)
        if buckets[key] then
            local bucket = buckets[key]
            bucket.data.items[item_id] = {item=item, pending=is_pending, banned=is_banned}
            bucket.data.quantity = bucket.data.quantity + 1
            bucket.data.selected = bucket.data.selected + (is_pending and 1 or 0)
            bucket.data.has_forbidden = bucket.data.has_forbidden or is_forbidden
            bucket.data.has_banned = bucket.data.has_banned or is_banned
        else
            local data = {
                desc=desc,
                per_item_value=value,
                items={[item_id]={item=item, pending=is_pending, banned=is_banned}},
                item_type=item:getType(),
                item_subtype=item:getSubtype(),
                quantity=1,
                quality=item.flags.artifact and 6 or item:getQuality(),
                wear=wear_level,
                selected=is_pending and 1 or 0,
                has_forbidden=is_forbidden,
                has_banned=is_banned,
                dirty=false,
            }
            local entry = {
                search_key=make_search_key(desc),
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
    local include_forbidden = self.subviews.show_forbidden:getOptionValue()
    local include_banned = self.subviews.show_banned:getOptionValue()
    local only_agreement = self.subviews.only_agreement:getOptionValue()
    local min_condition = self.subviews.min_condition:getOptionValue()
    local max_condition = self.subviews.max_condition:getOptionValue()
    local min_quality = self.subviews.min_quality:getOptionValue()
    local max_quality = self.subviews.max_quality:getOptionValue()
    for _,choice in ipairs(raw_choices) do
        local data = choice.data
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
        if only_agreement and not is_agreement_item(data.item_type) then
            goto continue
        end
        if not include_banned then
            if choice.item_id then
                if data.items[choice.item_id].banned then
                    goto continue
                end
            elseif data.has_banned then
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

MoveGoodsModal = defclass(MoveGoodsModal, gui.ZScreenModal)
MoveGoodsModal.ATTRS {
    focus_path='movegoods',
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
            if item_data.pending and not pending[item_id] then
                item_data.item.flags.forbid = false
                dfhack.items.markForTrade(item_data.item, depot)
            elseif not item_data.pending and pending[item_id] then
                local spec_ref = dfhack.items.getSpecificRef(item_data.item, df.specific_ref_type.JOB)
                if spec_ref then
                    dfhack.job.removeJob(spec_ref.data.job)
                end
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

OVERLAY_WIDGETS = {
    trade=CaravanTradeOverlay,
    diplomacy=DiplomacyOverlay,
    movegoods=MoveGoodsOverlay,
}

INTERESTING_FLAGS = {
    casualty = 'Casualty',
    hardship = 'Encountered hardship',
    seized = 'Goods seized',
    offended = 'Offended'
}
local caravans = df.global.plotinfo.caravans

local function caravans_from_ids(ids)
    if not ids or #ids == 0 then
        return caravans
    end

    local c = {} --as:df.caravan_state[]
    for _,id in ipairs(ids) do
        id = tonumber(id)
        if id then
            c[id] = caravans[id]
        end
    end
    return c
end

function bring_back(car)
    if car.trade_state ~= df.caravan_state.T_trade_state.AtDepot then
        car.trade_state = df.caravan_state.T_trade_state.Approaching
    end
end

local commands = {}

function commands.list()
    for id, car in pairs(caravans) do
        print(dfhack.df2console(('%d: %s caravan from %s'):format(
            id,
            df.creature_raw.find(df.historical_entity.find(car.entity).race).name[2], -- adjective
            dfhack.TranslateName(df.historical_entity.find(car.entity).name)
        )))
        print('  ' .. (df.caravan_state.T_trade_state[car.trade_state] or ('Unknown state: ' .. car.trade_state)))
        print(('  %d day(s) remaining'):format(math.floor(car.time_remaining / 120)))
        for flag, msg in pairs(INTERESTING_FLAGS) do
            if car.flags[flag] then
                print('  ' .. msg)
            end
        end
    end
end

function commands.extend(days, ...)
    days = tonumber(days or 7) or qerror('invalid number of days: ' .. days) --luacheck: retype
    for id, car in pairs(caravans_from_ids{...}) do
        car.time_remaining = car.time_remaining + (days * 120)
        bring_back(car)
    end
end

function commands.happy(...)
    for id, car in pairs(caravans_from_ids{...}) do
        -- all flags default to false
        car.flags.whole = 0
        bring_back(car)
    end
end

function commands.leave(...)
    for id, car in pairs(caravans_from_ids{...}) do
        car.trade_state = df.caravan_state.T_trade_state.Leaving
    end
end

local function isDisconnectedPackAnimal(unit)
    if unit.following then
        local dragger = unit.following
        return (
            unit.relationship_ids[ df.unit_relationship_type.Dragger ] == -1 and
            dragger.relationship_ids[ df.unit_relationship_type.Draggee ] == -1
        )
    end
end

local function getPrintableUnitName(unit)
    local visible_name = dfhack.units.getVisibleName(unit)
    local profession_name = dfhack.units.getProfessionName(unit)
    if visible_name.has_name then
        return ('%s (%s)'):format(dfhack.TranslateName(visible_name), profession_name)
    end
    return profession_name  -- for unnamed animals
end

local function rejoin_pack_animals()
    print('Reconnecting disconnected pack animals...')
    local found = false
    for _, unit in pairs(df.global.world.units.active) do
        if unit.flags1.merchant and isDisconnectedPackAnimal(unit) then
            local dragger = unit.following
            print(('  %s  <->  %s'):format(
                dfhack.df2console(getPrintableUnitName(unit)),
                dfhack.df2console(getPrintableUnitName(dragger))
            ))
            unit.relationship_ids[ df.unit_relationship_type.Dragger ] = dragger.id
            dragger.relationship_ids[ df.unit_relationship_type.Draggee ] = unit.id
            found = true
        end
    end
    if (found) then
        print('All pack animals reconnected.')
    else
        print('No disconnected pack animals found.')
    end
end

function commands.unload()
    rejoin_pack_animals()
end

function commands.help()
    print(dfhack.script_help())
end

function main(args)
    local command = table.remove(args, 1) or 'list'
    if commands[command] then
        commands[command](table.unpack(args))
    else
        commands.help()
        print()
        qerror("No such command: " .. command)
    end
end

if not dfhack_flags.module then
    main{...}
end
