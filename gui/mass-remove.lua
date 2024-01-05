-- building/construction mass removal/suspension tool

local gui = require('gui')
local guidm = require('gui.dwarfmode')
local utils = require('utils')
local widgets = require('gui.widgets')

local function noop()
end

local function remove_building(built, planned, bld)
    if (built and bld:getBuildStage() == bld:getMaxBuildStage()) or
        (planned and bld:getBuildStage() ~= bld:getMaxBuildStage())
    then
        dfhack.buildings.deconstruct(bld)
    end
end

local function remove_construction(built, planned, pos, bld)
    if planned and bld then
        remove_building(false, true, bld)
    elseif built and not bld then
        dfhack.constructions.designateRemove(pos)
    end
end

local function remove_stockpile(bld)
    dfhack.buildings.deconstruct(bld)
end

local function remove_zone(pos)
    for _, bld in ipairs(dfhack.buildings.findCivzonesAt(pos) or {}) do
        dfhack.buildings.deconstruct(bld)
    end
end

--
-- DimsPanel
--

local function get_dims(pos1, pos2)
    local width, height, depth = math.abs(pos1.x - pos2.x) + 1,
            math.abs(pos1.y - pos2.y) + 1,
            math.abs(pos1.z - pos2.z) + 1
    return width, height, depth
end

DimsPanel = defclass(DimsPanel, widgets.ResizingPanel)
DimsPanel.ATTRS{
    get_mark_fn=DEFAULT_NIL,
    autoarrange_subviews=true,
}

function DimsPanel:init()
    self:addviews{
        widgets.WrappedLabel{
            text_to_wrap=self:callback('get_action_text')
        },
        widgets.TooltipLabel{
            indent=1,
            text={{text=self:callback('get_area_text')}},
            show_tooltip=self.get_mark_fn
        },
    }
end

function DimsPanel:get_action_text()
    local str = self.get_mark_fn() and 'second' or 'first'
    return ('Select the %s corner with the mouse.'):format(str)
end

function DimsPanel:get_area_text()
    local mark = self.get_mark_fn()
    if not mark then return '' end
    local other = dfhack.gui.getMousePos()
            or {x=mark.x, y=mark.y, z=df.global.window_z}
    local width, height, depth = get_dims(mark, other)
    local tiles = width * height * depth
    local plural = tiles > 1 and 's' or ''
    return ('%dx%dx%d (%d tile%s)'):format(width, height, depth, tiles, plural)
end

local function is_something_selected()
    return dfhack.gui.getSelectedBuilding(true) or
        dfhack.gui.getSelectedStockpile(true) or
        dfhack.gui.getSelectedCivZone(true)
end

--
-- MassRemove
--

MassRemove = defclass(MassRemove, widgets.Window)
MassRemove.ATTRS{
    frame_title='Mass Remove',
    frame={w=47, h=18, r=2, t=18},
    resizable=true,
    resize_min={h=9},
    autoarrange_subviews=true,
    autoarrange_gap=1,
}

function MassRemove:init()
    self:addviews{
        widgets.WrappedLabel{
            view_id='warning',
            text_to_wrap='Please deselect any selected buildings, stockpiles or zones before attempting to remove them.',
            text_pen=COLOR_RED,
            visible=is_something_selected,
        },
        widgets.WrappedLabel{
            text_to_wrap='Designate buildings, constructions, stockpiles, and/or zones for removal.',
            visible=function() return not is_something_selected() end,
        },
        DimsPanel{
            get_mark_fn=function() return self.mark end,
            visible=function() return not is_something_selected() end,
        },
        widgets.CycleHotkeyLabel{
            view_id='buildings',
            label='Buildings:',
            key='CUSTOM_B',
            key_back='CUSTOM_SHIFT_B',
            option_gap=5,
            options={
                {label='Leave alone', value=noop, pen=COLOR_BLUE},
                {label='Remove built and planned', value=curry(remove_building, true, true), pen=COLOR_RED},
                {label='Remove built', value=curry(remove_building, true, false), pen=COLOR_LIGHTRED},
                {label='Remove planned', value=curry(remove_building, false, true), pen=COLOR_YELLOW},
            },
            initial_option=2,
        },
        widgets.CycleHotkeyLabel{
            view_id='constructions',
            label='Constructions:',
            key='CUSTOM_C',
            key_back='CUSTOM_SHIFT_C',
            option_gap=1,
            options={
                {label='Leave alone', value=noop, pen=COLOR_BLUE},
                {label='Remove built and planned', value=curry(remove_construction, true, true), pen=COLOR_RED},
                {label='Remove built', value=curry(remove_construction, true, false), pen=COLOR_LIGHTRED},
                {label='Remove planned', value=curry(remove_construction, false, true), pen=COLOR_YELLOW},
            },
        },
        widgets.CycleHotkeyLabel{
            view_id='stockpiles',
            label='Stockpiles:',
            key='CUSTOM_S',
            key_sep=':  ',
            option_gap=4,
            options={
                {label='Leave alone', value=noop, pen=COLOR_BLUE},
                {label='Remove', value=remove_stockpile, pen=COLOR_RED},
            },
        },
        widgets.CycleHotkeyLabel{
            view_id='zones',
            label='Zones:',
            key='CUSTOM_Z',
            key_sep=':  ',
            option_gap=9,
            options={
                {label='Leave alone', value=noop, pen=COLOR_BLUE},
                {label='Remove', value=remove_zone, pen=COLOR_RED},
            },
        },
    }

    self:refresh_grid()
