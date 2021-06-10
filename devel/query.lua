-- Query is a script useful for finding and reading values of data structure fields. Purposes will likely be exclusive to writing lua script code.
-- Written by Josh Cooper(cppcooper) on 2017-12-21, last modified: 2021-06-15
-- Version: 3.x
--luacheck:skip-entirely
local utils=require('utils')
local validArgs = utils.invert({
 'help',

 'unit',
 'item',
 'tile',
 'table',
 'getfield',

 'search',
 'findvalue',
 'maxdepth',
 'maxlength',

 'noblacklist',
 'safer',
 'dumb',

 'setvalue',
 'disableprint',
 'debug',
 'devdebug',
 'debugdata'
})
local args = utils.processArgs({...}, validArgs)
new_value =nil
maxdepth =nil
cur_depth = -1

local help = [====[

devel/query
===========
Query is a script useful for finding and reading values of data structure fields.
Purposes will likely be exclusive to writing lua script code.

This is a recursive script which takes your selected data {table,unit,item,tile}
and then iterates through it, then iterates through anything it finds. It does
this recursively until it has walked over everything it is allowed. Everything
it walks over it checks against any (optional) string/value queries, and if it
finds a match it then prints it to the console.

You can control most aspects of this process, the script is fairly flexible. So
much so that you can easily create an infinitely recursing query and/or potentially
crash Dwarf Fortress and DFHack. In previous iterations memory bloat was even a
concern, where RAM would be used up in mere minutes or seconds; you can probably
get this to happen as well if you are careless with the depth settings and don't
print everything walked over (i.e. have a search term). The `kill-lua` command
may be able to stop this script if it gets out of control.

Before recursing or printing things to the console the script checks several things.
A few important ones:

 - Is the data structure capable of being iterated?
 - Is the data structure pointing to a parent data structure?
 - Is the current level of recursion too high, and do we need to unwind it first?
 - Is the number of entries too high (eg. 70,000 table entries that would be printed)?
 - Is the data going to be usefully readable?
 - Does the field or key match the field or key query or queries?
 - Is printing fields allowed?
 - Is printing keys allowed?

Examples::

  devel/query -table df -search dead
  devel/query -table df.global.ui.main -depth 0
  devel/query -table df.profession -querykeys WAR
  devel/query -unit -search STRENGTH
  devel/query -unit -search physical_attrs -listkeys
  devel/query -unit -getfield id

**Selection options:**

``-unit``:              Selects the highlighted unit

``-item``:              Selects the highlighted item.

``-tile``:              Selects the highlighted tile's block and then attempts to find the tile, and perform your queries on it.

``-table <value>``:     Selects the specified table (ie. 'value').

                        Must use dot notation to denote sub-tables.
                        (eg. ``-table df.global.world``)

``-getfield <value>``:  Gets the specified field from the selection.

                        Must use in conjunction with one of the above selection options.
                        Must use dot notation to denote sub-fields.

**Query options:**

``-search <value>``:       Searches the selection for field names with substrings matching the specified value.

``-findvalue <value>``:    Searches the selection for field values matching the specified value.

``-maxdepth <value>``:     Limits the field recursion depth (default: 10)

``-maxlength <value>``:    Limits the table sizes that will be walked (default: 257)

``-noblacklist``:   Disables blacklist filtering.

``-safer``:         Disables walking struct data.

                    Unlike native Lua types, struct data can sometimes be misaligned,
                    which can cause crashes when accessing it. This option may be useful
                    if you're running an alpha or beta build of DFHack.

``-dumb``:          Disables intelligent checks for things such as reasonable
                    recursion depth [note: depth maximums are increased, not removed]
                    and also checks for recursive data structures (ie. cycles)

**Command options:**

``-setvalue <value>``: Attempts to set the values of any printed fields.
                       Supported types: boolean,

``-disableprint``:     Disables printing. Might be useful if you are debugging this script.
                       Or to see if a query will crash (faster) but not sure what else you could use it for.
                       
``-debug <value>``:    Enables debug log lines equal to or less than the value provided.

``-debugdata``:        Enables debugging data. Prints type information under each field.

``-help``:             Prints this help information.

]====]

--[[ Test cases:
    These sections just have to do with when I made the tests and what their purpose at that time was.
    [safety] make sure the query doesn't crash itself or dfhack
        1. devel/query -maxdepth 3 -table df
        2. devel/query -dumb -table dfhack -search gui
        3. devel/query -dumb -table df
        4. devel/query -dumb -unit
    [validity] make sure the query output is not malformed, and does what is expected
        1. devel/query -dumb -table dfhack
        2. devel/query -dumb -table df -search job_skill
        3. devel/query -dumb -table df -getfield job_skill
]]

