-- Simple modlist manager
--@ module = true

local argparse = require('argparse')
local overlay = require('plugins.overlay')
local gui = require('gui')
local widgets = require('gui.widgets')
local repeatutil = require('repeat-util')
local dialogs = require('gui.dialogs')
local json = require('json')
local utils = require('utils')

local presets_file = json.open("dfhack-config/modpresets.json")
local GLOBAL_KEY = 'modlistloader'

local function get_newregion_viewscreen()
    local vs = dfhack.gui.getViewscreenByType(df.viewscreen_new_regionst, 0)
    return vs
end

local function get_modlist_fields(kind, viewscreen)
    if kind == "available" then
        return {
            id = viewscreen.available_id,
            numeric_version = viewscreen.available_numeric_version,
            earliest_compat_numeric_version = viewscreen.available_earliest_compat_numeric_version,
            src_dir = viewscreen.available_src_dir,
            name = viewscreen.available_name,
            displayed_version = viewscreen.available_displayed_version,
            mod_header = viewscreen.available_mod_header,
        }
    elseif kind == "base_available" then
        return {
            id = viewscreen.base_available_id,
            numeric_version = viewscreen.base_available_numeric_version,
            earliest_compat_numeric_version = viewscreen.base_available_earliest_compat_numeric_version,
            src_dir = viewscreen.base_available_src_dir,
            name = viewscreen.base_available_name,
            displayed_version = viewscreen.base_available_displayed_version,
            mod_header = viewscreen.base_available_mod_header,
        }
    elseif kind == "object_load_order" then
        return {
            id = viewscreen.object_load_order_id,
            numeric_version = viewscreen.object_load_order_numeric_version,
            earliest_compat_numeric_version = viewscreen.object_load_order_earliest_compat_numeric_version,
            src_dir = viewscreen.object_load_order_src_dir,
            name = viewscreen.object_load_order_name,
            displayed_version = viewscreen.object_load_order_displayed_version,
            mod_header = viewscreen.object_load_order_mod_header,
        }
    else
        error("Invalid kind: " .. kind)
    end
end

local function move_mod_entry(viewscreen, to, from, mod_id, mod_version)
    local to_fields = get_modlist_fields(to, viewscreen)
    local from_fields = get_modlist_fields(from, viewscreen)

    local mod_index = nil
    for i, v in ipairs(from_fields.id) do
        local version = from_fields.numeric_version[i]
        if v.value == mod_id and version == mod_version then
            mod_index = i
            break
        end
    end

    if mod_index == nil then
        return false
    end

    for k, v in pairs(to_fields) do
        if type(from_fields[k][mod_index]) == "userdata" then
            v:insert('#', from_fields[k][mod_index]:new())
        else
            v:insert('#', from_fields[k][mod_index])
        end
    end

    for k, v in pairs(from_fields) do
        v:erase(mod_index)
    end

    return true
end

local function enable_mod(viewscreen, mod_id, mod_version)
    return move_mod_entry(viewscreen, "object_load_order", "available", mod_id, mod_version)
end

local function disable_mod(viewscreen, mod_id, mod_version)
    return move_mod_entry(viewscreen, "available", "object_load_order", mod_id, mod_version)
end

local function get_active_modlist(viewscreen)
    local t = {}
    local fields = get_modlist_fields("object_load_order", viewscreen)
    for i, v in ipairs(fields.id) do
        local version = fields.numeric_version[i]
        table.insert(t, { version = version, id = v.value })
    end
    return t
end

local function swap_modlist(viewscreen, modlist)
    local current = get_active_modlist(viewscreen)
    for _, v in ipairs(current) do
        disable_mod(viewscreen, v.id, v.version)
    end

    local failures = {}
    for _, v in ipairs(modlist) do
        if not enable_mod(viewscreen, v.id, v.version) then
            table.insert(failures, v.id)
        end
    end
    return failures
end

local function is_modlist_visible()
    -- local viewscreen = dfhack.gui.getCurViewscreen()
    -- if viewscreen._type == df.viewscreen_new_regionst then
    --     if viewscreen.doing_mods then
    --         return true
    --     end
    -- end
    -- return false

    local vs = get_newregion_viewscreen()
    if vs and vs.doing_mods then
        return true
    end
end

ModmanageMenu = defclass(ModmanageMenu, widgets.Window)
ModmanageMenu.ATTRS {
    view_id = "modman_menu",
    frame_title = "Modlist Manager",
    frame_style = gui.WINDOW_FRAME,
    frame_inset=0,

    frame = { w = 40, t = 10, b = 15 },

    resizable = true,
    autoarrange_subviews=false,
}

local function save_new_preset(preset_name)
    local viewscreen = get_newregion_viewscreen()
    local modlist = get_active_modlist(viewscreen)
    table.insert(presets_file.data, { name = preset_name, modlist = modlist })
    presets_file:write()
end

local function remove_preset(idx)
    if idx > #presets_file.data then
        return
    end

    table.remove(presets_file.data, idx)
    presets_file:write()
end

local function overwrite_preset(idx)
    if idx > #presets_file.data then
        return
    end

    local viewscreen = get_newregion_viewscreen()
    local modlist = get_active_modlist(viewscreen)
    presets_file.data[idx].modlist = modlist
    presets_file:write()
end

local function load_preset(idx)
    if idx > #presets_file.data then
        return
    end

    local viewscreen = get_newregion_viewscreen()
    local modlist = presets_file.data[idx].modlist
    local failures = swap_modlist(viewscreen, modlist)

    if #failures > 0 then
        local failures_str = ""
        for _, v in ipairs(failures) do
            failures_str = failures_str .. v .. "\n"
        end
        dialogs.showMessage("Warning", "Failed to load some mods", COLOR_LIGHTRED)
    end
