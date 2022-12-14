-- overlay plugin gui config
--@ module = true

local gui = require('gui')
local guidm = require('gui.dwarfmode')
local widgets = require('gui.widgets')

local overlay = require('plugins.overlay')

local DIALOG_WIDTH = 59
local LIST_HEIGHT = 14

local SHADOW_FRAME = copyall(gui.GREY_LINE_FRAME)
SHADOW_FRAME.signature_pen = false

local HIGHLIGHT_FRAME = copyall(SHADOW_FRAME)
HIGHLIGHT_FRAME.h_frame_pen = dfhack.pen.parse{ch=205, fg=COLOR_GREEN, bg=COLOR_BLACK}
HIGHLIGHT_FRAME.v_frame_pen = dfhack.pen.parse{ch=186, fg=COLOR_GREEN, bg=COLOR_BLACK}
HIGHLIGHT_FRAME.lt_frame_pen = dfhack.pen.parse{ch=201, fg=COLOR_GREEN, bg=COLOR_BLACK}
HIGHLIGHT_FRAME.lb_frame_pen = dfhack.pen.parse{ch=200, fg=COLOR_GREEN, bg=COLOR_BLACK}
HIGHLIGHT_FRAME.rt_frame_pen = dfhack.pen.parse{ch=187, fg=COLOR_GREEN, bg=COLOR_BLACK}
HIGHLIGHT_FRAME.rb_frame_pen = dfhack.pen.parse{ch=188, fg=COLOR_GREEN, bg=COLOR_BLACK}

local function make_highlight_frame_style(frame)
    local frame_style = copyall(HIGHLIGHT_FRAME)
    local fg, bg = COLOR_GREEN, COLOR_LIGHTGREEN
    if frame.t then
        frame_style.t_frame_pen = dfhack.pen.parse{ch=205, fg=fg, bg=bg}
    elseif frame.b then
        frame_style.b_frame_pen = dfhack.pen.parse{ch=205, fg=fg, bg=bg}
    end
    if frame.l then
        frame_style.l_frame_pen = dfhack.pen.parse{ch=186, fg=fg, bg=bg}
    elseif frame.r then
        frame_style.r_frame_pen = dfhack.pen.parse{ch=186, fg=fg, bg=bg}
    end
    return frame_style
end

--------------------
-- DraggablePanel --
--------------------

DraggablePanel = defclass(DraggablePanel, widgets.Panel)
DraggablePanel.ATTRS{
    on_click=DEFAULT_NIL,
    name=DEFAULT_NIL,
    draggable=true,
    drag_anchors={frame=true, body=true},
    drag_bound='body',
}

function DraggablePanel:onInput(keys)
    if keys._MOUSE_L_DOWN then
        local rect = self.frame_rect
        local x,y = self:getMousePos(gui.ViewRect{rect=rect})
        if x then
            self.on_click()
        end
    end
    return DraggablePanel.super.onInput(self, keys)
end

function DraggablePanel:postUpdateLayout()
    local frame = self.frame
    local matcher = {t=not not frame.t, b=not not frame.b,
                     l=not not frame.l, r=not not frame.r}
    local parent_rect, frame_rect = self.frame_parent_rect, self.frame_rect
    if frame_rect.y1 <= parent_rect.y1 then
        frame.t, frame.b = frame_rect.y1-parent_rect.y1, nil
    elseif frame_rect.y2 >= parent_rect.y2 then
        frame.t, frame.b = nil, parent_rect.y2-frame_rect.y2
    end
    if frame_rect.x1 <= parent_rect.x1 then
        frame.l, frame.r = frame_rect.x1-parent_rect.x1, nil
    elseif frame_rect.x2 >= parent_rect.x2 then
        frame.l, frame.r = nil, parent_rect.x2-frame_rect.x2
    end
    self.frame_style = make_highlight_frame_style(self.frame)
    if not not frame.t ~= matcher.t or not not frame.b ~= matcher.b
            or not not frame.l ~= matcher.l or not not frame.r ~= matcher.r then
        -- we've changed edge affinity, recalculate our frame
        self:updateLayout()
    end
