-- Show biomes on the map.

local gui = require('gui')
local widgets = require('gui.widgets')
local guidm = require('gui.dwarfmode')

local biomeTypeNames = {
    MOUNTAIN = "Mountain",
    GLACIER = "Glacier",
    TUNDRA = "Tundra",
    SWAMP_TEMPERATE_FRESHWATER = "Temperate Freshwater Swamp",
    SWAMP_TEMPERATE_SALTWATER = "Temperate Saltwater Swamp",
    MARSH_TEMPERATE_FRESHWATER = "Temperate Freshwater Marsh",
    MARSH_TEMPERATE_SALTWATER = "Temperate Saltwater Marsh",
    SWAMP_TROPICAL_FRESHWATER = "Tropical Freshwater Swamp",
    SWAMP_TROPICAL_SALTWATER = "Tropical Saltwater Swamp",
    SWAMP_MANGROVE = "Mangrove Swamp",
    MARSH_TROPICAL_FRESHWATER = "Tropical Freshwater Marsh",
    MARSH_TROPICAL_SALTWATER = "Tropical Saltwater Marsh",
    FOREST_TAIGA = "Taiga Forest",
    FOREST_TEMPERATE_CONIFER = "Temperate Conifer Forest",
    FOREST_TEMPERATE_BROADLEAF = "Temperate Broadleaf Forest",
    FOREST_TROPICAL_CONIFER = "Tropical Conifer Forest",
    FOREST_TROPICAL_DRY_BROADLEAF = "Tropical Dry Broadleaf Forest",
    FOREST_TROPICAL_MOIST_BROADLEAF = "Tropical Moist Broadleaf Forest",
    GRASSLAND_TEMPERATE = "Temperate Grassland",
    SAVANNA_TEMPERATE = "Temperate Savanna",
    SHRUBLAND_TEMPERATE = "Temperate Shrubland",
    GRASSLAND_TROPICAL = "Tropical Grassland",
    SAVANNA_TROPICAL = "Tropical Savanna",
    SHRUBLAND_TROPICAL = "Tropical Shrubland",
    DESERT_BADLAND = "Badland Desert",
    DESERT_ROCK = "Rock Desert",
    DESERT_SAND = "Sand Desert",
    OCEAN_TROPICAL = "Tropical Ocean",
    OCEAN_TEMPERATE = "Temperate Ocean",
    OCEAN_ARCTIC = "Arctic Ocean",
    POOL_TEMPERATE_FRESHWATER = "Temperate Freshwater Pool",
    POOL_TEMPERATE_BRACKISHWATER = "Temperate Brackishwater Pool",
    POOL_TEMPERATE_SALTWATER = "Temperate Saltwater Pool",
    POOL_TROPICAL_FRESHWATER = "Tropical Freshwater Pool",
    POOL_TROPICAL_BRACKISHWATER = "Tropical Brackishwater Pool",
    POOL_TROPICAL_SALTWATER = "Tropical Saltwater Pool",
    LAKE_TEMPERATE_FRESHWATER = "Temperate Freshwater Lake",
    LAKE_TEMPERATE_BRACKISHWATER = "Temperate Brackishwater Lake",
    LAKE_TEMPERATE_SALTWATER = "Temperate Saltwater Lake",
    LAKE_TROPICAL_FRESHWATER = "Tropical Freshwater Lake",
    LAKE_TROPICAL_BRACKISHWATER = "Tropical Brackishwater Lake",
    LAKE_TROPICAL_SALTWATER = "Tropical Saltwater Lake",
    RIVER_TEMPERATE_FRESHWATER = "Temperate Freshwater River",
    RIVER_TEMPERATE_BRACKISHWATER = "Temperate Brackishwater River",
    RIVER_TEMPERATE_SALTWATER = "Temperate Saltwater River",
    RIVER_TROPICAL_FRESHWATER = "Tropical Freshwater River",
    RIVER_TROPICAL_BRACKISHWATER = "Tropical Brackishwater River",
    RIVER_TROPICAL_SALTWATER = "Tropical Saltwater River",
    SUBTERRANEAN_WATER = "Subterranean Water",
    SUBTERRANEAN_CHASM = "Subterranean Chasm",
    SUBTERRANEAN_LAVA = "Subterranean Lava",
}

local function find(t, predicate)
    for k, item in pairs(t) do
        if predicate(k, item) then
            return k, item
        end
    end
    return nil
end

