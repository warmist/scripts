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

 'search',
 'hasvalue',

 'maxdepth',
 'maxtablelength',

 'getfield',
 'setvalue',

 'noblacklist',
 'showall',

 'safer',
 'dumb',
 'disableprint',
 'debug',
 'devdebug',
 'datadebug'
})
local args = utils.processArgs({...}, validArgs)
maxdepth =nil
cur_depth = -1

newkeyvalue=nil
bprintfields=nil
bprintkeys=nil
space_field="   "
fN=0
--kN=25
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

  devel/query -table df -query dead
  devel/query -table df.global.ui.main -depth 0
  devel/query -table df.profession -querykeys WAR
  devel/query -unit -query STRENGTH
  devel/query -unit -query physical_attrs -listkeys
  devel/query -unit -getfield id

**Selection options:**

These options are used to specify where the query will run,
or specifically what key to print inside a unit.

``-unit``:              Selects the highlighted unit

``-item``:              Selects the highlighted item.

``-tile``:              Selects the highlighted tile's block and then attempts to find the tile, and perform your queries on it.

``-table <value>``:     Selects the specified table (ie. 'value').

                        Must use dot notation to denote sub-tables.
                        (eg. ``-table df.global.world``)

``-getfield <value>``:  Gets the specified field from the selection.

                        Must use dot notation to denote sub-fields.
                        Useful if there would be several matching
                        fields with the input as a substring (eg. 'id', 'gui')

**Query options:**

``-search <value>``:       Searches the selection for field names with substrings matching the specified value.

``-hasvalue <value>``:     Searches the selection for field values matching the specified value.

``-maxdepth <value>``:        Limits the field recursion depth (default: 10)

``-maxtablelength <value>``:  Limits the table sizes that will be walked (default: 257)

``-noblacklist``:   Removes blacklist filtering, and disregards readability of output.

``-safer``:         Disables walking struct data.

                    Unlike native Lua types, struct data can sometimes be misaligned,
                    which can cause crashes when accessing it. This option may be useful
                    if you're running an alpha or beta build of DFHack.

``-dumb``:          Disables intelligent checks for things such as reasonable
                    recursion depth [note: depth maximums are increased, not removed]
                    and also checks for recursive data structures (ie. cycles)

**Command options:**

``-debug <value>``: Enables debug log lines equal to or less than the value
provided. Some lines are commented out entirely, and you probably won't even use
this.. but hey, now you know it exists.

``-disableprint``: Disables printing fields and keys. Might be useful if you are
debugging this script. Or to see if a query will crash (faster) but not sure
what else you could use it for.

``-help``: Prints this help information.

]====]

