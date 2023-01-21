-- Workaround for the v50.x bug where Dwarf Fortress occasionally erase Dwarf's nicknames.
-- It happen when killing certain figures, such as forgotten beasts.
--@ enable = true

local repeatUtil = require('repeat-util')
local modId = "fix-nicks-mod"
local usage = [[
Usage
-----
    Enabling fix-nicks will prevent any nickname to be erased, by a game bug or by the player.
    The nicknames are saved and restored once a day.

    enable fix-nicks
    disable fix-nicks
]]

local function isempty(s)
    return s == nil or s == ''
end

local function save_nicks()
    for k,unit in pairs(df.global.world.units.active) do
        local nickname = unit.name.nickname
        local hfid = unit.id
        if not isempty(nickname) then
            dfhack.persistent.save{key="nicknames/" .. hfid, value=nickname, ints = {hfid}}
        end
    end
end

local function restore_nicks()
    for k,entry in pairs(dfhack.persistent.get_all("nicknames", true)) do
        local nickname = entry.value
        local hfid = entry.ints[1]

        local unit = df.unit.find(hfid)
        if isempty(unit.name.nickname) then
            print("Restoring removed nickname for " .. nickname)
            dfhack.units.setNickname(unit, nickname)
        end
    end
end

local function save_and_restore_nicks()
    save_nicks()
    restore_nicks()
end

enabled = enabled or false
if not dfhack_flags.enable then
    print(usage)
    print()
    print(('fix-nicks is currently '):format(
            enabled and 'enabled' or 'disabled'))
    return
end

if dfhack_flags.enable_state then
    save_nicks()
    repeatUtil.scheduleEvery(modId, 1, "days", save_and_restore_nicks)

    print('fix-nicks enabled')
    enabled = true
else
    repeatUtil.cancel(modId)
    print('fix-nicks disabled')
    enabled = false
end
