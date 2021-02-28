-- Lua script coverage report generator

local help_message =
[====[
Lua script coverage report generator

Usage:
    luacov [options] [pattern...]

This script generates a coverage report from collected statistics. By default it
reports on every Lua file in all of DFHack. To filter filenames, specify one or
more Lua patterns matching files to be included. Alternately, you can configure
reporting parameters in the .luacov file in your DF directory. See online luacov
documentation for the format of that file.

Statistics are cumulative across reports. That is, if you run a report, run a
lua script, and then run another report, the report will include all activity
from the first report plus the recently run lua script. Restarting DFHack will
clear the statistics. You can also clear statistics from previous reports while
DFHack is running by deleting the "luacov.stats.out" file in your DF folder.

Note that the coverage report will be empty unless you run DFHack with the
"DFHACK_ENABLE_LUACOV" environment variable defined, which starts the coverage
monitoring.

Also note that coverage monitoring and lua profiling via the "profiler" module
cannot both be active at the same time. Their interceptor hooks override each
other. Usage of the "kill-lua" command will likewise override the luacov
interceptor hook and prevent coverage statistics from being collected.

Options:

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

local show_help = false
local other_args = utils.processArgsGetopt({...}, {
        {'h', 'help', handler=function() show_help = true end},
    })
if show_help then
    dfhack.print(string.format('LuaCov %s - ', runner.version))
    print(help_message)
    return
end

if not runner.initialized then
    dfhack.printerr(
        'Warning: Coverage stats are not being collected. Report will be' ..
        ' empty. Please run dfhack with the DFHACK_ENABLE_LUACOV environment' ..
        ' variable defined to start coverage monitoring.')
end

-- gets the active luacov configuration
local configuration = runner.load_config()

-- save the original include table since this script can mutate it when run with
-- parameters, but we need to restore the original values when this script is
-- subsequently run without parameters.
default_include = default_include or configuration.include or {}
configuration.include = #other_args == 0 and default_include or {}

-- override 'include' table if patterns were explicitly specified
for _,pattern in ipairs(other_args) do
    table.insert(configuration.include,
                (pattern:gsub("\\", "/"):gsub("%.lua$", "")))
end

print('flushing accumulated stats')
runner.save_stats()

print(string.format('generating report in "%s" for files matching:',
                    configuration.reportfile))
if #configuration.include == 0 then
    print('  all')
else
    for _,pattern in ipairs(configuration.include) do
        print(('  %s'):format(pattern))
    end
end
runner.run_report(configuration)
