-- Query is a script useful for finding and reading values of data structure fields. Purposes will likely be exclusive to writing lua script code.
-- Written by Josh Cooper(cppcooper) on 2017-12-21, last modified: 2021-06-10
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
 'excludetype',
 'excludekind',

 'noblacklist',
 'dumb',

 'setvalue',
 'oneline',
 'disableprint',
 'debug',
 'debugdata'
})
local args = utils.processArgs({...}, validArgs)
local new_value = nil
local find_value = nil
local maxdepth = nil
local cur_depth = -1
local tilex = nil
local tiley = nil
local bool_flags = {}

local help = [====[

devel/query
===========
Query is a script useful for finding and reading values of data structure
fields. Purposes will likely be exclusive to writing lua script code,
possibly C++.

This script takes your data selection eg.{table,unit,item,tile} then recursively
iterates through it outputting names and values of what it finds.

As it iterates you can have it do other things, like search for a specific
structure pattern (see lua patterns) or set the value of fields matching the
selection and any search pattern specified.

If the script is taking too long to finish, or if it can't finish you should run
``dfhack-run kill-lua`` from a terminal.

Examples::

  devel/query -unit -getfield id
  devel/query -unit -search STRENGTH
  devel/query -unit -search physical_attrs -maxdepth 2
  devel/query -tile -search dig
  devel/query -tile -search "occup.*carv"
  devel/query -table df -maxdepth 2
  devel/query -table df -maxdepth 2 -excludekind s -excludetype fsu -oneline
  devel/query -table df.profession -findvalue FISH
  devel/query -table df.global.ui.main -maxdepth 0
  devel/query -table df.global.ui.main -maxdepth 0 -oneline

**Selection options:**

``-unit``:              Selects the highlighted unit

``-item``:              Selects the highlighted item.

``-tile``:              Selects the highlighted tile's block and then attempts
                        to find the tile, and perform your queries on it.

``-table <value>``:     Selects the specified table (ie. 'value').

                        Must use dot notation to denote sub-tables.
                        (eg. ``-table df.global.world``)

``-getfield <value>``:  Gets the specified field from the selection.

                        Must use in conjunction with one of the above selection
                        options. Must use dot notation to denote sub-fields.

**Query options:**

``-search <value>``:       Searches the selection for field names with
                           substrings matching the specified value.

``-findvalue <value>``:    Searches the selection for field values matching the
                           specified value.

``-maxdepth <value>``:     Limits the field recursion depth (default: 7)

``-maxlength <value>``:    Limits the table sizes that will be walked
                           (default: 257)

``-excludetype [a|bfnstu0]``:  Excludes data types: All | Boolean, Function,
                               Number, String, Table, Userdata, nil

``-excludekind [a|bces]``:     Excludes data types: All | Bit-fields,
                               Class-type, Enum-type, Struct-type

``-noblacklist``:   Disables blacklist filtering.

``-dumb``:          Disables intelligent checking for recursive data
                    structures(loops) and increases the -maxdepth to 25 if a
                    value is not already present

**Command options:**

``-setvalue <value>``: Attempts to set the values of any printed fields.
                       Supported types: boolean,

``-oneline``:          Reduces output to one line, except with ``-debugdata``

``-disableprint``:     Disables printing. Might be useful if you are debugging
                       this script. Or to see if a query will crash (faster) but
                       not sure what else you could use it for.
                       
``-debug <value>``:    Enables debug log lines equal to or less than the value
                       provided.

``-debugdata``:        Enables debugging data. Prints type information under
                       each field.

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
            function recurse(fname, value)
                local newTName = makeName(tname, fname)
                if is_tiledata(value) then
                    local newPath =  appendField(path, string.format("%s[%d][%d]", fname,tilex,tiley))
                    query(value[tilex][tiley], newTName, search_term, newPath)
                elseif not is_looping(path, newTName) then
                    local newPath =  appendField(path, fname)
                    query(value, newTName, search_term, newPath)
                end
            end
            foreach(t, recurse)
        end
    end
    cur_depth = cur_depth - 1
end

function foreach(t, fn)
    if getmetatable(t) and t._kind and t._kind == "enum-type" then
        for k,v in ipairs(t) do
            fn(k,v)
        end
    else
        for k,v in safe_pairs(t) do
            fn(k,v)
        end
    end
end

function setValue(tname, t)
    if args.setvalue then
        if not args.search or is_match(tname, t) then
            t = new_value
        end
    end
end

--Section: entry/initialization
function main()
    if args.help then
        print(help)
        return
    end
    processArguments()
    local selection,path_info = table.unpack{getSelectionData()}
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
        local pos = copyall(df.global.cursor)
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
    return selection, path_info
end

function processArguments()
    --Table Recursion
    if args.maxdepth then
        maxdepth = tonumber(args.maxdepth)
        if not maxdepth then
            qerror(string.format("Must provide a number with -depth"))
        end
    elseif args.dumb then
        maxdepth = 25
    else
        maxdepth = 7
    end
    args.maxdepth = maxdepth

    --Table Length
    if not args.maxlength then
        --[[ Table length is inversely proportional to how useful the data is.
        257 was chosen with the intent of capturing all enums. Or hopefully most of them.
        ]]
        args.maxlength = 257
    else
        args.maxlength = tonumber(args.maxlength)
    end

    new_value = toType(args.setvalue)
    find_value = toType(args.findvalue)

    args.excludetype = args.excludetype and args.excludetype or ""
    args.excludekind = args.excludekind and args.excludekind or ""
    if string.find(args.excludetype, 'a') then
        bool_flags["boolean"] = true
        bool_flags["function"] = true
        bool_flags["number"] = true
        bool_flags["string"] = true
        bool_flags["table"] = true
        bool_flags["userdata"] = true
    else
        bool_flags["boolean"] = string.find(args.excludetype, 'b') and true or false
        bool_flags["function"] = string.find(args.excludetype, 'f') and true or false
        bool_flags["number"] = string.find(args.excludetype, 'n') and true or false
        bool_flags["string"] = string.find(args.excludetype, 's') and true or false
        bool_flags["table"] = string.find(args.excludetype, 't') and true or false
        bool_flags["userdata"] = string.find(args.excludetype, 'u') and true or false
    end

    if string.find(args.excludekind, 'a') then
        bool_flags["bit-field"] = true
        bool_flags["class-type"] = true
        bool_flags["enum-type"] = true
        bool_flags["struct-type"] = true
    else
        bool_flags["bit-field"] = string.find(args.excludekind, 'b') and true or false
        bool_flags["class-type"] = string.find(args.excludekind, 'c') and true or false
        bool_flags["enum-type"] = string.find(args.excludekind, 'e') and true or false
        bool_flags["struct-type"] = string.find(args.excludekind, 's') and true or false
    end
end

local bRunOnce={}
function runOnce(caller)
    if bRunOnce[caller] == true then
        return false
    end
    bRunOnce[caller] = true
    return true
end

--Section: filters
function is_searchable(tname, t)
    if not is_blacklisted(tname, t) and not df.isnull(t) then
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
    return false
end

function is_match(path, field, value)
    if not args.search or string.find(tostring(field),args.search) or string.find(path,args.search) then
        if not args.findvalue or (not type(value) == "string" and value == find_value) or string.find(value,find_value) then
            return true
        end
    end
    return false
end

function is_looping(path, field)
    return not args.dumb and string.find(path, tostring(field))
end

function is_blacklisted(field, t)
    field = tostring(field)
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

function is_tiledata(value)
    if args.tile and string.find(tostring(value),"%[16%]") then
        if type(value) and string.find(tostring(value[tilex]),"%[16%]") then
            return true
        end
    end
    return false
end

function is_excluded(value)
    return bool_flags[type(value)] or not isEmpty(value) and getmetatable(value) and bool_flags[value._kind]
end

function toType(str)
    if str ~= nil then
        if str == "true" then
            return true
        elseif str == "false" then
            return false
        elseif tonumber(str) then
            return tonumber(str)
        elseif string.find(str, "nil") then
            return nil
        else
            return tostring(str)
        end
    end
    return nil
end

--Section: table helpers
function safe_pairs(t, keys_only)
    if keys_only then
        local mt = debug.getmetatable(t)
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
    local ret = table.pack(pcall(function() return pairs(t) end))
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
        if getmetatable(value) and value._kind and value._kind ~= nil then
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
    if not args.disableprint and not is_excluded(value) then
        if is_tiledata(value) then
            value = value[tilex][tiley]
            field = string.format("%s[%d][%d]", field,tilex,tiley)
        end
        local indent = nil
        local bMatch = false
        if not args.search and not args.findvalue then
            indent = makeIndentation()
        elseif is_match(path, field, value) then
            --print(path,field,value,args.findvalue,find_value)
            bMatch = true
        end
        if indent ~= nil or bMatch then
            local indentedField = tostring(bMatch and path or field)
            if bMatch then
                indentedField = string.format("%-80s ", indentedField .. ":")
            else
                indentedField = string.format("%-40s ", indentedField .. ":")
            end
            if args.debugdata or not args.oneline or bToggle then
                indentedField = string.gsub(indentedField,"  "," ~")
                bToggle = false
            else
                bToggle = true
            end
            if not bMatch then
                indentedField = indent .. "| " .. indentedField
            end
            local N = math.min(90, string.len(indentedField))
            indent = string.format("%" .. N .. "s", "")
            local output = nil
            if hasMetadata(value) then
                if args.oneline then
                    output = string.format("%s %s [%s]", indentedField, value, value._kind)
                else
                    output = string.format("%s %s\n%s [has metatable; _kind: %s]", indentedField, value, indent, value._kind)
                end
            else
                if args.debugdata then
                    output = string.format("%s type(%s) = %s", indentedField, value, type(value))
                else
                    output = string.format("%s %s", indentedField, value)
                end
            end
            if args.debugdata then
                if hasMetadata(value) then
                    print(value)
                    if not args.search and args.oneline then
                        output = output .. string.format("\n%s type(%s): %s, _kind: %s, _type: %s",
                                indent, field, type(value), field._kind, field._type)
                    else
                        output = output .. string.format("\n%s type(%s): %s\n%s _kind: %s\n%s _type: %s",
                                indent, field, type(value), indent, field._kind, indent, field._type)
                    end
                else
                    if args.oneline then
                        output = output .. string.format(", type(%s): %s", path, type(value))
                    else
                        output = output .. string.format("\n%s type(%s): %s", indent, field, type(value))
                    end
                end
            end
            print(output)
        end
    end
end

function debugf(level,...)
    if args.debug and level <= tonumber(args.debug) then
        local str=string.format(" #  %s",select(1, ...))
        for i = 2, select('#', ...) do
            str=string.format("%s\t%s",str,select(i, ...))
        end
        print(str)
    end
end

main()
print()