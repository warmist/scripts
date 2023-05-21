local gui = require('gui')
local widgets = require('gui.widgets')

---------------------
-- Sandbox
--

Sandbox = defclass(Sandbox, widgets.Window)
Sandbox.ATTRS {
    frame_title='Arena Sandbox',
    frame={r=2, t=18, w=40, h=10},
}

function Sandbox:init()
    self:addviews{
        widgets.WrappedLabel{
            text_to_wrap='Use the buttons at the bottom of the screen to create units, trees, or fluids. \n\nClose this window to return to your fort.'
        }
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
    pass_movement_keys=true,
}

function SandboxScreen:init()
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

    df.global.gametype = df.game_type.DWARF_ARENA

    self:addviews{Sandbox{}}
end

function SandboxScreen:onDismiss()
    df.global.gametype = df.game_type.DWARF_MAIN
    view = nil
end

if df.global.gametype ~= df.game_type.DWARF_MAIN then
    qerror('must have a fort loaded')
end

view = view and view:raise() or SandboxScreen{}:show()