end

function DraggablePanel:onRenderFrame(dc, rect)
    if self:getMousePos(gui.ViewRect{rect=self.frame_rect}) then
        self.frame_background = dfhack.pen.parse{
                ch=32, fg=COLOR_LIGHTGREEN, bg=COLOR_LIGHTGREEN}
    else
        self.frame_background = nil
    end
    DraggablePanel.super.onRenderFrame(self, dc, rect)
end

-------------------
-- OverlayConfig --
-------------------

OverlayConfig = defclass(OverlayConfig, gui.Screen)

function OverlayConfig:init()
    -- prevent hotspot widgets from reacting
    overlay.register_trigger_lock_screen(self)

    self.scr_name = overlay.simplify_viewscreen_name(
            getmetatable(dfhack.gui.getCurViewscreen(true)))

    local main_panel = widgets.Panel{
        frame={w=DIALOG_WIDTH, h=LIST_HEIGHT+15},
        draggable=true,
        frame_style=gui.GREY_LINE_FRAME,
        frame_title='Overlay config',
        frame_background=gui.CLEAR_PEN,
        frame_inset=1,
        autoarrange_subviews=true,
        autoarrange_gap=1,
    }
    main_panel:addviews{
        widgets.Label{text={'Current screen: ',
                            {text=self.scr_name, pen=COLOR_CYAN}}},
        widgets.CycleHotkeyLabel{
            view_id='filter',
            key='CUSTOM_CTRL_A',
            label='Showing:',
            options={{label='overlays for the current screen',
                    value='cur'},
                    {label='all overlays', value='all'}},
            on_change=self:callback('refresh_list')},
        widgets.FilteredList{
            view_id='list',
            frame={h=LIST_HEIGHT},
            on_select=self:callback('highlight_selected'),
            on_submit=self:callback('toggle_enabled'),
            on_submit2=self:callback('reposition'),
        },
        widgets.ResizingPanel{
            autoarrange_subviews=true,
            subviews={
                widgets.HotkeyLabel{
                    key='SELECT',
                    key_sep=' or click widget name to enable/disable',
                    scroll_keys={},
                },
                widgets.HotkeyLabel{
                    key='SEC_SELECT',
                    key_sep=' or drag the on-screen widget to reposition ',
                    scroll_keys={},
                },
                widgets.HotkeyLabel{
                    key='CUSTOM_CTRL_D',
                    scroll_keys={},
                    label='reset selected widget to its default position',
                    on_activate=self:callback('reset'),
                },
            },
        },
        widgets.WrappedLabel{
            scroll_keys={},
            text_to_wrap='When repositioning a widget, touch an edge of the'..
                ' screen to anchor the widget to that edge.',
        },
    }
    self:addviews{main_panel}
    self:refresh_list()
end

local function make_highlight_frame(widget_frame)
    local frame = {h=widget_frame.h+2, w=widget_frame.w+2}
    if widget_frame.l then frame.l = widget_frame.l - 1
    else frame.r = widget_frame.r - 1 end
    if widget_frame.t then frame.t = widget_frame.t - 1
    else frame.b = widget_frame.b - 1 end
    return frame
end

