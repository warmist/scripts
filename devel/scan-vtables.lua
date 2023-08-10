memscan = require('memscan')

local df_ranges = {}
for i,mem in ipairs(dfhack.internal.getMemRanges()) do
    if mem.read and (
        string.match(mem.name,'/dwarfort%.exe$')
        or string.match(mem.name,'/dwarfort$')
        or string.match(mem.name,'/Dwarf_Fortress$')
        or string.match(mem.name,'Dwarf Fortress%.exe')
        or string.match(mem.name,'/libg_src_lib.so$')
    )
    then
        table.insert(df_ranges, mem)
    end
end

function is_df_addr(a)
    for _, mem in ipairs(df_ranges) do
        if a >= mem.start_addr and a < mem.end_addr then
            return true
        end
    end
    return false
end

for _, range in ipairs(df_ranges) do
    if (not range.read) or range.write or range.execute or range.name:match('g_src') then
        goto next_range
    end

    local area = memscan.MemoryArea.new(range.start_addr, range.end_addr)
    for i = 1, area.uintptr_t.count - 1 do
        local vtable = area.uintptr_t:idx2addr(i)
        local typeinfo = area.uintptr_t[i - 1]
        if is_df_addr(typeinfo + 8) then
            local typestring = df.reinterpret_cast('uintptr_t', typeinfo + 8)[0]
            if is_df_addr(typestring) then
                local vlen = 0
                while is_df_addr(vtable + (8*vlen)) and is_df_addr(df.reinterpret_cast('uintptr_t', vtable + (8*vlen))[0]) do
                    vlen = vlen + 1
                    break -- for now, any vtable with one valid function pointer is valid enough
                end
                if vlen > 0 then
                    local ok, name = pcall(function()
                        return memscan.read_c_string(df.reinterpret_cast('char', typestring))--:gsub('^%d+', '')
                    end)
                    if not ok then
                    else
                        local demangled_name = dfhack.internal.cxxDemangle('_Z' .. name)
                        if demangled_name and not demangled_name:match('[<>]') and not demangled_name:match('^std::') then
                            print(("<vtable-address name='%s' value='0x%x'/>"):format(demangled_name, vtable))
                        end
                    end
                end
            end
        end

    end
    ::next_range::
end