end

local function find_preset_by_name(name)
    for i, v in ipairs(presets_file.data) do
        if v.name == name then
            return i
        end
    end
end

local function rename_preset(idx, new_name)
    if idx > #presets_file.data then
        return
    end

    presets_file.data[idx].name = new_name
    presets_file:write()
end

local function toggle_default(idx)
    if idx > #presets_file.data then
        return
    end

    if presets_file.data[idx].default then
        presets_file.data[idx].default = false
        presets_file:write()
    else
        for i, v in ipairs(presets_file.data) do
            v.default = false
        end
        presets_file.data[idx].default = true
        presets_file:write()
    end
end

function ModmanageMenu:init()
    local presetList

    local function refresh_list()
        presets_file:read()
        local presets = utils.clone(presets_file.data, true)
        local default_set = false
        for _, v in ipairs(presets) do
            v.text = v.name

            if v.default and not default_set then
                v.text = v.text .. " (default)"
                default_set = true
            end
        end

        presetList:setChoices(presets)
    end

    presetList = widgets.List {
        frame = { l =1, r = 1, t = 1, b = 5 },
        on_double_click = function(idx, current)
            load_preset(idx)
        end,
    }

    refresh_list()

    self:addviews{
        presetList,

        widgets.HotkeyLabel{
            frame = { l = 1, b = 1, w = 15 },
            key = "CUSTOM_S",
            label = "Save current",
            on_activate = function()
                dialogs.showInputPrompt("Enter preset name", nil, nil, "", function(t)
                    local existing_idx = find_preset_by_name(t)
                    if existing_idx then
                        dialogs.showYesNoPrompt(
                            "Confirmation",
                            "Overwrite " .. t .. "?",
                            nil,
                            function()
                                overwrite_preset(existing_idx)
                                refresh_list()
                            end
                        )

                        return
                    else
                        save_new_preset(t)
                        refresh_list()
                    end
                end)
            end,
        },

        widgets.HotkeyLabel{
            frame = { l = 17, b = 1, w = 15 },
            key = "CUSTOM_R",
            label = "Rename",
            on_activate = function()
                local idx, current = presetList:getSelected()

                if not idx then
                    return
                end

                dialogs.showInputPrompt("Enter new name", nil, nil, current.name, function(t)
                    local existing_idx = find_preset_by_name(t)

                    if existing_idx then
                        if existing_idx == idx then
                            return
                        end

                        dialogs.showYesNoPrompt(
                            "Confirmation",
                            "Overwrite " .. t .. "?",
                            nil,
                            function()
                                remove_preset(existing_idx)
                                rename_preset(idx, t)
                                refresh_list()
                            end
                        )
                    else
                        rename_preset(idx, t)
                        refresh_list()
                    end
                end)
            end,
        },

        widgets.HotkeyLabel{
            frame = { l = 1, b = 2, w = 15 },
            key = "SELECT",
            label = "Load",
            on_activate = function()
                local idx, current = presetList:getSelected()

                if not idx then
                    return
                end

                load_preset(idx)
            end,
        },

        widgets.HotkeyLabel{
            frame = { l = 17, b = 2, w = 15 },
            key = "CUSTOM_D",
            label = "Delete",
            on_activate = function()
                local idx, current = presetList:getSelected()

                if not idx then
                    return
                end

                dialogs.showYesNoPrompt(
                    "Confirmation",
                    "Delete " .. current.text .. "?",
                    nil,
                    function()
                        remove_preset(idx)
                        refresh_list()
                    end
                )
            end,
        },

        widgets.HotkeyLabel{
            frame = { l = 1, b = 0, w = 20 },
            key = "CUSTOM_Q",
            label = "Set as default",
            on_activate = function()
                local idx, current = presetList:getSelected()

                if not idx then
                    return
                end

                toggle_default(idx)
                refresh_list()
            end
        },
    }
end

ModmanageScreen = defclass(ModmanageScreen, gui.ZScreen)
ModmanageScreen.ATTRS {
    focus_path = "modman_screen",
    defocusable = false,
}

function ModmanageScreen:init()
    self:addviews{
        ModmanageMenu{}
    }
end

ModmanageOverlay = defclass(ModmanageOverlay, overlay.OverlayWidget)
ModmanageOverlay.ATTRS {
    frame = { w=30, h=1 },
    default_pos = {x=5, y=-5},
    viewscreens = {"new_region"},
    default_enabled=true,
    overlay_only=true,
    hotspot=true,
    overlay_onupdate_max_freq_seconds=0,
}

function ModmanageOverlay:init()
    self:addviews{
        widgets.HotkeyLabel{
            frame = {l=0, t=0, w = 20, h = 1},
            key = "CUSTOM_M",
            view_id = "modman_open",
            label = "Mod Manager",
            on_activate = function()
                ModmanageScreen{}:show()
            end,
        },
    }
end

function ModmanageOverlay:overlay_onupdate(viewscreen)
    self.visible = is_modlist_visible()

    for k, v in pairs(self.subviews) do
        v.visible = self.visible
    end
end

OVERLAY_WIDGETS = {
    button = ModmanageOverlay,
}

local default_applied = false

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_VIEWSCREEN_CHANGED then
        local vs = get_newregion_viewscreen()
        if vs and not default_applied then
            default_applied = true
            for i, v in ipairs(presets_file.data) do
                if v.default then
                    load_preset(i)
                    break
                end
            end
        elseif not vs then
            default_applied = false
        end
    end
end
