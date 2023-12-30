-- migrate configuration from 50.11-r4 and prior to new format
--@module = true

-- init files
local SYSTEM_INIT_FILE = 'dfhack-config/init/dfhack.control-panel-system.init'
local PREFERENCES_INIT_FILE = 'dfhack-config/init/dfhack.control-panel-preferences.init'
local AUTOSTART_FILE = 'dfhack-config/init/onMapLoad.control-panel-new-fort.init'
local REPEATS_FILE = 'dfhack-config/init/onMapLoad.control-panel-repeats.init'

function migrate(config_data)
    -- read old files, add converted data to config_data, overwrite old files with
    -- a message that says they are deprecated and can be deleted with the proper procedure
    -- we can't delete them outright since steam may just restore them due to Steam Cloud
    -- we *could* delete them if we know that we've been started from Steam as DFHack and not as DF
end