function OverlayConfig:refresh_list(filter)
    local choices = {}
    local state = overlay.get_state()
    local list = self.subviews.list
    local make_on_click_fn = function(idx)
        return function() list.list:setSelected(idx) end
    end
    for _,name in ipairs(state.index) do
        local db_entry = state.db[name]
        local widget = db_entry.widget
        if not widget.hotspot and filter ~= 'all' then
            local matched = false
            for _,scr in ipairs(overlay.normalize_list(widget.viewscreens)) do
                if overlay.simplify_viewscreen_name(scr) == self.scr_name then
                    matched = true
                    break
                end
            end
            if not matched then goto continue end
        end
        local panel = nil
        if not widget.overlay_only then
            panel = DraggablePanel{
                    frame=make_highlight_frame(widget.frame),
                    frame_style=SHADOW_FRAME,
                    on_click=make_on_click_fn(#choices+1),
                    name=name}
            panel.on_drag_end = function(success)
                if (success) then
                    local frame = panel.frame
                    local posx = frame.l and tostring(frame.l+2)
                            or tostring(-(frame.r+2))
                    local posy = frame.t and tostring(frame.t+2)
                            or tostring(-(frame.b+2))
                    overlay.overlay_command({'position', name, posx, posy},true)
                end
                self.reposition_panel = nil
            end
        end
        local cfg = state.config[name]
        local tokens = {}
        table.insert(tokens, '[')
        table.insert(tokens, {
                pen=cfg.enabled and COLOR_LIGHTGREEN or COLOR_YELLOW,
                text=cfg.enabled and 'enabled' or 'disabled'})
        table.insert(tokens, (']%s '):format(cfg.enabled and ' ' or ''))
        table.insert(tokens, name)
        table.insert(tokens, {text=function()
                if self.reposition_panel and self.reposition_panel == panel then
                    return ' (repositioning with keyboard)'
                end
                return ''
            end})
        table.insert(choices,
                {text=tokens, enabled=cfg.enabled, name=name, panel=panel,
                 search_key=name})
        ::continue::
    end
    local old_filter = list:getFilter()
    list:setChoices(choices)
    list:setFilter(old_filter)
    if self.frame_parent_rect then
        self:postUpdateLayout()
    end
end

function OverlayConfig:highlight_selected(_, obj)
    if self.selected_panel then
        self.selected_panel.frame_style = SHADOW_FRAME
        self.selected_panel = nil
    end
    if self.reposition_panel then
        self.reposition_panel:setKeyboardDragEnabled(false)
        self.reposition_panel = nil
    end
    if not obj or not obj.panel then return end
    local panel = obj.panel
    panel.frame_style = make_highlight_frame_style(panel.frame)
    self.selected_panel = panel
end

function OverlayConfig:toggle_enabled(_, obj)
    local command = obj.enabled and 'disable' or 'enable'
    overlay.overlay_command({command, obj.name}, true)
    self:refresh_list(self.subviews.filter:getOptionValue())
end

function OverlayConfig:reposition(_, obj)
    self.reposition_panel = obj.panel
    if self.reposition_panel then
        self.reposition_panel:setKeyboardDragEnabled(true)
    end
end

function OverlayConfig:reset()
    local idx,obj = self.subviews.list:getSelected()
    if not obj or not obj.panel then return end
    overlay.overlay_command({'position', obj.panel.name, 'default'}, true)
    self:refresh_list(self.subviews.filter:getOptionValue())
end

function OverlayConfig:onDismiss()
    view = nil
end

function OverlayConfig:postUpdateLayout()
    for _,choice in ipairs(self.subviews.list:getChoices()) do
        if choice.panel then
            choice.panel:updateLayout(self.frame_parent_rect)
        end
    end
end

function OverlayConfig:onInput(keys)
    if self.reposition_panel then
        if self.reposition_panel:onInput(keys) then
            return true
        end
    end
    if keys.LEAVESCREEN then
        self:dismiss()
        return true
    end
    if self.selected_panel then
        if self.selected_panel:onInput(keys) then
            return true
        end
    end
    for _,choice in ipairs(self.subviews.list:getVisibleChoices()) do
        if choice.panel and choice.panel:onInput(keys) then
            return true
        end
    end
    return self:inputToSubviews(keys)
end

function OverlayConfig:onRenderFrame(dc, rect)
    self:renderParent()
    for _,choice in ipairs(self.subviews.list:getVisibleChoices()) do
        local panel = choice.panel
        if panel and panel ~= self.selected_panel then
            panel:render(dc)
        end
    end
    if self.selected_panel then
        self.render_selected_panel = function()
            self.selected_panel:render(dc)
        end
    else
        self.render_selected_panel = nil
    end
end

function OverlayConfig:renderSubviews(dc)
    OverlayConfig.super.renderSubviews(self, dc)
    if self.render_selected_panel then
        self.render_selected_panel()
    end
end

if dfhack_flags.module then
    return
end

view = view or OverlayConfig{}:show()
