-- migrate configuration from 50.11-r4 and prior to new format
--@module = true

-- init files
local SYSTEM_INIT_FILE = 'dfhack-config/init/dfhack.control-panel-system.init'
local PREFERENCES_INIT_FILE = 'dfhack-config/init/dfhack.control-panel-preferences.init'
local AUTOSTART_FILE = 'dfhack-config/init/onMapLoad.control-panel-new-fort.init'
local REPEATS_FILE = 'dfhack-config/init/onMapLoad.control-panel-repeats.init'

local function save_tombstone_file(path)
    local ok, f = pcall(io.open, path, 'w')
    if not ok or not f then
        dialogs.showMessage('Error',
            ('Cannot open file for writing: "%s"'):format(path))
        return
    end
    f:write('# This file was once used by gui/control-panel\n')
    f:write('# If you are on Steam, you can delete this file manually\n')
    f:write('# by starting DFHack in the Steam client, then deleting\n')
    f:write('# this file while DF is running. Otherwise Steam Cloud will\n')
    f:write('# restore the file when you next run DFHack.\n')
    f:write('#\n')
    f:write('# If you\'re not on Steam, you can delete this file at any time.\n')
    f:close()
end
--[[
function SystemServices:on_submit()
    SystemServices.super.on_submit(self)

    local enabled_map = self:get_enabled_map()
    local save_fn = function(f)
        for _,service in ipairs(SYSTEM_USER_SERVICES) do
            if enabled_map[service] then
                f:write(('enable %s\n'):format(service))
            end
        end
    end
    save_file(SYSTEM_INIT_FILE, save_fn)
end

function FortServicesAutostart:on_submit()
    _,choice = self.subviews.list:getSelected()
    if not choice then return end
    self.enabled_map[choice.target] = not choice.enabled

    local save_fn = function(f)
        for service,enabled in pairs(self.enabled_map) do
            if enabled then
                if service:match(' ') then
                    f:write(('on-new-fortress %s\n'):format(service))
                else
                    f:write(('on-new-fortress enable %s\n'):format(service))
                end
            end
        end
    end
    save_file(AUTOSTART_FILE, save_fn)
    self:refresh()
end

function FortServicesAutostart:init()
    local enabled_map = {}
    local ok, f = pcall(io.open, AUTOSTART_FILE)
    if ok and f then
        local services_set = utils.invert(FORT_AUTOSTART)
        for line in f:lines() do
            line = line:trim()
            if #line == 0 or line:startswith('#') then goto continue end
            local service = line:match('^on%-new%-fortress enable ([%S]+)$')
                    or line:match('^on%-new%-fortress (.+)')
            if service and services_set[service] then
                enabled_map[service] = true
            end
            ::continue::
        end
    end
    self.enabled_map = enabled_map
end

function Preferences:do_save()
    local save_fn = function(f)
        for ctx_name,settings in pairs(PREFERENCES) do
            local ctx_env = require(ctx_name)
            for id in pairs(settings) do
                f:write((':lua require("%s").%s=%s\n'):format(
                        ctx_name, id, tostring(ctx_env[id])))
            end
        end
        for _,spec in ipairs(CPP_PREFERENCES) do
            local line = spec.init_fmt:format(spec.get_fn())
            f:write(('%s\n'):format(line))
        end
    end
    save_file(PREFERENCES_INIT_FILE, save_fn)
end

function RepeatAutostart:init()
    self.subviews.show_help_label.visible = false
    self.subviews.launch.visible = false
    local enabled_map = {}
    local ok, f = pcall(io.open, REPEATS_FILE)
    if ok and f then
        for line in f:lines() do
            line = line:trim()
            if #line == 0 or line:startswith('#') then goto continue end
            local service = line:match('^repeat %-%-name ([%S]+)')
            if service then
                enabled_map[service] = true
            end
            ::continue::
        end
    end
    self.enabled_map = enabled_map
end

function RepeatAutostart:on_submit()
    _,choice = self.subviews.list:getSelected()
    if not choice then return end
    self.enabled_map[choice.name] = not choice.enabled
    local run_commands = dfhack.isMapLoaded()

    local save_fn = function(f)
        for name,enabled in pairs(self.enabled_map) do
            if enabled then
                local command_str = ('repeat --name %s %s\n'):
                        format(name, table.concat(REPEATS[name].command, ' '))
                f:write(command_str)
                if run_commands then
                    dfhack.run_command(command_str) -- actually start it up too
                end
            elseif run_commands then
                repeatUtil.cancel(name)
            end
        end
    end
    save_file(REPEATS_FILE, save_fn)
    self:refresh()
end
]]
function migrate(config_data)
    -- read old files, add converted data to config_data, overwrite old files with
    -- a message that says they are deprecated and can be deleted with the proper procedure
    -- we can't delete them outright since steam may just restore them due to Steam Cloud
    -- we *could* delete them if we know that we've been started from Steam as DFHack and not as DF
end
