--@module = true

local migration = reqscript('internal/control-panel/migration')
local registry = reqscript('internal/control-panel/registry')
local repeatUtil = require('repeat-util')

local CONFIG_FILE = 'dfhack-config/control-panel.json'

local function get_config()
    local f = json.open(CONFIG_FILE)
    local updated = false
    if f.exists then
        -- ensure proper structure
        ensure_key(f.data, 'commands')
        ensure_key(f.data, 'preferences')
        -- remove unknown or out of date entries from the loaded config
        for k, v in pairs(f.data) do
            if k ~= 'commands' and k ~= 'preferences' then
                updated = true
                f.data[k] = nil
            end
        end
        for name, config_command_data in pairs(f.data.commands) do
            local data = registry.COMMANDS_BY_NAME[name]
            if not data or config_command_data.version ~= data.version then
                updated = true
                f.data.commands[name] = nil
            end
        end
        for name, config_pref_data in pairs(f.data.preferences) do
            local data = registry.PREFERENCES_BY_NAME[name]
            if not data or config_pref_data.version ~= data.version then
                updated = true
                f.data.preferences[name] = nil
            end
        end
    else
        -- migrate any data from old configs
        migration.migrate(f.data)
        updated = next(f.data.commands) or next(f.data.preferences)
    end
    if updated then
        f:write()
    end
    return f
end

config = config or get_config()

function get_enabled_map()
    local enabled_map = {}
    local output = dfhack.run_command_silent('enable'):split('\n+')
    for _,line in ipairs(output) do
        local _,_,command,enabled_str = line:find('%s*(%S+):%s+(%S+)')
        if enabled_str then
            enabled_map[command] = enabled_str == 'on'
        end
    end
    -- repeat entries override tool names for control-panel
    for name in pairs(repeatUtil.repeating) do
        enabled_map[name] = true
    end
    return enabled_map
end

function apply(data, enabled_map, enabled)
    enabled_map = enabled_map or {}
    if enabled == nil then
        enabled = safe_index(config.data.commands, data.command, 'autostart')
        enabled = enabled or (enabled == nil and data.default)
        if not enabled then return end
    end
    if data.mode == 'enable' or data.mode == 'system_enable' then
        if enabled_map[data.command] == nil then
            dfhack.printerr(('tool not enableable: "%s"'):format(data.command))
            return false
        else
            dfhack.run_command({enabled and 'enable' or 'disable', data.command})
        end
    elseif data.mode == 'repeat' then
        if enabled then
            local command_str = ('repeat --name %s %s\n'):
                    format(data.command, table.concat(data.params, ' '))
            dfhack.run_command(command_str)
        else
            repeatUtil.cancel(data.command)
        end
    elseif data.mode == 'run' then
        if enabled then
            dfhack.run_command(data.command)
        end
    else
        dfhack.printerr(('unhandled command: "%s"'):format(data.command))
        return false
    end
    return true
end
