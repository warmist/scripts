-- Merge food and drink stacks in the selected stockpile or every stockpile
--[====[

combine by Vettlingr
==============
Merge stacks of food in the selected stockpile or all stockpiles.

]====]
local utils = require 'utils'

local f = {
    validArgs = utils.invert({ 'help', 'drinks', 'plants', 'meat', 'fish', 'fat', 'food', 'roasts', 'max', 'all', 'stockpile' });
    args = utils.processArgs({...}, validArgs);
help = [====[
Combine
=============
Merge stacks of food in selected Stockpile or across all stockpiles on the map.
Valid commands:
:``-drinks``:
    Merges drinks
:``-plants``:
    Merges plants
:``-meat``:
    Merges meat and intestines
:``-fat``:
    Merges fat and tallow
:``-roasts``:
    Merges prepared food
:``-fish``:
    Merges fish
:``-food``:
    Merges all food categories
:``-all``:
    Selects all stockpiles
:``-max``:
    Selects a maximum stacksize, if unspecified it will be set to 500

Examples:
combine -drinks -fish -all
    Combines drinks and fish stacks in all stockpiles

combine -food -all
    Combines all food types across all stockpiles

combine -fat -roasts -max 50
    Combines fat and prepared food in the selected stockpile with a preferred stacksize of 50

]====]
}

local max = 30

local drinks={}
local plants={}
local meats={}
local fat={}
local roasts={}
local fish={}

--Stockpile Stack sizes:
drinks.max  =   30
plants.max  =   6
meats.max   =   20
fat.max     =   20
roasts.max  =   20
fish.max    =   10

if f.args.drinks then drinks.max = tonumber(f.args.drinks) end
if f.args.plants then plants.max = tonumber(f.args.plants) end
if f.args.meats then meats.max = tonumber(f.args.meats) end
if f.args.fat then fat.max = tonumber(f.args.fat) end
if f.args.roasts then roasts.max = tonumber(f.args.roasts) end
if f.args.fish then fish.max = tonumber(f.args.fish) end

--Not sure if these are needed.
drinks.Tot=0 drinks.xTot=0
plants.Tot=0 plants.xTot=0
meats.Tot=0 meats.xTot=0
fat.Tot=0 fat.xTot=0
roasts.Tot=0 roasts.xTot=0
fish.Tot=0 fish.xTot=0

if f.args.max then max = tonumber(f.args.max) end

local stockpile = nil
if f.args.stockpile then stockpile = df.building.find(tonumber(f.args.stockpile)) end

local function itemsCompatible(item0, item1)
    return item0:getType() == item1:getType()
        and item0.mat_type == item1.mat_type
        and item0.mat_index == item1.mat_index
end

local function FishitemsCompatible(item0, item1)
    return item0:getType() == item1:getType()
        and item0.race == item1.race
        and item0.caste == item1.caste
end

