--@ module = true

-- TODO: the category checkbox that indicates whether all items in the category
-- are selected can be incorrect after the overlay adjusts the container
-- selection. the state is in trade.current_type_a_flag, but figuring out which
-- index to modify is non-trivial.

local common = reqscript('internal/caravan/common')
local gui = require('gui')
local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')

trader_selected_state = trader_selected_state or {}
broker_selected_state = broker_selected_state or {}
handle_ctrl_click_on_render = handle_ctrl_click_on_render or false
handle_shift_click_on_render = handle_shift_click_on_render or false

local GOODFLAG = {
    UNCONTAINED_UNSELECTED = 0,
    UNCONTAINED_SELECTED = 1,
    CONTAINED_UNSELECTED = 2,
    CONTAINED_SELECTED = 3,
    CONTAINER_COLLAPSED_UNSELECTED = 4,
    CONTAINER_COLLAPSED_SELECTED = 5,
}

local trade = df.global.game.main_interface.trade

-- -------------------
-- Trade
--

Trade = defclass(Trade, widgets.Window)
Trade.ATTRS {
    frame_title='Select trade goods',
    frame={w=78, h=45},
    resizable=true,
    resize_min={h=27},
}

local VALUE_COL_WIDTH = 8

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
    if a.data.value == b.data.value then
        return sort_by_name_desc(a, b)
    end
    return a.data.value > b.data.value
end

local function sort_by_value_asc(a, b)
    if a.data.value == b.data.value then
        return sort_by_name_desc(a, b)
    end
    return a.data.value < b.data.value
end

