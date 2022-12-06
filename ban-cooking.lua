-- convenient way to ban cooking categories of food
-- based on ban-cooking.rb
--[====[

ban-cooking
===========
A more convenient way to ban cooking various categories of foods than the
kitchen interface.  Usage:  ``ban-cooking <type>``.  Valid types are ``booze``,
``honey``, ``tallow``, ``oil``, ``seeds`` (non-tree plants with seeds),
``brew``, ``fruit``, ``mill``, ``thread``, and ``milk``.

]====]

kitchen = df.global.ui.kitchen

already_banned = already_banned or {}

for i,v in ipairs(kitchen.exc_types) do
    if v == df.kitchen_exc_type.Cook then
        already_banned[{kitchen.mat_types[i], kitchen.mat_indices[i], kitchen.item_types[i], kitchen.item_subtypes[i]}] = true
    end
end

local function ban_cooking(print_name, mat_type, mat_index, type, subtype)
    key = {mat_type, mat_index, type, subtype}
    -- Skip adding a new entry further below, if the item is already banned.
    if already_banned[key] then
        return
    end
    -- The item hasn't already been banned, so we do that here by appending its values to the various arrays
    print(print_name + ' has been banned!')
    kitchen.mat_types:insert('#', mat_type)
    kitchen.mat_indices:insert('#', mat_index)
    kitchen.item_types:insert('#', type)
    kitchen.item_subtypes:insert('#', subtype)
    kitchen.exc_types:insert('#', df.kitchen_exc_type.Cook)
    already_banned[key] = true
end

local funcs = {}

funcs["booze"] = function()
    for _,p in ipairs(df.global.world.raws.plants.all) do
        for _,m in ipairs(p.material) do
            if m.flags.ALCOHOL and m.flags.EDIBLE_COOKED then
                local matinfo = dfhack.matinfo.find(p.id, m.id)
                ban_cooking(p.name .. ' ' .. m.id, matinfo.type, matinfo.index, df.item_type.DRINK, -1)
            end
        end
    end
    for _,c in ipairs(df.global.world.raws.creatures.all) do
        for _,m in ipairs(c.material) do
            if m.flags.ALCOHOL and m.flags.EDIBLE_COOKED then
                local matinfo = dfhack.matinfo.find(creature_id.id, m.id)
                ban_cooking(c.name[2] .. ' ' .. m.id, matinfo.type, matinfo.index, df.item_type.DRINK, -1)
            end
        end
    end
end

funcs["honey"] = function()
    local mat = dfhack.matinfo.find("CREATURE:HONEY_BEE:HONEY")
    ban_cooking('honey bee honey', mat.type, mat.index, df.item_type.LIQUID_MISC, -1)
end

funcs["tallow"] = function()
    for _,c in ipairs(df.global.world.raws.creatures.all) do
        for _,m in ipairs(c.material) do
            if m.flags.EDIBLE_COOKED then
                for _,s in m.reaction_product.id do
                    if s.value == "SOAP_MAT" then
                        local matinfo = dfhack.matinfo.find(c.creature_id, m.id)
                        ban_cooking(c.name[2] .. ' ' .. m.id, matinfo.type, matinfo.index, df.item_type.GLOB, -1)
                        break
                    end
                end
            end
        end
    end
end

funcs["milk"] = function()
    for _,c in ipairs(df.global.world.raws.creatures.all) do
        for _,m in ipairs(c.material) do
            if m.flags.EDIBLE_COOKED then
                for _,s in m.reaction_product.id do
                    if s.value == "CHEESE_MAT" then
                        local matinfo = dfhack.matinfo.find(c.creature_id, m.id)
                        ban_cooking(c.name[2] .. ' ' .. m.id, matinfo.type, matinfo.index, df.item_type.LIQUID_MISC, -1)
                        break
                    end
                end
            end
        end
    end
end

funcs["oil"] = function()
    for _,p in ipairs(df.global.world.raws.plants.all) do
        for _,m in ipairs(p.material) do
            if m.flags.EDIBLE_COOKED then
                for _,s in m.reaction_product.id do
                    if s.value == "SOAP_MAT" then
                        local matinfo = dfhack.matinfo.find(p.id, m.id)
                        ban_cooking(p.name .. ' ' .. m.id, matinfo.type, matinfo.index, df.item_type.LIQUID_MISC, -1)
                        break
                    end
                end
            end
        end
    end
end

funcs["seed"] = function()
    for _,p in ipairs(df.global.world.raws.plants.all) do
        if p.material_defs.type.seed ~= -1 and p.material_defs.idx.seed ~= -1 and not p.flags.TREE then
            ban_cooking(p.name + ' seeds', p.material_defs.type.seed, p.material_defs.idx.seed, df.item_type.SEEDS, -1)
            for _,m in ipairs(p.material) do
                if m.id == "STRUCTURAL" and m.flags.EDIBLE_COOKED then
                    local has_drink = false
                    local has_seed = false
                    for _,s in m.reaction_product.id do
                        has_seed = has_seed or s.value == "SEED_MAT"
                        has_drink = has_drink or s.value == "DRINK_MAT"
                    end
                    if has_seed and has_drink then
                        local matinfo = dfhack.matinfo.find(p.id, m.id)
                        ban_cooking(p.name .. ' ' .. m.id, matinfo.type, matinfo.index, df.item_type.PLANT, -1)
                    end
                end
            end
            for k,g in ipairs(p.growths) do
                local matinfo = dfhack.matinfo.decode(g)
                local m = matinfo.material
                if m.flags.EDIBLE_COOKED then
                    local has_drink = false
                    local has_seed = false
                    for _,s in m.reaction_product.id do
                        has_seed = has_seed or s.value == "SEED_MAT"
                        has_drink = has_drink or s.value == "DRINK_MAT"
                    end
                    if has_seed and has_drink then
                        ban_cooking(p.name .. ' ' .. m.id, matinfo.type, matinfo.index, df.item_type.PLANT_GROWTH, k)
                    end
                end
            end
        end
    end