--[[ Test cases:
    These sections just have to do with when I made the tests and what their purpose at that time was.
    [safety] make sure the query doesn't crash itself or dfhack
        1. devel/query -keydepth 3 -listall -table df
        2. devel/query -depth 10 -keydepth 3 -includeitall -dumb -table dfhack -query gui -listall
        3. devel/query -depth 10 -keydepth 3 -includeitall -dumb -table df -listfields
        4. devel/query -depth 10 -keydepth 5 -includeitall -dumb -unit -listall
    [validity] make sure the query output is not malformed, and does what is expected
        1. devel/query -dumb -includeitall -listfields -unit
        2. devel/query -dumb -includeitall -listfields -table dfhack
        3. devel/query -dumb -includeitall -listfields -table df
        4. devel/query -dumb -includeitall -listfields -table df -query job_skill
        5. devel/query -dumb -includeitall -listall -table df -query job_skill
        6. devel/query -dumb -includeitall -listall -table df -getfield job_skill
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
        selection = parseTableString(selection,args.getfield)
    end
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
        if not args.maxtablelength then
            --[[ Table length is inversely proportional to how useful the data is.
            257 was chosen with the intent of capturing all enums. Or hopefully most of them.
            ]]
            args.maxtablelength = 257
        else
            args.maxtablelength = tonumber(args.maxtablelength)
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
        newkeyvalue=true
    elseif args.setkey == "false" then
        newkeyvalue=false
    end
end

--Section: core logic
function query(t, tname, search_term, path)
    --[[
    * increment depth
    * check depth
    * print info about t
    * recurse structure
    * decrement depth
    ]]--
    cur_depth = cur_depth + 1
    if not maxdepth or cur_depth < maxdepth then
        -- check that we can search
        -- print field t
        setValue(t)
        printField(path, tname, t)
        --print()
        if is_searchable(t, tname) then
            -- iterate over search space
            for k,v in pairs(t) do
                -- for each, make new parent string and recurse
                --print(k,t[k],v)
                local newTName = makeName(tname,k)
                local newParent =  appendField(path,k)
                query(t[k], newTName, search_term, newParent)
            end
        end
    end
    cur_depth = cur_depth - 1
end

function setValue(field)
    if args.setvalue then
        if not args.search or is_match(path, tostring(field), field) then
            field = args.setvalue
        end
    end
end

--Section: filters
function is_searchable(t, tname)
    if not isBlackListed(tname) and not df.isnull(t) then
        debugf(1,string.format("is_searchable( %s ): type: %s, length: %s, count: %s",t,type(t),getTableLength(t), countTableLength(t)))
        if not isEmpty(t) then
            if not args.maxtablelength or runOnce(is_searchable) or countTableLength(t) <= args.maxtablelength then
                if getmetatable(t) then
                    if t._kind == "primitive" then
                        return false
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
    return not is_recursive(path, field)
            and (not args.hasvalue or value == args.hasvalue)
            and (not args.search or string.find(tostring(field),args.search))
end

function is_recursive(path, field)
    return string.find(path, tostring(field))
end

function isBlackListed(field)
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

bRunOnce={}
function runOnce(caller)
    if bRunOnce[caller] == true then
        return false
    end
    bRunOnce[caller] = true
    return true
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

function parseTableString(t, path)
    debugf(1,"parsing",t, path)
    curTable = t
    keyParts = {}
    for word in string.gmatch(path, '([^.]+)') do --thanks stack overflow
        table.insert(keyParts, word)
    end
    if not curTable then
        qerror("Looks like we're borked somehow.")
    end
    for k,v in pairs(keyParts) do
        if v and curTable[v] ~= nil then
            --debugf(1,"found something",v,curTable,curTable[v])
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
    indent="   "
    for i=1,(cur_depth) do
        indent=string.format("  %s",indent)
    end
    indent=string.format("%s ",indent)
    return indent
end

bToggle = true
function printField(path, field, value)
    if runOnce(printField) then
        print(string.format("%s", path))
        return
    end
    if not args.disableprint then
        local indent = nil
        if not args.search then
            indent = makeIndentation()
        elseif is_match(path, field, value) then
            indent = makeIndentation()
        end
        if indent ~= nil then
            local indentedField = field
            indentedField = string.format("%-40s", field .. ":")
            if bToggle then
                indentedField = string.gsub(indentedField,"  "," ~")
                bToggle = false
            else
                bToggle = true
            end
            indentedField = indent .. "| " .. indentedField
            indent = string.format("%" .. string.len(indentedField) .. "s", "")
            if hasMetadata(value) then
                print(string.format("%s %s\n%s [has metatable; _kind: %s]", indentedField, value, indent, value._kind))
            else
                print(string.format("%s %s", indentedField, value))
            end
            if args.datadebug then
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



function hasPairs(value)
    --debugf(11,"hasPairs()")
    if type(value) == "table" then
        --debugf(11,"hasPairs: stage 1")
        return true
    elseif type(value) == "userdata" then
        --debugf(11,"hasPairs: stage 2")
        if getmetatable(value) then
            --debugf(11,"hasPairs: stage 3")
            if value._kind == "primitive" then
                return false
            elseif value._kind == "container" or value._kind == "bitfield" then
                --debugf(11,"hasPairs: stage 4")
                return true
            elseif value._kind == "struct" and not df.isnull(value) then
                --debugf(11,"hasPairs: stage 5. struct is not null")
                if args.safer then
                    return false
                else
                    return true
                end
            end
            debugf(11,"hasPairs: stage 6")
            debugf(0,string.format("This shouldn't be reached.\n   input-value: %s, type: %s, _kind: %s",value,type(value),value._kind))
            return (TableLength(value) ~= 0)
        end
    else
        --debugf(11,"hasPairs: stage 7")
        for k,v in safe_pairs(value) do
            --debugf(11,"hasPairs: stage 8")
            debugf(0,string.format("Pretty sure this is never going to proc, except on structs.\n   table-length: %d, input-value: %s, type: %s, k: %s, v: %s",TableLength(value),value,type(value),k,v))
            return true
        end
    end
    --debugf(11,"hasPairs: stage 0")
    return false
end

function isFieldValueMatch(field,value)
    --debugf(11,"isFieldValueMatch()")
    if not (args.query or args.queryvalues) then
        --debugf(11,"isFieldValueMatch: stage 1")
        return true
    end
    --debugf(11,"isFieldValueMatch: stage 2,0")
    bFieldMatches = not args.query or (args.query and string.find(tostring(field),args.query))
    bValueMatches = not args.queryvalues or (args.queryvalues and string.find(tostring(value),args.queryvalues))
    return bFieldMatches and bValueMatches
end

function isKeyValueMatch(key,value)
    --debugf(11,"isKeyValueMatch()")
    if not (args.querykeys or args.queryvalues) then
        --debugf(11,"isKeyValueMatch: stage 1")
        return true
    end
    --debugf(11,"isKeyValueMatch: stage 2,0")
    bKeyMatches = not args.querykeys or (args.querykeys and string.find(key,args.querykeys))
    bValueMatches = not args.queryvalues or (args.queryvalues and string.find(tostring(value),args.queryvalues))
    return bKeyMatches and bValueMatches
end



function isFieldHumanReadable(field,value)
    if args.includeitall then
        return true
    end
    --debugf(11,"isFieldHumanReadable()")
    tf=tonumber(field) and "number" or type(field)
    tv=type(value)
    if tf == "string" or hasPairs(value) then
        --debugf(11,"isFieldHumanReadable: stage 1")
        return true
    elseif tf ~= "number" then
        debugf(0,"field type is not a string, or a number. It is: ", tf)
    else
        debugf(1,string.format("field type: %s,  value type: %s",tf,tv))
    end
    --debugf(11,"isFieldHumanReadable: stage 0")
    return false
end

function isKeyHumanReadable(key,value)
    if args.includeitall then
        return true
    end
    --debugf(11,"isKeyHumanReadable()")
    tk=tonumber(key) and "number" or type(key)
    tv=type(value)
    debugf(4,string.format("isKeyHumanReadable: key=%s, value=%s, value-type=%s",key,value,type(value)))
    if tk == "string" or tv == "string" then
        --debugf(11,"isKeyHumanReadable: stage 1")
        return true
    elseif tk == "number" and getmetatable(value) then
        --debugf(11,"isKeyHumanReadable: stage 2")
        return true
    elseif tk ~= "number" then
        debugf(0,"key type is not a string, or a number. It is: ", tk)
    else
        debugf(1,string.format("field type: %s,  value type: %s",tk,tv))
    end
    --debugf(11,"isKeyHumanReadable: stage 0")
    return false
end

function canRecurseField(parent,field,value)
    debugf(10,"canRecurseField()",field,value)
    if type(value) == "table" and hasPairs(value) and (not args.maxtablelength or TableLength(value) <= args.maxtablelength) then
        --debugf(11,"canRecurseField: stage 1")
        --check that we aren't going to walk through a pointer to the parent structure
        if tonumber(field) then
            --debugf(11,"canRecurseField: stage 2")
            --[[if args.dumb or not string.find(parent,"%[[%d]+%]") then
                --debugf(11,"canRecurseField: stage 3")
                return true
            end]]
            return true
        end
        pattern=string.format("%%.%s",field)
        if not string.find(parent,string.format("%s%%.",pattern)) and
           not string.find(parent,pattern,1+parent:len()-pattern:len()) then
            --debugf(11,"canRecurseField: stage 4")
            --todo???if not tonumber(k) and (type(k) ~= "table" or depth) and not string.find(tostring(k), 'script') then
            if not isBlackListed(field) then
                --debugf(11,"canRecurseField: stage 5")
                return true
            end
        end
    end
    --debugf(11,"canRecurseField: stage 0")
    return false
end

function canRecurseKey(parent,key,value)
    --debugf(11,"canRecurseKey()",key,value)
    if hasPairs(value) and (not args.maxtablelength or TableLength(value) <= args.maxtablelength) then
        --debugf(11,"canRecurseKey: stage 1")
        --check that we aren't going to walk through a pointer to the parent structure
        if tonumber(key) then
            --debugf(11,"canRecurseKey: stage 2")
            --[[if args.dumb or not string.find(parent,"%[[%d]+%]") then
                --debugf(11,"canRecurseKey: stage 3")
                return true
            end]]
            return true
        end
        pattern=string.format("%%.%s",key)
        if not string.find(parent,string.format("%s%%.",pattern)) and
           not string.find(parent,pattern,1+parent:len()-pattern:len()) then
            --debugf(11,"canRecurseKey: stage 4")
            --todo???if not tonumber(k) and (type(k) ~= "table" or depth) and not string.find(tostring(k), 'script') then
            if not isBlackListed(key) then
                --debugf(11,"canRecurseKey: stage 5")
                return true
            end
        end
    end
    --debugf(11,"canRecurseKey: stage 0")
    return false
end

function print_tile(key,v)
    print(string.format("%s, v._kind: %s", v[x][y], v[x][y]._kind))
    for k,v2 in safe_pairs(v[x][y]) do
        if isKeyHumanReadable(k,v2) then
            bprintparent=print_key(k,v2,bprintparent,parent,v2)
            if canRecurseKey(parent,k,v2) then
                debugf(3,"print_keys->print_keys.3")
                print_keys(string.format(tonumber(k) and "%s[%s]" or "%s.%s",parent,k),k,v2,bprintparent)
            else
                debugf(3,"print_keys->norecursion.3")
            end
        end
    end
    if v._kind == "container" and string.find(tostring(v),"%[16%]%[%]") then
        if isKeyValueMatch(key) then
            debugf(0,"print_keys->print_tile")
            print_key(string.format("%s[%d][%d]",key,x,y), v[x][y])
            return true
        end
    end
    return false
end

function print_keys(parent,field,value,bprintparent)
    --debugf(11,"print_keys()")
    cur_keydepth = cur_keydepth + 1
    if not keydepth or (cur_keydepth <= keydepth) then
        if hasMetadata(value) then
            debugf(5,"print_keys: field value has metadata")
            if value._kind == "enum-type" then
                debugf(4,"print_keys: enum-type")
                for i,v in ipairs(value) do
                    if isKeyHumanReadable(i,value) then
                        bprintparent=print_key(i,v,bprintparent,parent,value)
                        if canRecurseKey(parent,i,v) then
                            debugf(3,"print_keys->print_keys.1")
                            print_keys(string.format("%s[%d]",parent,i),i,v,bprintparent)
                        else
                            debugf(3,"print_keys->norecursion.1")
                        end
                    end
                end
            elseif value._kind == "container" then
                debugf(5,"print_keys: container")
                if not args.tile or not print_tile(field,value) then
                    debugf(4,"print_keys: not a tile exclusive data structure",string.format("_type: %s, length: %s", value._type, #value))
                    for k,v in pairs(value) do
                        if isKeyHumanReadable(k,v) then
                            bprintparent=print_key(k,v,bprintparent,parent,value)
                            if canRecurseKey(parent,k,v) then
                                debugf(3,"print_keys->print_keys.2")
                                print_keys(string.format(tonumber(k) and "%s[%s]" or "%s.%s",parent,k),k,v,bprintparent)
                            else
                                debugf(3,"print_keys->norecursion.2")
                            end
                        end
                    end
                end
            else
                debugf(5,string.format("print_keys:\n    # parent: %s\n    # field: %s\n    # _kind: %s\n    # type: %s\n    # value: %s",parent,field,value._kind,type(value),value))
                if value._kind == "struct" then
                    --debugf(11,string.format("struct length: %s",TableLength(value)))
                end
                for k,v in safe_pairs(value) do
                    if isKeyHumanReadable(k,v) then
                        bprintparent=print_key(k,v,bprintparent,parent,value)
                        if canRecurseKey(parent,k,v) then
                            debugf(3,"print_keys->print_keys.3")
                            print_keys(string.format(tonumber(k) and "%s[%s]" or "%s.%s",parent,k),k,v,bprintparent)
                        else
                            debugf(3,"print_keys->norecursion.3")
                        end
                    end
                end
            end
        else
            debugf(5,string.format("print_keys:\n    # parent: %s\n    # field: %s\n    # type: %s\n    # value: %s",parent,field,type(value),value))
            for k,v in pairs(value) do
                if isKeyHumanReadable(k,v) then
                    bprintparent=print_key(k,v,bprintparent,parent,value)
                    if canRecurseKey(parent,k,v) then
                        debugf(3,"print_keys->print_keys.4")
                        print_keys(string.format(tonumber(k) and "%s[%s]" or "%s.%s",parent,k),k,v,bprintparent)
                    else
                        debugf(3,"print_keys->norecursion.4")
                    end
                end
            end
        end
    end
    cur_keydepth = cur_keydepth - 1
    --debugf(11,"print_keys: exit")
end

function print_key(k,v,bprintparent,parent,v0)
    if not args.disableprint and (k or v) and isKeyValueMatch(k,v) then
        if bprintparent then
            debugf(7,"print_key->print_field")
            print_field(parent,v0)
            bprintparent=false
        end
        if args.setkey then
            set_key(v0,k)
            v=v0[k]
        end
        key=string.format("%-4s ",tostring(k)..":")
        indent="   |"
        for i=1,(cur_keydepth) do
            indent=string.format("  %s",indent)
        end
        indent=string.format("%s ",indent)
        print(indent .. string.format("%s",key) .. tostring(v))
    end
    return bprintparent
end

function set_key(v0,k)
    key_type=type(v0[k])
    if key_type == "number" and tonumber(args.setkey) then
        v0[k]=tonumber(args.setkey)
    elseif key_type == "boolean" and newkeyvalue then
        v0[k]=newkeyvalue
    elseif key_type == "string" then
        v0[k]=args.setkey
    end
end

function print_field(field,v)
    if not args.disableprint and (field or v) then
        field=string.format("%s: ",tostring(field))
        cN=string.len(field)
        fN = cN >= fN and cN or fN
        fN = fN >= 90 and 90 or fN
        form="%-"..(fN+5).."s"
        print(space_field .. string.gsub(string.format(form,field),"   "," ~ ") .. "[" .. type(v) .. "] " .. tostring(v))
    end
end

function Query(t,query,parent,field,bprintparent)
    cur_depth = cur_depth + 1
    breturn_printedkeys=false
    if not maxdepth or cur_depth < maxdepth then --We always have at least the default depth limit
        parent = parent and parent or ""
        field = field and field or ""
        debugf(10,"we're inside query")
        if bprintkeys and hasMetadata(t) and t._kind == "enum-type" and isFieldValueMatch(field,value) then
            debugf(5,"query is going straight to print_keys")
            print_keys(parent,"",t,bprintparent)
            breturn_printedkeys=true
        else
            for field,value in pairs(t) do
                debugf(10,"we're looping inside query")
                if value then
                    debugf(9,"query loop has a valid value",field,value)
                    debugf(9,string.format("value-type: %s, field: %s, value: %s",type(value),field,value))
                    newParent=""
                    if tonumber(field) then
                        newParent=string.format("%s[%s]",parent,field)
                    else
                        newParent=string.format("%s.%s",parent,field)
                    end
                    debugf(10,"query: stage 1")

                    -- print field
                    bprintparent=true
                    if bprintfields and isFieldValueMatch(field,value) and isFieldHumanReadable(field,value) then
                        debugf(8,"query->print_field")
                        print_field(newParent,value)
                        bprintparent=false
                    end
                    debugf(10,"query: stage 2")

                    -- query recursively
                    bprintedkeys=false
                    if canRecurseField(parent,field,value) then
                        debugf(8,"query->query")
                        bprintedkeys=Query(t[field],query,newParent,field,bprintparent)
                    end
                    debugf(10,"query: stage 3")

                    -- print keys
                    if bprintkeys and not bprintedkeys and isFieldValueMatch(field,value) and canRecurseKey(parent,field,value) then
                        debugf(8,"query->print_keys")
                        print_keys(newParent,field,value,bprintparent)
                        breturn_printedkeys=true
                    end
                    debugf(10,"query: stage 4")
                end
            end
        end
    end
    cur_depth = cur_depth - 1
    return breturn_printedkeys
end

main()