local biomesMap = {}
local biomeList = {}
local function gatherBiomeInfo()
    local maxX, maxY, maxZ = dfhack.maps.getTileSize()
    maxX = maxX - 1; maxY = maxY - 1; maxZ = maxZ - 1

    local z = df.global.window_z

    for y = 0, maxY do
        for x = 0, maxX do
            local rgnX, rgnY = dfhack.maps.getTileBiomeRgn(x,y,z)
            local biomeTypeId = dfhack.maps.getBiomeType(rgnX, rgnY)
            local biome = dfhack.maps.getRegionBiome(rgnX, rgnY)

            local biomesZ = biomesMap[z]
            if not biomesZ then
                biomesZ = {}
                biomesMap[z] = biomesZ
            end
            local biomesZY = biomesZ[y]
            if not biomesZY then
                biomesZY = {}
                biomesZ[y] = biomesZY
            end

            local function currentBiome(_, item)
                return item.biome == biome
            end
            local ix = find(biomeList, currentBiome)
            if not ix then
                local ch = string.char(string.byte('a') + #biomeList)
                table.insert(biomeList, {biome = biome, char = ch, typeId = biomeTypeId})
                ix = #biomeList
            end

            biomesZY[x] = ix
        end
    end
end

gatherBiomeInfo()

local TITLE = "Biomes"

BiomeVisualizerLegend = nil -- for debugging purposes
BiomeVisualizerLegend = defclass(BiomeVisualizerLegend, widgets.Window)
BiomeVisualizerLegend.ATTRS {
    frame_title=TITLE,
    frame_inset=0,
    resizable=true,
    autoarrange_subviews = true,
    autoarrange_gap = 1,
    frame = {
        w = 47,
        h = 10,
        l = 5,
        t = 8,
    },
}

local function GetBiomeName(biome, biomeTypeId)
    -- based on probe.cpp
    local sav = biome.savagery
    local evi = biome.evilness;
    local sindex = sav > 65 and 2 or sav < 33 and 0 or 1
    local eindex = evi > 65 and 2 or evi < 33 and 0 or 1
    local surr = sindex + eindex * 3 +1; --in Lua arrays are 1-based

    local surroundings = {
        "Serene", "Mirthful", "Joyous Wilds",
        "Calm", "Wilderness", "Untamed Wilds",
        "Sinister", "Haunted", "Terrifying"
    }
    local surrounding = surroundings[surr]

    local name = biomeTypeNames[df.biome_type[biomeTypeId]] or "DFHACK_Unknown"

    return ([[%s %s]]):format(surrounding, name)
end

function BiomeVisualizerLegend:init()
    self:addviews{
        widgets.List{
            view_id = 'list',
            frame = { t = 0 },
            text_pen = { fg = COLOR_GREY, bg = COLOR_BLACK },
            --cursor_pen = { fg = COLOR_BLACK, bg = COLOR_GREEN },
            --on_select = self:callback('onSelectEntry'),
        },
    }

    local choices = {}
    for _, biomeExt in ipairs(biomeList) do
        table.insert(choices, {
            text = ([[%s: %s]]):format(biomeExt.char, GetBiomeName(biomeExt.biome, biomeExt.typeId)),
            biomeTypeId = biomeExt.typeId,
        })
    end
    self.subviews.list:setChoices(choices)
end

BiomeVisualizer = defclass(BiomeVisualizer, gui.ZScreen)
BiomeVisualizer.ATTRS{
    focus_path='BiomeVisualizer',
}

local function getMapViewBounds()
    local dims = dfhack.gui.getDwarfmodeViewDims()
    local x = df.global.window_x
    local y = df.global.window_y
    return {x1 = dims.map_x1 + x,
            y1 = dims.map_y1 + y,
            x2 = dims.map_x2 + x,
            y2 = dims.map_y2 + y,
    }
end

function BiomeVisualizer:init()
    self:addviews{BiomeVisualizerLegend{}}
end

function BiomeVisualizer:onRenderFrame(dc, rect)
    BiomeVisualizer.super.onRenderFrame()

    local function get_overlay_pen(pos)
        local safe_index = safe_index
        -- 304 = `0`, 353 = `a`
        local idxBaseTile = 353
        local biomes = biomesMap

        local N = safe_index(biomes, pos.z, pos.y, pos.x)
        if not N then return end
        return COLOR_RED, tostring(N), idxBaseTile + (N - 1)
    end
    local overlay_bounds = getMapViewBounds()

    guidm.renderMapOverlay(get_overlay_pen, overlay_bounds)
end

function BiomeVisualizer:onDismiss()
    view = nil
end

view = view and view:raise() or BiomeVisualizer{}:show()
