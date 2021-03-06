-- Lua script coverage report generator

local help_message =
[====[
Lua script coverage report generator

Usage:
    luacov [options] [pattern...]

This script generates a coverage report from collected statistics. By default it
reports on every Lua file in all of DFHack. To filter filenames, specify one or
more Lua patterns matching files or directories to be included. Alternately, you
can configure reporting parameters in the .luacov file in your DF directory. See
https://keplerproject.github.io/luacov/doc/modules/luacov.defaults.html for
details.

Statistics are cumulative across reports. That is, if you run a report, run a
lua script, and then run another report, the report will include all activity
from the first report plus the recently run lua script. Restarting DFHack will
clear the statistics. You can also clear statistics after running a report by
passing the --clear flag to this script.

Note that the coverage report will be empty unless you run DFHack with the
"DFHACK_ENABLE_LUACOV=1" environment variable defined, which starts the coverage
monitoring.

Also note that coverage monitoring and lua profiling via the "profiler" module
cannot both be active at the same time. Their interceptor hooks override each
other. Usage of the "kill-lua" command will likewise override the luacov
interceptor hook and prevent coverage statistics from being collected.

Options:

-c, --clear
    Remove accumulated metrics after generating the report, ensuring the next
    report starts from a clean slate.
-h, --help
    Show this help message and exit.

Examples:

devel/luacov
     Report on all DFHack lua scripts.
devel/luacov quickfort
    Report only on quickfort source files.
devel/luacov quickfort hack/lua
    Report only on quickfort and DFHack library lua source files.
]====]

local utils = require('utils')
local runner = require("luacov.runner")

local clear, show_help = false, false
local other_args = utils.processArgsGetopt({...}, {
        {'c', 'clear', handler=function() clear = true end},
        {'h', 'help', handler=function() show_help = true end},
    })
if show_help then
    dfhack.print(string.format('LuaCov %s - ', runner.version))
    print(help_message)
    return
end

if not runner.initialized or debug.gethook() ~= runner.debug_hook then
    dfhack.printerr(
        'Warning: Coverage stats are not being collected. Report will be' ..
        ' empty unless stats were collected in a previous run. Please run' ..
        ' dfhack with the DFHACK_ENABLE_LUACOV environment variable defined' ..
        ' to start coverage monitoring. Keep in mind that using the' ..
        ' "kill-lua" command or using a Lua profiler will interfere with' ..
        ' coverage monitoring.')
end

-- gets the active luacov configuration
local config = runner.load_config()

-- save the original configuration values since this script can mutate the
-- config when run with parameters, but we need to restore the original values
-- when this script is subsequently run without parameters.
default_include = default_include or config.include or {}
if default_clear == nil then default_clear = config.deletestats or false end

-- override 'include' table if patterns were explicitly specified
config.include = #other_args == 0 and default_include or {}
for _,pattern in ipairs(other_args) do
    table.insert(config.include,
                (pattern:gsub("\\", "/"):gsub("%.lua$", "")))
end

-- always exclude test files
config.exclude = config.exclude or {}
local test_pattern = '/test/' -- those are path slashes and not regex delimiters
if not utils.invert(config.exclude)[test_pattern] then
    table.insert(config.exclude, test_pattern)
end

-- remove stats after generating report if requested; otherwise restore default
config.deletestats = clear or default_clear

runner.pause()
dfhack.with_finalize(
    function() runner.resume() end,
    function()
        print(('flushing coverage stats to "%s"'):format(config.statsfile))
        runner.save_stats()

        print(('generating report in "%s" for files matching:'):format(
                config.reportfile))
        if #config.include == 0 then
            print('  .*')
        else
            for _,pattern in ipairs(config.include) do
                print(('  %s'):format(pattern))
            end
        end
        print(('and %s accumulated stats in "%s"'):format(
                config.deletestats and 'removing' or 'keeping',
                config.statsfile))
        runner.run_report(config)
    end)
