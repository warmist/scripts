-- The DFHack in-game launcher
--@module=true

local gui = require('gui')
local helpdb = require('helpdb')
local widgets = require('gui.widgets')

AUTOCOMPLETE_PANEL_WIDTH = 20
EDIT_PANEL_HEIGHT = 4
EDIT_PANEL_ON_TOP = true

----------------------------------
-- AutocompletePanel
--
AutocompletePanel = defclass(AutocompletePanel, widgets.Panel)

function AutocompletePanel:init()
    self:addviews{
        widgets.List{
            view_id='autocomplete_list',
            frame={l=0, t=0}}
    }
end

function AutocompletePanel:computeFrame(parent_rect)
    local list = self.subviews.autocomplete_list
    self.saved_selected = list.selected
    self.saved_page_top = list.page_top
    return gui.mkdims_wh(
        parent_rect.width - AUTOCOMPLETE_PANEL_WIDTH,
        1,
        AUTOCOMPLETE_PANEL_WIDTH,
        parent_rect.height - 2)
end

function AutocompletePanel:postUpdateLayout()
    -- ensure the list display stays stable during resize events
    local list = self.subviews.autocomplete_list
    list.selected = self.saved_selected
    list.page_top = self.saved_page_top
end

function AutocompletePanel:advance(delta)
    local list = self.subviews.autocomplete_list
    list:moveCursor(delta)
    local idx, option = list:getSelected()
    return option and option.text or nil
end

function AutocompletePanel:set_options(options, initially_selected)
    local list = self.subviews.autocomplete_list
    list:setChoices(options, 1)
    if not initially_selected then
        -- don't highlight any row, and select the first row on next advance
        list.selected = 0
    end
end

function AutocompletePanel:ensure_selection()
    local list = self.subviews.autocomplete_list
    if list.selected == 0 then
        list:setSelected(1)
    end
end


----------------------------------
-- EditPanel
--
EditPanel = defclass(EditPanel, widgets.Panel)
EditPanel.ATTRS{
    on_change=DEFAULT_NIL,
    on_tab=DEFAULT_NIL,
    on_tab2=DEFAULT_NIL,
    on_submit=DEFAULT_NIL,
    on_submit2=DEFAULT_NIL
}

function EditPanel:init()
    self.stack = {}

    self:addviews{
        widgets.EditField{
            view_id='editfield',
            frame={l=1, t=1},
            on_change=self.on_change,
            on_submit=self.on_submit},
        widgets.HotkeyLabel{
            frame={l=1, t=3},
            key='CHANGETAB',
            key_sep='/',
            label='',
            on_activate=self.on_tab},
        widgets.HotkeyLabel{
            frame={l=5, t=3},
            key='SEC_CHANGETAB',
            label='Autocomplete',
            on_activate=self.on_tab2},
        widgets.HotkeyLabel{
            frame={l=30, t=3},
            key='SELECT',
            key_sep='/',
            label=''},
        widgets.HotkeyLabel{
            frame={l=36, t=3},
            key='SEC_SELECT',
            label='Run',
            on_activate=function()
                self.on_submit2(self.subviews.editfield.text) end},
    }
end

-- set the edit field text and save the current text in the stackin case the
-- user wants it back
function EditPanel:push_text(text)
    local editfield = self.subviews.editfield
    table.insert(self.stack, editfield.text)
    editfield.text = text
end

