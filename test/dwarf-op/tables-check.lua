config = {
    mode = 'fortress',
}

local dorf_tables = reqscript('internal/dwarf-op/dorf_tables')

function collect_profs(job)
    local profs = {}
    for prof,p in pairs(job) do
        if tonumber(p) then
            table.insert(profs, prof)
        end
    end
    return profs
end

function check_prof(prof)
    expect.ne(dorf_tables.professions[prof], nil, prof .. " was not found in the professions table, there may be a typo")
    expect.ne(df.profession[prof], nil, prof .. " does not appear to be a valid DF built-in profession")
end

function validate_skills(table)
    if table.skills ~= nil then
        for skill,_ in pairs(table.skills) do
            expect.ne(df.job_skill[skill], nil, skill .. " does not appear to be a valid DF built-in skill")
        end
    end
end

function test.dorf_tables()
    -- validate jobs table
    for _,job in pairs(dorf_tables.jobs) do
        profs = collect_profs(job)
        -- validate professions
        for _,prof in pairs(profs) do
            check_prof(prof)
        end
        -- validate required professions
        if dorf_tables.jobs.req ~= nil then
            for _,prof in pairs(dorf_tables.jobs.req) do
                check_prof(prof)
            end
        end
        -- validate types
        if dorf_tables.jobs.types ~= nil then
            for _,type in pairs(dorf_tables.jobs.types) do
                expect.neq(dorf_tables.types[type], nil, type .. " was not found in the types table, it may be a.... type-o =)")
            end
        end
    end
    -- validate professions table
    for _,prof in pairs(dorf_tables.professions) do
        -- validate skills
        validate_skills(prof)
    end
    -- validate types table
    for _,type in pairs(dorf_tables.types) do
        validate_skills(type)
        for attribute,_ in pairs(type.attribs) do
            local v = df.physical_attribute_type[attribute] or df.mental_attribute_type[attribute]
            expect.ne(v, nil, attribute .. " was not found in either list of attribute enums {physical_attribute_type, mental_attribute_type}")
        end
    end
end