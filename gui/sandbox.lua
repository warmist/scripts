local gui = require('gui')
local makeown = reqscript('makeown')
local widgets = require('gui.widgets')

local DISPOSITIONS = {
    HOSTILE = 1,
    WILD = 2,
    FRIENDLY = 3,
    FORT = 4,
}

---------------------
-- Sandbox
--

Sandbox = defclass(Sandbox, widgets.Window)
Sandbox.ATTRS {
    frame_title='Arena Sandbox',
    frame={r=2, t=18, w=40, h=15},
    autoarrange_subviews=true,
}

function Sandbox:init()
    self:addviews{
        widgets.WrappedLabel{
            frame={l=0},
            text_to_wrap='Use the buttons at the bottom of the screen to create units, trees, or fluids. \n\nClick on this window to focus and then right click to close and return to your fort.'
        },
        widgets.Panel{frame={h=1}},
        widgets.WrappedLabel{
            frame={l=0},
            text_pen=COLOR_GREY,
            text_to_wrap='When returning to fort mode, mark created units as:'
        },
        widgets.CycleHotkeyLabel{
            view_id='disposition',
            frame={l=0},
            key='CUSTOM_SHIFT_D',
            key_back='CUSTOM_SHIFT_A',
            options={
                {label='hostile', value=DISPOSITIONS.HOSTILE, pen=COLOR_RED},
                {label='independent/wild', value=DISPOSITIONS.WILD, pen=COLOR_YELLOW},
                {label='friendly', value=DISPOSITIONS.FRIENDLY, pen=COLOR_GREEN},
                {label='citizens/pets', value=DISPOSITIONS.FORT, pen=COLOR_BLUE},
            },
        },
    }
end

function Sandbox:onInput(keys)
    if keys.LEAVESCREEN or keys._MOUSE_R_DOWN then
        -- close any open UI elements
        df.global.game.main_interface.arena_unit.open = false
        df.global.game.main_interface.arena_tree.open = false
        df.global.game.main_interface.bottom_mode_selected = -1
    end
    return Sandbox.super.onInput(self, keys)
end

---------------------
-- SandboxScreen
--

SandboxScreen = defclass(SandboxScreen, gui.ZScreen)
SandboxScreen.ATTRS {
    focus_path='sandbox',
    force_pause=true,
}

local function init_arena()
    local arena = df.global.world.arena
    local arena_unit = df.global.game.main_interface.arena_unit
    local arena_tree = df.global.game.main_interface.arena_tree

    -- races
    arena.race:resize(0)
    arena.caste:resize(0)
    arena.creature_cnt:resize(0)
    arena.type = -1
    arena_unit.race = 0
    arena_unit.caste = 0
    arena_unit.races_filtered:resize(0)
    arena_unit.races_all:resize(0)
    arena_unit.castes_filtered:resize(0)
    arena_unit.castes_all:resize(0)
    for i, cre in ipairs(df.global.world.raws.creatures.all) do
        arena.creature_cnt:insert('#', 0)
        for caste in ipairs(cre.caste) do
            -- the real interface sorts these alphabetically
            arena.race:insert('#', i)
            arena.caste:insert('#', caste)
        end
    end

    -- interactions
    arena.interactions:resize(0)
    arena.interaction = -1
    arena_unit.interactions:resize(0)
    arena_unit.interaction = -1
    for _, inter in ipairs(df.global.world.raws.interactions) do
        for _, effect in ipairs(inter.effects) do
            if #effect.arena_name > 0 then
                arena.interactions:insert('#', effect)
            end
        end
    end

    -- skills
    arena.skills:resize(0)
    arena.skill_levels:resize(0)
    arena_unit.skills:resize(0)
    arena_unit.skill_levels:resize(0)
    for i in ipairs(df.job_skill) do
        if i >= 0 then
            arena.skills:insert('#', i)
            arena.skill_levels:insert('#', 0)
        end
    end

    -- trees
    arena.tree_types:resize(0)
    arena.tree_age = 100
    arena_tree.tree_types_filtered:resize(0)
    arena_tree.tree_types_all:resize(0)
    arena_tree.age = 100
    for _, tree in ipairs(df.global.world.raws.plants.trees) do
        arena.tree_types:insert('#', tree)
    end
end

local function is_sentient(unit)
    local caste_flags = unit.enemy.caste_flags
    return caste_flags.CAN_SPEAK or caste_flags.CAN_LEARN
end

local function finalize_sentient(unit, disposition)

    if disposition == DISPOSITIONS.HOSTILE then
        unit.flags1.marauder = true;
    elseif disposition == DISPOSITIONS.WILD then
        unit.flags2.visitor = true
        unit.flags3.guest = true
        unit.animal.leave_countdown = 20000
    elseif disposition == DISPOSITIONS.FRIENDLY then
        -- noop; units are created friendly by default
    elseif disposition == DISPOSITIONS.FORT then
        makeown.make_own(unit)
    end
end

local function finalize_animal(unit, disposition)
    if disposition == DISPOSITIONS.HOSTILE then
        unit.flags1.active_invader = true;
        unit.flags1.marauder = true;
        unit.flags4.agitated_wilderness_creature = true
    elseif disposition == DISPOSITIONS.WILD then
        unit.flags2.roaming_wilderness_population_source = true
        unit.flags2.roaming_wilderness_population_source_not_a_map_feature = true
        unit.animal.leave_countdown = 20000
    elseif disposition == DISPOSITIONS.FRIENDLY then
        -- noop; units are created friendly by default
    elseif disposition == DISPOSITIONS.FORT then
        makeown.make_own(unit)
        unit.flags1.tame = true
        unit.training_level = df.animal_training_level.Domesticated
    end
end

local function finalize_units(first_created_unit_id, disposition)
    print(first_created_unit_id, disposition)
    -- unit->flags4.bits.agitated_wilderness_creature
    for unit_id=first_created_unit_id,df.global.unit_next_id-1 do
        local unit = df.unit.find(unit_id)
        if not unit then goto continue end
        unit.profession = df.profession.STANDARD
        unit.name.has_name = false
        if is_sentient(unit) then
            finalize_sentient(unit, disposition)
        else
            finalize_animal(unit, disposition)
        end
        ::continue::
    end
end

function SandboxScreen:init()
    self.first_created_unit_id = df.global.unit_next_id

    init_arena()

    self:addviews{Sandbox{}}

    df.global.gametype = df.game_type.DWARF_ARENA
end

function SandboxScreen:onDismiss()
    df.global.gametype = df.game_type.DWARF_MAIN
    view = nil
    finalize_units(self.first_created_unit_id,
            self.subviews.disposition:getOptionValue())
end

if df.global.gametype ~= df.game_type.DWARF_MAIN then
    qerror('must have a fort loaded')
end

view = view and view:raise() or SandboxScreen{}:show()