function EditPanel:pop_text()
    local editfield = self.subviews.editfield
    local text = self.stack[#self.stack]
    self.stack[#self.stack] = nil
    editfield.text = text
end

function EditPanel:computeFrame(parent_rect)
    local y1 = EDIT_PANEL_ON_TOP and 0 or (parent_rect.height - EDIT_PANEL_HEIGHT)
    return gui.mkdims_wh(
        0,
        y1,
        parent_rect.width - (AUTOCOMPLETE_PANEL_WIDTH + 2),
        EDIT_PANEL_HEIGHT)
end

----------------------------------
-- HelpPanel
--
HelpPanel = defclass(HelpPanel, widgets.Panel)

function HelpPanel:init()
    self.cur_entry = ""

    self:addviews{
        widgets.WrappedLabel{
            view_id='help_label',
            frame={l=0, t=0},
            auto_height=false,
            text_to_wrap='Welcome to DFHack!'}
    }
end

function HelpPanel:set_help(help_text)
    local label = self.subviews.help_label
    label.text_to_wrap = help_text
    label:postComputeFrame()
    label:updateLayout() -- to update the scroll arrows after rewrapping text
end

function HelpPanel:set_entry(entry_name)
    if not helpdb.is_entry(entry_name) then
        entry_name = ""
    end
    if #entry_name == 0 or entry_name == self.cur_entry then
        return
    end
    self.cur_entry = entry_name
    self:set_help(helpdb.get_entry_long_help(entry_name))
end

function HelpPanel:computeFrame(parent_rect)
    local y1 = not EDIT_PANEL_ON_TOP and 1 or (EDIT_PANEL_HEIGHT + 2)
    return gui.mkdims_wh(
        1,
        y1,
        parent_rect.width - (AUTOCOMPLETE_PANEL_WIDTH + 4),
        parent_rect.height - (EDIT_PANEL_HEIGHT + 2))
end

----------------------------------
-- LauncherUI
--
LauncherUI = defclass(LauncherUI, gui.FramedScreen)
LauncherUI.ATTRS{
    frame_title='DFHack Launcher',
    frame_style = gui.GREY_LINE_FRAME,
    focus_path='launcher',
}

function LauncherUI:init()
    self.firstword = ""

    self:addviews{
        AutocompletePanel{
            view_id='autocomplete',
            active=false},
        EditPanel{
            view_id='edit',
            on_change=self:callback('on_edit_input'),
            on_tab=self:callback('next_autocomplete'),
            on_tab2=self:callback('prev_autocomplete'),
            on_submit=self:callback('run_command', true),
            on_submit2=self:callback('run_command', false)},
        HelpPanel{
            view_id='help'},
    }
end

local function get_first_word(text)
    return text:trim():split(' +')[1]
end

function LauncherUI:update_help(text, firstword)
    local firstword = firstword or get_first_word(text)
    if firstword == self.firstword then
        return
    end
    self.firstword = firstword
    self.subviews.help:set_entry(firstword)
end

function LauncherUI:update_autocomplete(text, firstword)
    local entries = helpdb.search_entries(
        {str=firstword},
        {str={'modtools/', 'devel/'}})
    local found = false
    for i,v in ipairs(entries) do
        if v == firstword then
            -- if firstword is in the list, move that item to the top
            table.remove(entries, i)
            table.insert(entries, 1, v)
            found = true
            break
        end
    end
    self.subviews.autocomplete:set_options(entries, found)
end

function LauncherUI:on_edit_input(text)
    local firstword = get_first_word(text)
    self:update_help(text, firstword)
    self:update_autocomplete(text, firstword)
end

function LauncherUI:next_autocomplete()
    local text = self.subviews.autocomplete:advance(1)
    if text then
        self.subviews.edit:push_text(text)
        self:update_help(text)
    end
end

function LauncherUI:prev_autocomplete()
    local autocomplete = self.subviews.autocomplete
    autocomplete:ensure_selection()
    local text = autocomplete:advance(-1)
    if text then
        self.subviews.edit:push_text(text)
        self:update_help(text)
    end
end

local function launch(initial_help)
    view = LauncherUI{}
    view:show()
    view:on_edit_input('')
    if initial_help then
        view.subviews.help:set_help(initial_help)
    end
end

function LauncherUI:onDismiss()
    view = nil
end

function LauncherUI:run_command(reappear, text)
    self:dismiss()
    local output = dfhack.run_command_silent(text)
    -- if we launched a new screen, don't come back up, even if reappear is true
    if not reappear or dfhack.gui.getCurFocus(true):startswith('dfhack/') then
        return
    end
    -- reappear and show the command output
    local initial_help = ('> %s\n\n%s'):format(text, output)
    launch(initial_help)
end

function LauncherUI:getWantedFrameSize()
    local width, height = dfhack.screen.getWindowSize()
    return math.max(76, width-10), math.max(24, height-10)
end

local H_SPLIT_PEN = dfhack.pen.parse{ch=205, fg=COLOR_GREY, bg=COLOR_BLACK}
local V_SPLIT_PEN = dfhack.pen.parse{ch=186, fg=COLOR_GREY, bg=COLOR_BLACK}
local TOP_SPLIT_PEN = dfhack.pen.parse{ch=203, fg=COLOR_GREY, bg=COLOR_BLACK}
local BOTTOM_SPLIT_PEN = dfhack.pen.parse{ch=202, fg=COLOR_GREY, bg=COLOR_BLACK}
local LEFT_SPLIT_PEN = dfhack.pen.parse{ch=204, fg=COLOR_GREY, bg=COLOR_BLACK}
local RIGHT_SPLIT_PEN = dfhack.pen.parse{ch=185, fg=COLOR_GREY, bg=COLOR_BLACK}

-- paint autocomplete panel border
local function paint_vertical_border(rect)
    local x = rect.x2 - (AUTOCOMPLETE_PANEL_WIDTH + 2)
    local y1, y2 = rect.y1, rect.y2
    dfhack.screen.paintTile(TOP_SPLIT_PEN, x, y1)
    dfhack.screen.paintTile(BOTTOM_SPLIT_PEN, x, y2)
    for y=y1+1,y2-1 do
        dfhack.screen.paintTile(V_SPLIT_PEN, x, y)
    end
end

-- paint border between edit area and help area
local function paint_horizontal_border(rect)
    local panel_height = EDIT_PANEL_HEIGHT + 1
    local x1, x2 = rect.x1, rect.x2
    local v_border_x = x2 - (AUTOCOMPLETE_PANEL_WIDTH + 2)
    local y = EDIT_PANEL_ON_TOP and
            (rect.y1 + panel_height) or (rect.y2 - panel_height)
    dfhack.screen.paintTile(LEFT_SPLIT_PEN, x1, y)
    dfhack.screen.paintTile(RIGHT_SPLIT_PEN, v_border_x, y)
    for x=x1+1,v_border_x-1 do
        dfhack.screen.paintTile(H_SPLIT_PEN, x, y)
    end
end

function LauncherUI:onRenderFrame(dc, rect)
    LauncherUI.super.onRenderFrame(self, dc, rect)
    paint_vertical_border(rect)
    paint_horizontal_border(rect)
end

function LauncherUI:onInput(keys)
    if keys.LEAVESCREEN then
        self:dismiss()
        return true
    end

    return self:inputToSubviews(keys)
end

if dfhack_flags.module then
    return
end

if not view then
    launch()
end