function Trade:init()
    self.choices = {[0]={}, [1]={}}
    self.cur_page = 1

    self:addviews{
        widgets.CycleHotkeyLabel{
            view_id='sort',
            frame={l=0, t=0, w=21},
            label='Sort by:',
            key='CUSTOM_SHIFT_S',
            options={
                {label='value'..common.CH_DN, value=sort_by_value_desc},
                {label='value'..common.CH_UP, value=sort_by_value_asc},
                {label='name'..common.CH_DN, value=sort_by_name_desc},
                {label='name'..common.CH_UP, value=sort_by_name_asc},
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
            view_id='trade_bins',
            frame={t=2, l=0, w=36},
            label='Bins:',
            key='CUSTOM_SHIFT_B',
            options={
                {label='trade bin with contents', value=true},
                {label='trade contents only', value=false},
            },
            initial_option=false,
            on_change=function() self:refresh_list() end,
        },
        widgets.TabBar{
            frame={t=4, l=0},
            labels={
                'Caravan goods',
                'Fort goods',
            },
            on_select=function(idx)
                self.cur_page = idx
                self:refresh_list()
            end,
            get_cur_page=function() return self.cur_page end,
        },
        widgets.Panel{
            frame={t=6, l=0, r=0, b=4},
            subviews={
                widgets.CycleHotkeyLabel{
                    view_id='sort_value',
                    frame={l=2, t=0, w=7},
                    options={
                        {label='value', value=sort_noop},
                        {label='value'..common.CH_DN, value=sort_by_value_desc},
                        {label='value'..common.CH_UP, value=sort_by_value_asc},
                    },
                    initial_option=sort_by_value_desc,
                    on_change=self:callback('refresh_list', 'sort_value'),
                },
                widgets.CycleHotkeyLabel{
                    view_id='sort_name',
                    frame={l=2+VALUE_COL_WIDTH+2, t=0, w=6},
                    options={
                        {label='name', value=sort_noop},
                        {label='name'..common.CH_DN, value=sort_by_name_desc},
                        {label='name'..common.CH_UP, value=sort_by_name_asc},
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
        widgets.HotkeyLabel{
            frame={l=0, b=2},
            label='Select all/none',
            key='CUSTOM_CTRL_A',
            on_activate=self:callback('toggle_visible'),
            auto_width=true,
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

function Trade:refresh_list(sort_widget, sort_fn)
    sort_widget = sort_widget or 'sort'
    sort_fn = sort_fn or self.subviews.sort:getOptionValue()
    if sort_fn == sort_noop then
        self.subviews[sort_widget]:cycle()
        return
    end
    for _,widget_name in ipairs{'sort', 'sort_value', 'sort_name'} do
        self.subviews[widget_name]:setOption(sort_fn)
    end
    local list = self.subviews.list
    local saved_filter = list:getFilter()
    list:setFilter('')
    list:setChoices(self:get_choices(), list:getSelected())
    list:setFilter(saved_filter)
end

local TOGGLE_MAP = {
    [GOODFLAG.UNCONTAINED_UNSELECTED] = GOODFLAG.UNCONTAINED_SELECTED,
    [GOODFLAG.UNCONTAINED_SELECTED] = GOODFLAG.UNCONTAINED_UNSELECTED,
    [GOODFLAG.CONTAINED_UNSELECTED] = GOODFLAG.CONTAINED_SELECTED,
    [GOODFLAG.CONTAINED_SELECTED] = GOODFLAG.CONTAINED_UNSELECTED,
    [GOODFLAG.CONTAINER_COLLAPSED_UNSELECTED] = GOODFLAG.CONTAINER_COLLAPSED_SELECTED,
    [GOODFLAG.CONTAINER_COLLAPSED_SELECTED] = GOODFLAG.CONTAINER_COLLAPSED_UNSELECTED,
}

local TARGET_MAP = {
    [true]={
        [GOODFLAG.UNCONTAINED_UNSELECTED] = GOODFLAG.UNCONTAINED_SELECTED,
        [GOODFLAG.UNCONTAINED_SELECTED] = GOODFLAG.UNCONTAINED_SELECTED,
        [GOODFLAG.CONTAINED_UNSELECTED] = GOODFLAG.CONTAINED_SELECTED,
        [GOODFLAG.CONTAINED_SELECTED] = GOODFLAG.CONTAINED_SELECTED,
        [GOODFLAG.CONTAINER_COLLAPSED_UNSELECTED] = GOODFLAG.CONTAINER_COLLAPSED_SELECTED,
        [GOODFLAG.CONTAINER_COLLAPSED_SELECTED] = GOODFLAG.CONTAINER_COLLAPSED_SELECTED,
    },
    [false]={
        [GOODFLAG.UNCONTAINED_UNSELECTED] = GOODFLAG.UNCONTAINED_UNSELECTED,
        [GOODFLAG.UNCONTAINED_SELECTED] = GOODFLAG.UNCONTAINED_UNSELECTED,
        [GOODFLAG.CONTAINED_UNSELECTED] = GOODFLAG.CONTAINED_UNSELECTED,
        [GOODFLAG.CONTAINED_SELECTED] = GOODFLAG.CONTAINED_UNSELECTED,
        [GOODFLAG.CONTAINER_COLLAPSED_UNSELECTED] = GOODFLAG.CONTAINER_COLLAPSED_UNSELECTED,
        [GOODFLAG.CONTAINER_COLLAPSED_SELECTED] = GOODFLAG.CONTAINER_COLLAPSED_UNSELECTED,
    },
}

local TARGET_REVMAP = {
    [GOODFLAG.UNCONTAINED_UNSELECTED] = false,
    [GOODFLAG.UNCONTAINED_SELECTED] = true,
    [GOODFLAG.CONTAINED_UNSELECTED] = false,
    [GOODFLAG.CONTAINED_SELECTED] = true,
    [GOODFLAG.CONTAINER_COLLAPSED_UNSELECTED] = false,
    [GOODFLAG.CONTAINER_COLLAPSED_SELECTED] = true,
}

local function get_entry_icon(data)
    if TARGET_REVMAP[trade.goodflag[data.list_idx][data.item_idx]] then
        return common.ALL_PEN
    end
end

local function make_choice_text(desc, value)
    return {
        {width=VALUE_COL_WIDTH, rjustify=true, text=common.obfuscate_value(value)},
        {gap=2, text=desc},
    }
end

function Trade:cache_choices(list_idx, trade_bins)
    if self.choices[list_idx][trade_bins] then return self.choices[list_idx][trade_bins] end

    local goodflags = trade.goodflag[list_idx]
    local trade_bins_choices, notrade_bins_choices = {}, {}
    local parent_idx
    for item_idx, item in ipairs(trade.good[list_idx]) do
        local goodflag = goodflags[item_idx]
        if goodflag ~= GOODFLAG.CONTAINED_UNSELECTED and goodflag ~= GOODFLAG.CONTAINED_SELECTED then
            parent_idx = nil
        end
        local desc = item.flags.artifact and common.get_artifact_name(item) or
            dfhack.items.getDescription(item, 0, true)
        local data = {
            desc=desc,
            value=common.get_perceived_value(item, trade.mer, list_idx == 1),
            list_idx=list_idx,
            item_idx=item_idx,
        }
        if parent_idx then
            data.update_container_fn = function(from, to)
                -- TODO
            end
        end
        local choice = {
            search_key=common.make_search_key(desc),
            icon=curry(get_entry_icon, data),
            data=data,
            text=make_choice_text(desc, data.value),
        }
        local is_container = df.item_binst:is_instance(item)
        if not data.update_container_fn then
            table.insert(trade_bins_choices, choice)
        end
        if data.update_container_fn or not is_container then
            table.insert(notrade_bins_choices, choice)
        end
        if is_container then parent_idx = item_idx end
    end

    self.choices[list_idx][true] = trade_bins_choices
    self.choices[list_idx][false] = notrade_bins_choices
    return self:cache_choices(list_idx, trade_bins)
end

function Trade:get_choices()
    local choices = self:cache_choices(self.cur_page-1, self.subviews.trade_bins:getOptionValue())
    table.sort(choices, self.subviews.sort:getOptionValue())
    return choices
end

local function toggle_item_base(choice, target_value)
    local goodflag = trade.goodflag[choice.data.list_idx][choice.data.item_idx]
    local goodflag_map = target_value == nil and TOGGLE_MAP or TARGET_MAP[target_value]
    trade.goodflag[choice.data.list_idx][choice.data.item_idx] = goodflag_map[goodflag]
    target_value = TARGET_REVMAP[trade.goodflag[choice.data.list_idx][choice.data.item_idx]]
    if choice.data.update_container_fn then
        choice.data.update_container_fn(TARGET_REVMAP[goodflag], target_value)
    end
    return target_value
end

function Trade:select_item(idx, choice)
    if not dfhack.internal.getModifiers().shift then
        self.prev_list_idx = self.subviews.list.list:getSelected()
    end
end

function Trade:toggle_item(idx, choice)
    toggle_item_base(choice)
end

function Trade:toggle_range(idx, choice)
    if not self.prev_list_idx then
        self:toggle_item(idx, choice)
        return
    end
    local choices = self.subviews.list:getVisibleChoices()
    local list_idx = self.subviews.list.list:getSelected()
    local target_value
    for i = list_idx, self.prev_list_idx, list_idx < self.prev_list_idx and 1 or -1 do
        target_value = toggle_item_base(choices[i], target_value)
    end
    self.prev_list_idx = list_idx
end

function Trade:toggle_visible()
    local target_value
    for _, choice in ipairs(self.subviews.list:getVisibleChoices()) do
        target_value = toggle_item_base(choice, target_value)
    end
end

-- -------------------
-- TradeScreen
--

view = view or nil

TradeScreen = defclass(TradeScreen, gui.ZScreen)
TradeScreen.ATTRS {
    focus_path='caravan/trade',
}

function TradeScreen:init()
    self:addviews{Trade{}}
end

function TradeScreen:onDismiss()
    view = nil
end

-- -------------------
-- TradeOverlay
--

local MARGIN_HEIGHT = 26 -- screen height *other* than the list

local function set_height(list_idx, delta)
    trade.i_height[list_idx] = trade.i_height[list_idx] + delta
    if delta >= 0 then return end
    _,screen_height = dfhack.screen.getWindowSize()
    -- list only increments in three tiles at a time
    local page_height = ((screen_height - MARGIN_HEIGHT) // 3) * 3
    trade.scroll_position_item[list_idx] = math.max(0,
            math.min(trade.scroll_position_item[list_idx],
                     trade.i_height[list_idx] - page_height))
end

local function select_shift_clicked_container_items(new_state, old_state, list_idx)
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
        local is_container = df.item_binst:is_instance(trade.good[list_idx][k])
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
        set_height(list_idx, collapsed_item_count * -3)
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
local function toggle_ctrl_clicked_containers(new_state, old_state, list_idx)
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
        local is_container = df.item_binst:is_instance(trade.good[list_idx][k])
        if not is_container then goto continue end

        new_state[k] = CTRL_CLICK_STATE_MAP[old_state[k]]
        in_container = true
        is_collapsing = goodflag == GOODFLAG.UNCONTAINED_UNSELECTED or goodflag == GOODFLAG.UNCONTAINED_SELECTED

        ::continue::
    end

    if toggled_item_count > 0 then
        set_height(list_idx, toggled_item_count * 3 * (is_collapsing and -1 or 1))
    end
end

local function collapseTypes(types_list, list_idx)
    local type_on_count = 0

    for k in ipairs(types_list) do
        local type_on = trade.current_type_a_on[list_idx][k]
        if type_on then
            type_on_count = type_on_count + 1
        end
        types_list[k] = false
    end

    trade.i_height[list_idx] = type_on_count * 3
    trade.scroll_position_item[list_idx] = 0
end

local function collapseAllTypes()
   collapseTypes(trade.current_type_a_expanded[0], 0)
   collapseTypes(trade.current_type_a_expanded[1], 1)
end

local function collapseContainers(item_list, list_idx)
    local num_items_collapsed = 0
    for k, goodflag in ipairs(item_list) do
        if goodflag == GOODFLAG.CONTAINED_UNSELECTED
                or goodflag == GOODFLAG.CONTAINED_SELECTED then
            goto continue
        end

        local item = trade.good[list_idx][k]
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
        set_height(list_idx, num_items_collapsed * -3)
    end
end

local function collapseAllContainers()
    collapseContainers(trade.goodflag[0], 0)
    collapseContainers(trade.goodflag[1], 1)
end

local function collapseEverything()
    collapseAllContainers()
    collapseAllTypes()
end

local function copyGoodflagState()
    trader_selected_state = copyall(trade.goodflag[0])
    broker_selected_state = copyall(trade.goodflag[1])
end

TradeOverlay = defclass(TradeOverlay, overlay.OverlayWidget)
TradeOverlay.ATTRS{
    default_pos={x=-3,y=-12},
    default_enabled=true,
    viewscreens='dwarfmode/Trade/Default',
    frame={w=27, h=15},
    frame_style=gui.MEDIUM_FRAME,
    frame_background=gui.CLEAR_PEN,
}

function TradeOverlay:init()
    self:addviews{
        widgets.HotkeyLabel{
            frame={t=0, l=0},
            label='DFHack trade UI',
            key='CUSTOM_CTRL_T',
            on_activate=function() view = view and view:raise() or TradeScreen{}:show() end,
        },
        widgets.Label{
            frame={t=2, l=0},
            text={
                {text='Shift+Click checkbox', pen=COLOR_LIGHTGREEN}, ':',
                NEWLINE,
                '  select items inside bin',
            },
        },
        widgets.Label{
            frame={t=5, l=0},
            text={
                {text='Ctrl+Click checkbox', pen=COLOR_LIGHTGREEN}, ':',
                NEWLINE,
                '  collapse/expand bin',
            },
        },
        widgets.HotkeyLabel{
            frame={t=8, l=0},
            label='collapse bins',
            key='CUSTOM_CTRL_C',
            on_activate=collapseAllContainers,
        },
        widgets.HotkeyLabel{
            frame={t=9, l=0},
            label='collapse all',
            key='CUSTOM_CTRL_X',
            on_activate=collapseEverything,
        },
        widgets.Label{
            frame={t=11, l=0},
            text = 'Shift+Scroll',
            text_pen=COLOR_LIGHTGREEN,
        },
        widgets.Label{
            frame={t=11, l=12},
            text = ': fast scroll',
        },
    }
end

-- do our alterations *after* the vanilla response to the click has registered. otherwise
-- it's very difficult to figure out which item has been clicked
function TradeOverlay:onRenderBody(dc)
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

function TradeOverlay:onInput(keys)
    if TradeOverlay.super.onInput(self, keys) then return true end

    if keys._MOUSE_L_DOWN then
        if dfhack.internal.getModifiers().shift then
            handle_shift_click_on_render = true
            copyGoodflagState()
        elseif dfhack.internal.getModifiers().ctrl then
            handle_ctrl_click_on_render = true
            copyGoodflagState()
        end
    elseif keys._MOUSE_R_DOWN or keys.LEAVESCREEN then
        if view then
            view:dismiss()
        end
    end
end