--Section: entry/initialization
function main()
    if args.help then
        print(help)
        return
    end
    processArguments()
    local selection,path_info,pos,tilex,tiley = table.unpack{getSelectionData()}
    debugf(0, tostring(selection), path_info)

    if selection == nil then
        qerror(string.format("Selected %s is null. Invalid selection.", path_info))
        return
    end
    query(selection, path_info, args.search, path_info)
end

function getSelectionData()
    local selection = nil
    local path_info = nil
    local pos = nil
    local tilex = nil
    local tiley = nil
    if args.table then
        debugf(0,"table selection")
        selection = findTable(args.table)
        path_info = args.table
    elseif args.unit then
        debugf(0,"unit selection")
        selection = dfhack.gui.getSelectedUnit()
        path_info = "unit"
    elseif args.item then
        debugf(0,"item selection")
        selection = dfhack.gui.getSelectedItem()
        path_info = "item"
    elseif args.tile then
        debugf(0,"tile selection")
        pos = copyall(df.global.cursor)
        selection = dfhack.maps.ensureTileBlock(pos.x,pos.y,pos.z)
        path_info = string.format("block[%d][%d][%d]",pos.x,pos.y,pos.z)
        tilex = pos.x%16
        tiley = pos.y%16
    else
        print(help)
    end
    if args.getfield then
        selection = findPath(selection,args.getfield)
        path_info = path_info .. "." .. args.getfield
    end
    --print(selection, path_info)
    return selection, path_info, pos, tilex, tiley
end

function processArguments()
    --Dumb Queries
    if args.dumb then
        --[[ Let's make the recursion dumber, but let's not do it infinitely.
        There are many recursive structures which would cause this to happen.
        ]]
        if not args.maxdepth then
            maxdepth = 25
            args.maxdepth = maxdepth
        end
    else
        --Table Length
        if not args.maxlength then
            --[[ Table length is inversely proportional to how useful the data is.
            257 was chosen with the intent of capturing all enums. Or hopefully most of them.
            ]]
            args.maxlength = 257
        else
            args.maxlength = tonumber(args.maxlength)
        end
    end

    --Table Recursion
    if args.maxdepth then
        maxdepth = tonumber(args.maxdepth)
        if not maxdepth then
            qerror(string.format("Must provide a number with -depth"))
        end
    else
        maxdepth = 10
        args.maxdepth = maxdepth
    end

    --Set Key [boolean parsing]
    if args.setkey == "true" then
        new_value =true
    elseif args.setkey == "false" then
        new_value =false
    end
end

bRunOnce={}
function runOnce(caller)
    if bRunOnce[caller] == true then
        return false
    end
    bRunOnce[caller] = true
    return true
end

--Section: core logic
function query(t, tname, search_term, path)
    --[[
    * print info about t
    * increment depth
    * check depth
    * recurse structure
    * decrement depth
    ]]--
    setValue(tname, t)
    printField(path, tname, t)
    cur_depth = cur_depth + 1
    if not maxdepth or cur_depth <= maxdepth then
        -- check that we can search
        if is_searchable(tname, t) then
            -- iterate over search space
            for fname,v in safe_pairs(t) do
                -- for each, make new parent string and recurse
                --print(k,t[k],v)
                local newTName = makeName(tname, fname)
                if not is_recursive(path, newTName) then
                    local newPath =  appendField(path, fname)
                    query(t[fname], newTName, search_term, newPath)
                end
            end
        end
    end
    cur_depth = cur_depth - 1
end

function setValue(tname, t)
    if args.setvalue then
        if not args.search or is_match(tname, t) then
            t = args.setvalue
        end
    end
end

--Section: filters
function is_searchable(tname, t)
    if type(t) ~= "function" then
        if not isBlackListed(tname, t) and not df.isnull(t) then
            debugf(1,string.format("is_searchable( %s ): type: %s, length: %s, count: %s",t,type(t),getTableLength(t), countTableLength(t)))
            if not isEmpty(t) then
                if not args.maxlength or runOnce(is_searchable) or countTableLength(t) <= args.maxlength then
                    if getmetatable(t) then
                        if t._kind == "primitive" then
                            return false
                        elseif t._kind == "struct" then
                            if args.safer then
                                return false
                            else
                                return true
                            end
                        end
                        debugf(1,string.format("_kind: %s, _type: %s",t._kind,t._type))
                    end
                    for _,_ in safe_pairs(t) do
                        return true
                    end
                end
            end
        end
    end
    return false
end

function is_match(path, field, value)
    return (not args.findvalue or value == args.findvalue)
            and (not args.search or string.find(tostring(field),args.search) or string.find(path,args.search))
end

function is_recursive(path, field)
    return string.find(path, tostring(field))
end

function isBlackListed(field, t)
    if not args.noblacklist then
        if string.find(field,"script") then
            return true
        elseif string.find(field,"saves") then
            return true
        elseif string.find(field,"movie") then
            return true
        elseif string.find(field,"font") then
            return true
        elseif string.find(field,"texpos") then
            return true
        end
    end
    return false
