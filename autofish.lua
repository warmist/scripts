-- handles automatic fishing jobs to limit the number of fish the fortress keeps on hand
-- autofish [enable | disable] <max> [min] [--include-raw | -r]

--@ enable=true

local json = require("json")
local persist = require("persist-table")
local argparse = require("argparse")
local dump = require("dumper")

local GLOBAL_KEY = "autofish"

local help = [====[
autofish
=============
Manages your fish stocks by toggling fishing labours as you reach certain stock thresholds.


Usage
-------------
  autofish [enable | disable | status] | <max> [min] [--include-raw | -r]

Arguments
-------------
-r, --include-raw
  Allow the stock tracking to also count raw fish
enable
  Enable this script
disable
  Disable this script
status
  Print the current status
max
  The maximum number of fish you want to stop fishing at.
min
  the minimum number of fish before restarting fishing.
]====]
-- set default enabled state
enabled = enabled or false
set_maxFish = set_maxFish or 100
set_minFish = set_minFish or 50
set_useRaw = set_useRaw or false
isFishing = isFishing or true

function isEnabled()
    return enabled
end

local function persist_state()
    persist.GlobalTable[GLOBAL_KEY] = json.encode({enabled=enabled,
        set_maxFish=set_maxFish, set_minFish=set_minFish, set_useRaw=set_useRaw,
        isFishing=isFishing
    })
end

local function load_state()
    -- load persistent data
    local persisted_data = json.decode(persist.GlobalTable[GLOBAL_KEY] or "")
    enabled = (persisted_data or {enabled=false})["enabled"]
    set_maxFish = (persisted_data or {set_maxFish=100})["set_maxFish"]
    set_minFish = (persisted_data or {set_minFish=50})["set_minFish"]
    set_useRaw = (persisted_data or {set_useRaw=false})["set_useRaw"]
    isFishing = (persisted_data or {isFishing=true})["isFishing"]
end


-- toggle the fishing labour on all dwarves/work detail if enabled
function toggle_fishing_labour(state)
    -- pass true to state to turn on, otherwise disable
    -- find all work details that have fishing enabled:
    local work_details = df.global.plotinfo.hauling.work_details
    for k,v in pairs(work_details) do
        if v.allowed_labors.FISH then
            -- set limited to true just in case a custom work detail is being
            -- changed, to prevent *all* dwarves from fishing.
            v.work_detail_flags.limited = true
            v.work_detail_flags.enabled = state
        end
    end
    isFishing = state -- save current state
end

-- check if an item isn't forbidden/rotten/on fire/etc..
function isValidItem(item)
    local flags = item.flags
    if flags.rotten or flags.trader or flags.hostile or flags.forbid
        or flags.dump or flags.on_fire or flags.garbage_collect then
        return false
    end
    return true
end

function event_loop()
    if not enabled then return end
    local world = df.global.world

    -- count the number of valid fish we have. (not rotten, forbidden, on fire, dumping...)
    local prepared, raw = 0, 0
    for k,v in pairs(world.items.other[df.items_other_id.IN_PLAY]) do
        if v:getType() == df.item_type.FISH and isValidItem(v) then
            prepared = prepared + v:getStackSize()
        end
        if (v:getType() == df.item_type.RAW_FISH and isValidItem(v)) and set_useRaw then
            raw = raw + v:getStackSize()
        end
    end

    -- hande pausing/resuming labour
    local sumFish = prepared + raw

    if set_useRaw then
        if sumFish >= set_maxFish then
            toggle_fishing_labour(false)
        elseif sumFish < set_minFish then
            toggle_fishing_labour (true)
        end
    else
        if prepared >= set_maxFish then
            toggle_fishing_labour(false)
        elseif prepared < set_minFish then
            toggle_fishing_labour(true)
        end
    end

    -- don't need to check *that* often
    dfhack.timeout(1, "days", event_loop)
end



local function print_status()
    load_state()
    --print(string.format("%s max, %s min, %s useraw", settings.maxFish, settings.minFish, tostring(settings.useRawFish)))
    print(string.format("autofish is currently %s.\n", (enabled and "enabled" or "disabled")))
    if enabled then
        local rfs
        if set_useRaw then
            rfs="raw & prepared"
        else
            rfs="prepared"
        end

        print(string.format("Stopping at %s %s fish.", set_maxFish, rfs))
        print(string.format("Restarting at %s %s fish.", set_minFish, rfs))
        if isFishing then
            print("\nCurrently allowing fishing.")
        else
            print("\nCurrently not allowing fishing.")
        end
    end
end

-- handle loading
dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    print("state change")
    -- unload with game
    if sc == SC_MAP_UNLOADED then
        enabled = false
        return
    end

    -- only run in dorf mode
    if sc ~= SC_MAP_LOADED or df.global.gamemode == df.game_mode.DWARF then
        return
    end

    load_state()

    -- run the main code
    event_loop()
end


-- sanity checks?
if dfhack_flags.module then
    return
end

if df.global.gamemode ~= df.game_mode.DWARF or not dfhack.isMapLoaded() then
    dfhack.printerr("autofish needs a loaded fortress to work")
end

-- argument handling
-- autofish [enable | disable | status] | <max> [min] [--include-raw | -r]
local args = {...}
if dfhack_flags and dfhack_flags.enable then
    args = {dfhack_flags.enable_state and "enable" or "disable"}
end

-- find flags in args:
local positionals = argparse.processArgsGetopt(args,
    {{"r", "include-raw",
    handler=function() set_useRaw = not set_useRaw end}
})

if positionals[1] == "enable" then
    enabled = true
    --print_status()
elseif positionals[1] == "disable" then
    enabled = false
elseif positionals[1] == "status" then
    print_status()
elseif positionals ~= nil then
    -- positionals is a number?
    if positionals[1] and tonumber(positionals[1]) then
        -- assume we're changing setting:
        set_maxFish = tonumber(positionals[1])
    else
        return
    end
    if positionals[2] and tonumber(positionals[2]) then
        set_minFish = tonumber(positionals[2])
    end
    -- a setting probably changed, show the updated settings.
    print_status()
end


event_loop()
persist_state()
