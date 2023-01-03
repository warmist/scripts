local gui = require('gui')
local widgets = require('gui.widgets')

TileBrowser = defclass(TileBrowser, gui.Screen)

function TileBrowser:init()
    self.max_texpos = #df.global.enabler.textures.raws

    local main_panel = widgets.Window{
        view_id='window',
        frame={w=36, h=59},
        drag_anchors={title=true, body=true},
        resizable=true,
        resize_min={h=20},
        frame_title='Tile Browser',
    }
    main_panel:addviews{
        widgets.EditField{
            view_id='start_index',
            frame={t=0, l=0},
            key='CUSTOM_CTRL_A',
            label_text='Start index: ',
            text='0',
            on_submit=self:callback('set_start_index'),
            on_char=function(ch) return ch:match('%d') end},
        widgets.HotkeyLabel{
            frame={t=1, l=0},
            label='Prev',
            key='KEYBOARD_CURSOR_UP_FAST',
            on_activate=self:callback('shift_start_index', -1000)},
        widgets.Label{
            frame={t=1, l=6, w=1},
            text={{text=string.char(24), pen=COLOR_LIGHTGREEN}}},
        widgets.HotkeyLabel{
            frame={t=1, l=15},
            label='Next',
            key='KEYBOARD_CURSOR_DOWN_FAST',
            on_activate=self:callback('shift_start_index', 1000)},
        widgets.Label{
            frame={t=1, l=21, w=1},
            text={{text=string.char(25), pen=COLOR_LIGHTGREEN}}},
        widgets.Label{
            view_id='header',
            frame={t=3}},
        widgets.Label{
            view_id='report',
            frame={t=4, b=1},
            scroll_keys={
                STANDARDSCROLL_UP = -1,
                KEYBOARD_CURSOR_UP = -1,
                STANDARDSCROLL_DOWN = 1,
                KEYBOARD_CURSOR_DOWN = 1,
                STANDARDSCROLL_PAGEUP = '-page',
                STANDARDSCROLL_PAGEDOWN = '+page',
            }},
        widgets.Label{
            view_id='footer',
            frame={b=0}},
    }
    self:addviews{main_panel}

    self:set_start_index('0')
end

function TileBrowser:shift_start_index(amt)
    self:set_start_index(tonumber(self.subviews.start_index.text) + amt)
end

function TileBrowser:set_start_index(idx)
    idx = tonumber(idx)
    if not idx then return end

    idx = math.max(0, math.min(self.max_texpos - 980, idx))

    idx = idx - (idx % 20) -- floor to nearest multiple of 20
    self.subviews.start_index:setText(tostring(idx))
    self.dirty = true
end

function TileBrowser:update_report()
    if not self.dirty then return end

    local idx = tonumber(self.subviews.start_index.text)
    local end_idx = math.min(self.max_texpos, idx + 999)
    local prefix_len = #tostring(idx) + 4

    local guide = {}
    table.insert(guide, {text='', width=prefix_len})
    table.insert(guide, '0123456789 0123456789')
    self.subviews.header:setText(guide)
    self.subviews.footer:setText(guide)

    local report = {}
    for texpos=idx,end_idx do
        if texpos % 20 == 0 then
            table.insert(report, {text=tostring(texpos), width=prefix_len})
        elseif texpos % 10 == 0 then
            table.insert(report, ' ')
        end
        table.insert(report, {tile=texpos})
        if (texpos+1) % 20 == 0 then
            table.insert(report, NEWLINE)
        end
    end

    self.subviews.report:setText(report)
    self.subviews.window:updateLayout()
end

function TileBrowser:onRenderFrame()
    self:renderParent()
    self:update_report()
end

function TileBrowser:onInput(keys)
    if keys.LEAVESCREEN then
        self:dismiss()
        return true
    end
    return self.super.onInput(self, keys)
end

function TileBrowser:onDismiss()
    view = nil
end

view = view or TileBrowser{}:show()