end

function MassRemove:refresh_grid()
    local grid = {}
    for _, job in utils.listpairs(df.global.world.jobs.list) do
        if job.job_type == df.job_type.RemoveConstruction then
            pos = job.pos
            ensure_key(ensure_key(grid, pos.z), pos.y)[pos.x] = job
        end
    end
    self.grid = grid
end

local function get_bounds(mark, cur)
    cur = cur or dfhack.gui.getMousePos()
    if not cur then return end
    mark = mark or cur

    return {
        x1=math.min(cur.x, mark.x),
        x2=math.max(cur.x, mark.x),
        y1=math.min(cur.y, mark.y),
        y2=math.max(cur.y, mark.y),
        z1=math.min(cur.z, mark.z),
        z2=math.max(cur.z, mark.z),
    }
end

function MassRemove:onInput(keys)
    if MassRemove.super.onInput(self, keys) then return true end

    if keys.LEAVESCREEN or keys._MOUSE_R then
        if self.mark then
            self.mark = nil
            self:updateLayout()
            return true
        end
        return false
    end

    local pos = nil
    if keys._MOUSE_L and not self:getMouseFramePos() then
        pos = dfhack.gui.getMousePos()
    end
    if not pos then return false end

    if is_something_selected() then
        self.mark = nil
        self:updateLayout()
        return true
    end

    if self.mark then
        self:commit(get_bounds(self.mark, pos))
        self.mark = nil
        self:updateLayout()
        self:refresh_grid()
    else
        self.mark = pos
        self:updateLayout()
    end
    return true
end

local to_pen = dfhack.pen.parse
local SELECTION_PEN = to_pen{ch='X', fg=COLOR_GREEN,
                       tile=dfhack.screen.findGraphicsTile('CURSORS', 1, 2)}
local DESTROYING_PEN = to_pen{ch='d', fg=COLOR_LIGHTRED,
                       tile=dfhack.screen.findGraphicsTile('CURSORS', 3, 0)}

local function is_construction(pos)
    local tt = dfhack.maps.getTileType(pos)
    if not tt then return false end
    return df.tiletype.attrs[tt].material == df.tiletype_material.CONSTRUCTION
end

local function is_destroying_construction(pos, grid)
    if safe_index(grid, pos.z, pos.y, pos.x) then return true end
    return is_construction(pos) and
        dfhack.maps.getTileFlags(pos).dig == df.tile_dig_designation.Default
end

local function get_first_job(bld)
    if not bld then return end
    if #bld.jobs ~= 1 then return end
    return bld.jobs[0]
end

local function get_job_pen(pos, grid)
    if is_destroying_construction(pos) then
        return DESTROYING_PEN
    end
    local bld = dfhack.buildings.findAtTile(pos)
    local job = get_first_job(bld)
    if not job then return end
    local jt = job.job_type
    if jt == df.job_type.DestroyBuilding
            or jt == df.job_type.RemoveConstruction then
        return DESTROYING_PEN
    end
end

function MassRemove:onRenderFrame(dc, rect)
    MassRemove.super.onRenderFrame(self, dc, rect)

    if not dfhack.screen.inGraphicsMode() and not gui.blink_visible(500) then
        return
    end

    local bounds = get_bounds(self.mark)
    local bounds_rect = gui.ViewRect{rect=bounds}
    self:refresh_grid()

    local function get_overlay_pen(pos)
        local job_pen = get_job_pen(pos)
        if job_pen then return job_pen end
        if bounds and bounds_rect:inClipGlobalXY(pos.x, pos.y) then
            return SELECTION_PEN
        end
    end

    guidm.renderMapOverlay(get_overlay_pen)
end

function MassRemove:commit(bounds)
    local bld_fn = self.subviews.buildings:getOptionValue()
    local constr_fn = self.subviews.constructions:getOptionValue()
    local stockpile_fn = self.subviews.stockpiles:getOptionValue()
    local zones_fn = self.subviews.zones:getOptionValue()

    for z=bounds.z1,bounds.z2 do
        for y=bounds.y1,bounds.y2 do
            for x=bounds.x1,bounds.x2 do
                local pos = xyz2pos(x, y, z)
                local bld = dfhack.buildings.findAtTile(pos)
                if bld then
                    if bld:getType() == df.building_type.Stockpile then
                        stockpile_fn(bld)
                    elseif bld:getType() == df.building_type.Construction then
                        constr_fn(pos, bld)
                    else
                        bld_fn(bld)
                    end
                end
                if not dfhack.buildings.findAtTile(pos) and is_construction(pos) then
                    constr_fn(pos)
                end
                zones_fn(pos)
            end
        end
    end
end

--
-- MassRemoveScreen
--

MassRemoveScreen = defclass(MassRemoveScreen, gui.ZScreen)
MassRemoveScreen.ATTRS {
    focus_path='mass-remove',
    pass_movement_keys=true,
    pass_mouse_clicks=false,
}

function MassRemoveScreen:init()
    self:addviews{MassRemove{}}
end

function MassRemoveScreen:onDismiss()
    view = nil
end

if dfhack_flags.module then
    return
end

if not dfhack.isMapLoaded() then
    qerror('This script requires a fortress map to be loaded')
end

view = view and view:raise() or MassRemoveScreen{}:show()