end

funcs["brew"] = function()
    for _,p in ipairs(df.global.world.raws.plants.all) do
        if p.material_defs.type.drink ~= -1 and p.material_defs.idx.drink ~= -1 then
            for _,m in ipairs(p.material) do
                if m.id == "STRUCTURAL" and m.flags.EDIBLE_COOKED then
                    for _,s in m.reaction_product.id do
                        if s.value == "DRINK_MAT" then
                            local matinfo = dfhack.matinfo.find(p.id, m.id)
                            ban_cooking(p.name .. ' ' .. m.id, matinfo.type, matinfo.index, df.item_type.PLANT, -1)
                            break
                        end
                    end
                end
            end
            for k,g in ipairs(p.growths) do
                local matinfo = dfhack.matinfo.decode(g)
                local m = matinfo.material
                if m.flags.EDIBLE_COOKED then
                    for _,s in m.reaction_product.id do
                        if s.value == "DRINK_MAT" then
                            ban_cooking(p.name .. ' ' .. m.id, matinfo.type, matinfo.index, df.item_type.PLANT_GROWTH, k)
                            break
                        end
                    end
                end
            end
        end
    end
end

funcs["mill"] = function()
    for _,p in ipairs(df.global.world.raws.plants.all) do
        if p.material_defs.idx.mill ~= -1 then
            for _,m in ipairs(p.material) do
                if m.id == "STRUCTURAL" and m.flags.EDIBLE_COOKED then
                    local matinfo = dfhack.matinfo.find(p.id, m.id)
                    ban_cooking(p.name .. ' ' .. m.id, matinfo.type, matinfo.index, df.item_type.PLANT, -1)
                end
            end
        end
    end
end

funcs["thread"] = function()
    for _,p in ipairs(df.global.world.raws.plants.all) do
        if p.material_defs.idx.thread ~= -1 then
            for _,m in ipairs(p.material) do
                if m.id == "STRUCTURAL" and m.flags.EDIBLE_COOKED then
                    for _,s in m.reaction_product.id do
                        if s.value == "THREAD" then
                            local matinfo = dfhack.matinfo.find(p.id, m.id)
                            ban_cooking(p.name .. ' ' .. m.id, matinfo.type, matinfo.index, df.item_type.PLANT, -1)
                            break
                        end
                    end
                end
            end
            for k,g in ipairs(p.growths) do
                local matinfo = dfhack.matinfo.decode(g)
                local m = matinfo.material
                if m.flags.EDIBLE_COOKED then
                    for _,s in m.reaction_product.id do
                        if s.value == "THREAD" then
                            ban_cooking(p.name .. ' ' .. m.id, matinfo.type, matinfo.index, df.item_type.PLANT_GROWTH, k)
                            break
                        end
                    end
                end
            end
        end
    end
end

funcs["fruit"] = function()
    for _,p in ipairs(df.global.world.raws.plants.all) do
        for k,g in ipairs(p.growths) do
            local matinfo = dfhack.matinfo.decode(g)
            local m = matinfo.material
            if m.id == "FRUIT" and m.flags.EDIBLE_COOKED and m.flags.LEAF_MAT then
                for _,s in m.reaction_product.id do
                    if s.value == "DRINK_MAT" then
                        ban_cooking(p.name .. ' ' .. m.id, matinfo.type, matinfo.index, df.item_type.PLANT_GROWTH, k)
                        break
                    end
                end
            end
        end
    end
end

-- not implementing show for now

if ... == "help" then
    print("ban-cooking booze  - bans cooking of drinks")
    print("ban-cooking honey  - bans cooking of honey bee honey")
    print("ban-cooking tallow - bans cooking of tallow")
    print("ban-cooking milk   - bans cooking of creature liquids that can be turned into cheese")
    print("ban-cooking oil    - bans cooking of oil")
    print("ban-cooking seeds  - bans cooking of plants that have farmable seeds and that can be brewed into alcohol (eating raw plants to get seeds is rather slow)")
    print("ban-cooking brew   - bans cooking of all plants (fruits too) that can be brewed into alcohol")
    print("ban-cooking fruit  - bans cooking of only fruits that can be brewed into alcohol")
    print("ban-cooking mill   - bans cooking of plants that can be milled into powder -- should any actually exist")
    print("ban-cooking thread - bans cooking of plants that can be spun into thread -- should any actually exist")
end

local args = {...}

for k,v in ipairs({...}) do
    if funcs[v] then
        funcs[v]()
    end
end
