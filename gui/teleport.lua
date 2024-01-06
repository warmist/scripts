local gui = require('gui')
local guidm = require('gui.dwarfmode')
local widgets = require('gui.widgets')

local function get_dims(pos1, pos2)
    local width, height, depth = math.abs(pos1.x - pos2.x) + 1,
            math.abs(pos1.y - pos2.y) + 1,
            math.abs(pos1.z - pos2.z) + 1
    return width, height, depth
end

local function is_good_unit(unit, include)
    if not unit then return false end
    if item.flags.forbid and not include.forbidden then return false end
    if item.flags.in_job and not include.in_job then return false end
    if item.flags.trader and not include.trader then return false end
    return true
end

-----------------
-- Teleport
--

Teleport = defclass(Teleport, widgets.Window)
Teleport.ATTRS {
    frame_title='Teleport',
    frame={w=48, h=28, r=2, t=18},
    resizable=true,
    resize_min={h=10},
    autoarrange_subviews=true,
    autoarrange_gap=1,
}

function Teleport:init()
    self.mark = nil
    self.prev_help_text = ''
    self:reset_selected_state() -- sets self.selected_*
    self:refresh_dump_items() -- sets self.dump_items
    self:reset_double_click() -- sets self.last_map_click_ms and self.last_map_click_pos

    self:addviews{
        widgets.WrappedLabel{
            frame={l=0},
            text_to_wrap=self:callback('get_help_text'),
        },
        widgets.Panel{
            frame={h=2},
            subviews={
                widgets.Label{
                    frame={l=0, t=0},
                    text={
                        'Selected area: ',
                        {text=self:callback('get_selection_area_text')}
                    },
                },
            },
            visible=function() return self.mark end,
        },
        widgets.HotkeyLabel{
            frame={l=0},
            label='Teleport to tile under mouse cursor',
            key='CUSTOM_CTRL_T',
            auto_width=true,
            on_activate=self:callback('do_teleport'),
            enabled=function() return dfhack.gui.getMousePos() end,
        },
        widgets.ResizingPanel{
            autoarrange_subviews=true,
            subviews={
                widgets.ToggleHotkeyLabel{
                    view_id='include_citizens',
                    frame={l=0},
                    label='Include citizen units',
                    key='CUSTOM_CTRL_U',
                    auto_width=true,
                    initial_option=true,
                },
                widgets.ToggleHotkeyLabel{
                    view_id='include_friendly',
                    frame={l=0},
                    label='Include friendly units',
                    key='CUSTOM_CTRL_F',
                    auto_width=true,
                    initial_option=true,
                },
                widgets.ToggleHotkeyLabel{
                    view_id='include_hostile',
                    frame={l=0},
                    label='Include hostile units',
                    key='CUSTOM_CTRL_H',
                    auto_width=true,
                    initial_option=true,
                },
            },
        },
        widgets.Label{
            text={
                {text=function() return #self.selected_units.list end}
                ' selected units:'
            },
        },
        widgets.List{
            view_id='list',
            frame={l=0, r=0, b=2}
        },
        widgets.HotkeyLabel{
            frame={l=0},
            key='CUSTOM_R',
            label='Remove selected unit from list',
            auto_width=true,
            on_activate=self:callback('remove_unit'),
            enabled=function() return #self.selected_items.list > 0 end,
        },
        widgets.HotkeyLabel{
            frame={l=0},
            key='CUSTOM_SHIFT_R',
            label='Remove all selected units',
            auto_width=true,
            on_activate=self:callback('reset_selected_state'),
            enabled=function() return #self.selected_items.list > 0 end,
        },
}
end

function Teleport:reset_double_click()
    self.last_map_click_ms = 0
    self.last_map_click_pos = {}
end

function Teleport:reset_selected_state()
    self.selected_items = {list={}, set={}}
    self.selected_coords = {} -- z -> y -> x -> true
    self.selected_bounds = {} -- z -> bounds rect
    if next(self.subviews) then
        self:updateLayout()
    end
end

function Teleport:get_include()
    local include = {forbidden=false, in_job=false, trader=false}
    if next(self.subviews) then
        include.forbidden = self.subviews.include_forbidden:getOptionValue()
        include.in_job = self.subviews.include_in_job:getOptionValue()
        include.trader = self.subviews.include_trader:getOptionValue()
    end
    return include
end

function Teleport:refresh_dump_items()
    local dump_items = {}
    local include = self:get_include()
    for _,item in ipairs(df.global.world.items.all) do
        if not is_good_item(item, include) then goto continue end
        if item.flags.dump then
            table.insert(dump_items, item)
        end
        ::continue::
    end
    self.dump_items = dump_items
    if next(self.subviews) then
        self:updateLayout()
    end
end

function Teleport:get_help_text()
    local ret = 'Double click on a tile to teleport'
    if #self.selected_items.list > 0 then
        ret = ('%s %d highlighted item(s).'):format(ret, #self.selected_items.list)
    else
        ret = ('%s %d item(s) marked for dumping.'):format(ret, #self.dump_items)
    end
    if ret ~= self.prev_help_text then
        self.prev_help_text = ret
    end
    return ret
end

function Teleport:get_selection_area_text()
    local mark = self.mark
    if not mark then return '' end
    local cursor = dfhack.gui.getMousePos() or {x=mark.x, y=mark.y, z=df.global.window_z}
    return ('%dx%dx%d'):format(get_dims(mark, cursor))
end

function Teleport:get_bounds(cursor, mark)
    cursor = cursor or self.mark
    mark = mark or self.mark or cursor
    if not mark then return end

    return {
        x1=math.min(cursor.x, mark.x),
        x2=math.max(cursor.x, mark.x),
        y1=math.min(cursor.y, mark.y),
        y2=math.max(cursor.y, mark.y),
        z1=math.min(cursor.z, mark.z),
        z2=math.max(cursor.z, mark.z)
    }
end

function Teleport:select_items_in_block(block, bounds)
    local include = self:get_include()
    for _,item_id in ipairs(block.items) do
        local item = df.item.find(item_id)
        if not is_good_item(item, include) then
            goto continue
        end
        local x, y, z = dfhack.items.getPosition(item)
        if not x then goto continue end
        if not self.selected_items.set[item_id] and
                x >= bounds.x1 and x <= bounds.x2 and
                y >= bounds.y1 and y <= bounds.y2 then
            self.selected_items.set[item_id] = true
            table.insert(self.selected_items.list, item)
            ensure_key(ensure_key(self.selected_coords, z), y)[x] = true
            local selected_bounds = ensure_key(self.selected_bounds, z,
                    {x1=x, x2=x, y1=y, y2=y})
            selected_bounds.x1 = math.min(selected_bounds.x1, x)
            selected_bounds.x2 = math.max(selected_bounds.x2, x)
            selected_bounds.y1 = math.min(selected_bounds.y1, y)
            selected_bounds.y2 = math.max(selected_bounds.y2, y)
        end
        ::continue::
    end
end

function Teleport:select_box(bounds)
    if not bounds then return end
    local seen_blocks = {}
    for z=bounds.z1,bounds.z2 do
        for y=bounds.y1,bounds.y2 do
            for x=bounds.x1,bounds.x2 do
                local block = dfhack.maps.getTileBlock(xyz2pos(x, y, z))
                local block_str = tostring(block)
                if not seen_blocks[block_str] then
                    seen_blocks[block_str] = true
                    self:select_items_in_block(block, bounds)
                end
            end
        end
    end
end

function Teleport:onInput(keys)
    if Teleport.super.onInput(self, keys) then return true end
    if keys._MOUSE_R and self.mark then
        self.mark = nil
        self:updateLayout()
        return true
    elseif keys._MOUSE_L then
        if self:getMouseFramePos() then return true end
        local pos = dfhack.gui.getMousePos()
        if not pos then
            self:reset_double_click()
            return false
        end
        local now_ms = dfhack.getTickCount()
        if same_xyz(pos, self.last_map_click_pos) and
                now_ms - self.last_map_click_ms <= widgets.DOUBLE_CLICK_MS then
            self:reset_double_click()
            self:do_teleport(pos)
            self.mark = nil
            self:updateLayout()
            return true
        end
        self.last_map_click_ms = now_ms
        self.last_map_click_pos = pos
        if self.mark then
            self:select_box(self:get_bounds(pos))
            self:reset_double_click()
            self.mark = nil
            self:updateLayout()
            return true
        end
        self.mark = pos
        self:updateLayout()
        return true
    end
end

local to_pen = dfhack.pen.parse
local CURSOR_PEN = to_pen{ch='o', fg=COLOR_BLUE,
                         tile=dfhack.screen.findGraphicsTile('CURSORS', 5, 22)}
local BOX_PEN = to_pen{ch='X', fg=COLOR_GREEN,
                       tile=dfhack.screen.findGraphicsTile('CURSORS', 0, 0)}
local SELECTED_PEN = to_pen{ch='I', fg=COLOR_GREEN,
                       tile=dfhack.screen.findGraphicsTile('CURSORS', 1, 2)}

function Teleport:onRenderFrame(dc, rect)
    Teleport.super.onRenderFrame(self, dc, rect)

    local highlight_coords = self.selected_coords[df.global.window_z]
    if highlight_coords then
        local function get_overlay_pen(pos)
            if safe_index(highlight_coords, pos.y, pos.x) then
                return SELECTED_PEN
            end
        end
        guidm.renderMapOverlay(get_overlay_pen, self.selected_bounds[df.global.window_z])
    end

    -- draw selection box and cursor (blinking when in ascii mode)
    local cursor = dfhack.gui.getMousePos()
    local selection_bounds = self:get_bounds(cursor)
    if selection_bounds and (dfhack.screen.inGraphicsMode() or gui.blink_visible(500)) then
        guidm.renderMapOverlay(
            function() return self.mark and BOX_PEN or CURSOR_PEN end,
            selection_bounds)
    end
end

function Teleport:do_teleport(pos)
    pos = pos or dfhack.gui.getMousePos()
    if not pos then return end
    print(('teleporting %d units'):format(#self.unit_ids))
    for _,unid in ipairs(self.unit_ids) do
        local unit = df.unit.find(unid)
        if unit then
            dfhack.units.teleport(unit, pos)
        end
    end
    self.unit_ids = {}
    self:reset_selected_state()
    self:updateLayout()
end

-----------------
-- TeleportScreen
--

TeleportScreen = defclass(TeleportScreen, gui.ZScreen)
TeleportScreen.ATTRS {
    focus_path='autodump',
    pass_movement_keys=true,
    pass_mouse_clicks=false,
}

function TeleportScreen:init()
    self:addviews{Teleport{}}
end

function TeleportScreen:onDismiss()
    view = nil
end

view = view and view:raise() or TeleportScreen{}:show()