function getItems(items, item, index, bool)
    repeat
        local nextBatch = {}
        for _,v in pairs(items) do
            -- Skip items currently tasked
            if #v.specific_refs == 0 then
                    if bool==1 and ( v:getType() == df.item_type.DRINK )then
                        item[index] = v
                        index = index + 1
                    elseif bool==2 and ( v:getType() == df.item_type.PLANT or v:getType() == df.item_type.PLANT_GROWTH ) then
                            item[index] = v
                            index = index + 1
                    elseif bool==3 and (v:getType() == df.item_type.MEAT ) then
                            item[index] = v
                            index = index + 1
                    elseif bool==4 and (v:getType() == df.item_type.GLOB ) then
                            item[index] = v
                            index = index + 1
                    elseif bool==5 and (v:getType() == df.item_type.FOOD or v:getType() == df.item_type.CHEESE ) then
                            item[index] = v
                            index = index + 1
                    elseif bool==10 and (v:getType() == df.item_type.FISH or v:getType() == df.item_type.FISH_RAW or v:getType() == df.item_type.EGG ) then
                        item[index] = v
                        index = index + 1
                    else
                    local containedItems = dfhack.items.getContainedItems(v)
                        if (bool==1 and #containedItems == 1) or (bool>1 and #containedItems > 0) then
                            for _,w in pairs(containedItems) do
                                table.insert(nextBatch, w)
                            end
                        end
                    end
                end
            end
        items = nextBatch
    until #items == 0
    return index
end

function Combineitems(building, tabl, food, bool)
    local rootItems
    if building then
        rootItems = dfhack.buildings.getStockpileContents(building)
    else
        rootItems = dfhack.items.getContainedItems(item)
    end
    if #rootItems == 0 and not f.args.all then
        qerror("Select a non-empty container")
        return
    else
        local foodCount = getItems(rootItems, food, 0, bool)
        local removedFood = { } --as:bool[]
        food.max=max
        if f.args.max then max = tonumber(f.args.max)
            if tonumber(f.args.max)== 0 then max = 500
            end
        end
        for i=0,(foodCount-2) do
            local currentFood = food[i] --as:df.item_foodst
            local itemsNeeded = max - currentFood.stack_size

            if removedFood[currentFood.id] == nil and itemsNeeded > 0 then
                local j = i+1
                local last = foodCount
                repeat
                    local sourceFood = food[j]
                        if bool>=10 and removedFood[sourceFood.id] == nil and FishitemsCompatible(currentFood, sourceFood) then
                            local amountToMove = math.min(itemsNeeded, sourceFood.stack_size)
                            itemsNeeded = itemsNeeded - amountToMove
                            currentFood.stack_size = currentFood.stack_size + amountToMove

                            if sourceFood.stack_size == amountToMove then
                                removedFood[sourceFood.id] = true
                                sourceFood.stack_size = 1
                            else
                                sourceFood.stack_size = sourceFood.stack_size - amountToMove
                            end
                            --                    else print("failed")
                        elseif bool <10 and removedFood[sourceFood.id] == nil and itemsCompatible(currentFood, sourceFood) then
                            local amountToMove = math.min(itemsNeeded, sourceFood.stack_size)
                            itemsNeeded = itemsNeeded - amountToMove
                            currentFood.stack_size = currentFood.stack_size + amountToMove

                            if sourceFood.stack_size == amountToMove then
                                removedFood[sourceFood.id] = true
                                if bool>1 then sourceFood.stack_size = 1 end
                            else
                                sourceFood.stack_size = sourceFood.stack_size - amountToMove
                            end
                            --                    else print("failed")
                        end
                    j = j + 1
                until j == foodCount or itemsNeeded == 0
            end
        end
        local removedCount = 0
        for id,removed in pairs(removedFood) do
            if removed then
                removedCount = removedCount + 1
                local removedFood = df.item.find(id)
                dfhack.items.remove(removedFood)
            end
        end
        if food.Tot == nil then food.Tot = 0 end
        if food.xTot == nil then food.xTot = 0 end
        food.Tot = food.Tot + foodCount
        food.xTot = food.xTot + removedCount
    end
end

if f.args.help then
    print(f.help)
    return
end
if not f.args.all then
    local building = stockpile or dfhack.gui.getSelectedBuilding(true)
    if building ~= nil and building:getType() ~= 29 then building = nil
        end
    if building ~= nil then
        if f.args.drinks or f.args.food then
            Combineitems(building, f, drinks, 1)
            print("found " .. drinks.Tot .. " drinks")
            print("merged " .. drinks.xTot .. " drinks")
        end
        if f.args.plants or f.args.food then
            Combineitems(building, f, plants, 2)
            print("found " .. plants.Tot .. " plants")
            print("merged " .. plants.xTot .. " plants")
        end
        if f.args.meat or f.args.food then
            Combineitems(building, f, meats, 3)
            print("found " .. meats.Tot .. " meat")
            print("merged " .. meats.xTot .. " meat")
        end
        if f.args.fat or f.args.food then
            Combineitems(building, f, fat, 4)
            print("found " .. fat.Tot .. " fat")
            print("merged " .. fat.xTot .. " fat")
        end
        if f.args.roasts or f.args.food then
            Combineitems(building, f, roasts, 5)
            print("found " .. roasts.Tot .. " prepared food")
            print("merged " .. roasts.xTot .. " prepared food")
        end
        if f.args.fish or f.args.food then
            Combineitems(building, f, fish, 10)
            print("found " .. fish.Tot .. " fish")
            print("merged " .. fish.xTot .. " fish")
        end
    else
        print('select a stockpile')
    end
else
    if f.args.all then
        print('Combining all food...')
        for _, building in pairs(df.global.world.buildings.all) do
            if building:getType() == 29 and building ~= nil then
                if building ~= nil then
                    if f.args.drinks or f.args.food then
                        Combineitems(building, f, drinks, 1)
                    end
                    if f.args.plants or f.args.food then
                        Combineitems(building, f, plants, 2)
                    end
                    if f.args.meat or f.args.food then
                        Combineitems(building, f, meats, 3)
                    end
                    if f.args.fat or f.args.food then
                        Combineitems(building, f, fat, 4)
                    end
                    if f.args.roasts or f.args.food then
                        Combineitems(building, f, roasts, 5)
                    end
                    if f.args.fish or f.args.food then
                        Combineitems(building, f, fish, 10)
                    end
                else
                    print('invalid')
                end
            end
        end
        if f.args.drinks or f.args.food then
            print("found " .. drinks.Tot .. " drinks")
            print("merged " .. drinks.xTot .. " drinks")
        end
        if f.args.plants or f.args.food then
            print("found " .. plants.Tot .. " plants")
            print("merged " .. plants.xTot .. " plants")
        end
        if f.args.meat or f.args.food then
            print("found " .. meats.Tot .. " meat")
            print("merged " .. meats.xTot .. " meat")
        end
        if f.args.fat or f.args.food then
            print("found " .. fat.Tot .. " fat or tallow")
            print("merged " .. fat.xTot .. " fat or tallow")
        end
        if f.args.roasts or f.args.food then
            print("found " .. roasts.Tot .. " prepared food")
            print("merged " .. roasts.xTot .. " prepared food")
        end
        if f.args.fish or f.args.food then
            print("found " .. fish.Tot .. " fish")
            print("merged " .. fish.xTot .. " fish")
        end
    end
    return
end
