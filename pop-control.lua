-- Script to control the various population caps as well as use of max-wave and hermit persistently per fortress
-- by Tachytaenius
--[====[
pop-control
===========
Controls the various population caps as well as use of max-wave and hermit persistently per fortress
Intended to be placed within ``onMapLoad.init`` as ``pop-control on-load``
Available arguments:

- ``on-load`` automatically checks for settings for this site and prompts them to be entered if not present

- ``reenter-settings`` revise settings for this site
]====]

local script = require("gui.script")
local persistTable = require("persist-table")

-- (Hopefully) get original settings
originalPopCap = originalPopCap or df.global.d_init.population_cap
originalStrictPopCap = originalStrictPopCap or df.global.d_init.strict_population_cap
originalVisitorCap = originalVisitorCap or df.global.d_init.visitor_cap

if df.global.gamemode ~= 0 then
    return -- not fort mode!
end

if not persistTable.GlobalTable.fortPopInfo then
    persistTable.GlobalTable.fortPopInfo = {}
end

local siteId = df.global.ui.site_id

local function popControl(forceEnterSettings)
    script.start(function()
        local siteInfo = persistTable.GlobalTable.fortPopInfo[siteId]
        if not siteInfo or forceEnterSettings then
            -- get new settings
            persistTable.GlobalTable.fortPopInfo[siteId] = nil -- i don't know if persist-table works well with reassignent
            persistTable.GlobalTable.fortPopInfo[siteId] = {}
            siteInfo = persistTable.GlobalTable.fortPopInfo[siteId]
            if script.showYesNoPrompt("Hermit", "Hermit mode?") then
                siteInfo.hermit = "true"
            else
                siteInfo.hermit = "false"
                local _ -- ignore
                -- migrant cap
                local migrantCapInput
                while not tonumber(migrantCapInput) do
                    _, migrantCapInput = script.showInputPrompt("Migrant cap", "Maximum migrants per wave?")
                end
                siteInfo.migrantCap = migrantCapInput
                -- pop cap
                local popCapInput
                while not tonumber(popCapInput) or popCapInput == "" do
                    _, popCapInput = script.showInputPrompt("Population cap", "Maximum population? Settings population cap: " .. originalPopCap .. "\n(assuming wasn't changed before first call of this script)")
                end
                siteInfo.popCap = tostring(tonumber(popCapInput) or originalPopCap)
                -- strict pop cap
                local strictPopCapInput
                while not tonumber(strictPopCapInput) or strictPopCapInput == "" do
                    _, strictPopCapInput = script.showInputPrompt("Strict population cap", "Strict maximum population? Settings strict population cap " .. originalStrictPopCap .. "\n(assuming wasn't changed before first call of this script)")
                end
                siteInfo.strictPopCap = tostring(tonumber(strictPopCapInput) or originalStrictPopCap)
                -- visitor cap
                local visitorCapInput
                while not tonumber(visitorCapInput) or visitorCapInput == "" do
                    _, visitorCapInput = script.showInputPrompt("Visitors", "Vistitor cap? Settings visitor cap " .. originalVisitorCap .. "\n(assuming wasn't changed before first call of this script)")
                end
                siteInfo.visitorCap = tostring(tonumber(visitorCap) or originalVisitorCap)
            end
        end
        -- use settings
        if siteInfo.hermit == "true" then
            dfhack.run_command("hermit enable")
            -- NOTE: could, maybe should cancel max-wave repeat here
        else
            dfhack.run_command("hermit disable")
            dfhack.run_command("repeat -name max-wave -timeUnits months -time 1 -command [ max-wave " .. siteInfo.migrantCap .. " " .. siteInfo.popCap .. " ]")
            df.global.d_init.strict_population_cap = tonumber(siteInfo.strictPopCap)
            df.global.d_init.visitor_cap = tonumber(siteInfo.visitorCap)
        end
    end)
end

local function help()
    print("syntax: pop-control [reenter-settings|on-load]")
end

local action_switch = {
    ["reenter-settings"] = function() popControl(true) end,
    ["on-load"] = function() popControl(false) end
}
setmetatable(action_switch, {__index = function() return help end})

local args = {...}
action_switch[args[1] or "help"]()