end

--Section: table helpers
function safe_pairs(item, keys_only)
    --thanks goes to lethosor for this function
    if keys_only then
        local mt = debug.getmetatable(item)
        if mt and mt._index_table then
            local idx = 0
            return function()
                idx = idx + 1
                if mt._index_table[idx] then
                    return mt._index_table[idx]
                end
            end
        end
    end
    local ret = table.pack(pcall(function() return pairs(item) end))
    local ok = ret[1]
    table.remove(ret, 1)
    if ok then
        return table.unpack(ret)
    else
        return function() end
    end
end

function isEmpty(t)
    for _,_ in safe_pairs(t) do
        return false
    end
    return true
end

function countTableLength(t)
    local count = 0
    for _,_ in safe_pairs(t) do
        count = count + 1
    end
    debugf(1,string.format("countTableEntries( %s ) = %d",t,count))
    return count
end

function getTableLength(t)
    if type(t) == "table" then
        local count=#t
        debugf(1,string.format("----getTableLength( %s ) = %d",t,count))
        return count
    end
    return 0
end

function findPath(t, path)
    debugf(1,"parsing",t, path)
    curTable = t
    keyParts = {}
    for word in string.gmatch(path, '([^.]+)') do --thanks stack overflow
        table.insert(keyParts, word)
    end
    if not curTable then
        qerror("Looks like we're borked somehow.")
    end
    for _,v in pairs(keyParts) do
        if v and curTable[v] ~= nil then
            debugf(1,"found something",v,curTable,curTable[v])
            curTable = curTable[v]
        else
            qerror("Table" .. v .. " does not exist.")
        end
    end
    --debugf(1,"returning",curTable)
    return curTable
end

function findTable(path)
    tableParts = {}
    for word in string.gmatch(path, '([^.]+)') do --thanks stack overflow
        table.insert(tableParts, word)
    end
    curTable = nil
    for k,v in pairs(tableParts) do
        if curTable == nil then
            if _G[v] ~= nil then
                curTable = _G[v]
            else
                qerror("Table" .. v .. " does not exist.")
            end
        else
            if curTable[v] ~= nil then
                curTable = curTable[v]
            else
                qerror("Table" .. v .. " does not exist.")
            end
        end
    end
    return curTable
end

function hasMetadata(value)
    if not isEmpty(value) then
        if getmetatable(value) and value._kind then
            return true
        end
    end
    return false
end

--Section: output helpers
function makeName(tname, field)
    if tonumber(field) then
        return string.format("%s[%s]", tname, field)
    end
    return field
end

function appendField(parent, field)
    newParent=""
    if tonumber(field) then
        newParent=string.format("%s[%s]",parent,field)
    else
        newParent=string.format("%s.%s",parent,field)
    end
    debugf(2, string.format("new parent: %s", newParent))
    return newParent
end

function makeIndentation()
    local base="  "
    local indent=""
    for i=1,(cur_depth) do
        indent=indent .. string.format("%s",base)
    end
    --indent=string.format("%s ",base)
    return indent
end

bToggle = true
function printField(path, field, value)
    if runOnce(printField) then
        print(string.format("%s: %s", path, value))
        return
    end
    if not args.disableprint then
        local indent = nil
        local bMatch = false
        if not args.search then
            indent = makeIndentation()
        elseif is_match(path, field, value) then
            bMatch = true
        end
        if indent ~= nil or bMatch then
            local indentedField = tostring(bMatch and path or field)
            if bMatch then
                indentedField = string.format("%-80s ", indentedField .. ":")
            else
                indentedField = string.format("%-40s ", indentedField .. ":")
            end
            if bToggle then
                indentedField = string.gsub(indentedField,"  "," ~")
                bToggle = false
            else
                bToggle = true
            end
            if not bMatch then
                indentedField = indent .. "| " .. indentedField
            end
            indent = string.format("%" .. string.len(indentedField) .. "s", "")
            if hasMetadata(value) then
                print(string.format("%s %s\n%s [has metatable; _kind: %s]", indentedField, value, indent, value._kind))
            else
                print(string.format("%s %s", indentedField, value))
            end
            if args.debugdata then
                if hasMetadata(value) then
                    print(string.format("%s type(%s): %s\n%s _kind: %s\n%s _type: %s", indent, field, type(value), indent, field._kind, indent, field._type))
                else
                    print(string.format("%s type(%s): %s", indent, field, type(value)))
                end
            end
        end
    end
end

function debugf(level,...)
    if args.debug and level <= tonumber(args.debug) then
        str=string.format(" #  %s",select(1, ...))
        for i = 2, select('#', ...) do
            str=string.format("%s\t%s",str,select(i, ...))
        end
        print(str)
    end
end

main()
