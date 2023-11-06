-- Overlay to allow changing track stop friction and dump direction after construction
--@ module = true
local gui = require('gui')
local widgets = require('gui.widgets')
local overlay = require('plugins.overlay')

local NORTH = 'North'
local EAST = 'East'
local SOUTH = 'South'
local WEST = 'West'

local LOW = 'Low'
local MEDIUM = 'Medium'
local HIGH = 'High'
local MAX = 'Max'

local NONE = 'None'

local FRICTION_MAP = {
  [NONE] = 10,
  [LOW] = 50,
  [MEDIUM] = 500,
  [HIGH] = 10000,
  [MAX] = 50000,
}

local FRICTION_MAP_REVERSE = {}
for k, v in pairs(FRICTION_MAP) do
  FRICTION_MAP_REVERSE[v] = k
end

TrackStopOverlay = defclass(TrackStopOverlay, overlay.OverlayWidget)
TrackStopOverlay.ATTRS{
  default_pos={x=-71, y=29},
  default_enabled=true,
  viewscreens='dwarfmode/ViewSheets/BUILDING/Trap',
  frame={w=27, h=4},
  frame_style=gui.MEDIUM_FRAME,
  frame_background=gui.CLEAR_PEN,
}

function TrackStopOverlay:getFriction()
  return dfhack.gui.getSelectedBuilding().friction
end

function TrackStopOverlay:setFriction(friction)
  local building = dfhack.gui.getSelectedBuilding()

  building.friction = FRICTION_MAP[friction]
end

function TrackStopOverlay:getDumpDirection()
  local building = dfhack.gui.getSelectedBuilding()
  local use_dump = building.use_dump
  local dump_x_shift = building.dump_x_shift
  local dump_y_shift = building.dump_y_shift

  if use_dump == 0 then
    return NONE
  else
    if dump_x_shift == 0 and dump_y_shift == -1 then
      return NORTH
    elseif dump_x_shift == 1 and dump_y_shift == 0 then
      return EAST
    elseif dump_x_shift == 0 and dump_y_shift == 1 then
      return SOUTH
    elseif dump_x_shift == -1 and dump_y_shift == 0 then
      return WEST
    end
  end
end

function TrackStopOverlay:setDumpDirection(direction)
  local building = dfhack.gui.getSelectedBuilding()

  if direction == NONE then
    building.use_dump = 0
    building.dump_x_shift = 0
    building.dump_y_shift = 0
  elseif direction == NORTH then
    building.use_dump = 1
    building.dump_x_shift = 0
    building.dump_y_shift = -1
  elseif direction == EAST then
    building.use_dump = 1
    building.dump_x_shift = 1
    building.dump_y_shift = 0
  elseif direction == SOUTH then
    building.use_dump = 1
    building.dump_x_shift = 0
    building.dump_y_shift = 1
  elseif direction == WEST then
    building.use_dump = 1
    building.dump_x_shift = -1
    building.dump_y_shift = 0
  end
end

function TrackStopOverlay:render(dc)
  if not self:shouldRender() then
    return
  end

  local building = dfhack.gui.getSelectedBuilding()
  local friction = building.friction
  local friction_cycle = self.subviews.friction

  friction_cycle:setOption(FRICTION_MAP_REVERSE[friction])

  self.subviews.dump_direction:setOption(self:getDumpDirection())

  TrackStopOverlay.super.render(self, dc)
end

function TrackStopOverlay:shouldRender()
  local building = dfhack.gui.getSelectedBuilding()
  return building and building.trap_type == df.trap_type.TrackStop
end

function TrackStopOverlay:onInput(keys)
  if not self:shouldRender() then
    return
  end
  TrackStopOverlay.super.onInput(self, keys)
end

function TrackStopOverlay:init()
  self:addviews{
    widgets.Label{
      frame={t=0, l=0},
      text='Dump',
    },
    widgets.CycleHotkeyLabel{
      frame={t=0, l=9},
      key='CUSTOM_CTRL_X',
      options={NONE, NORTH, EAST, SOUTH, WEST},
      view_id='dump_direction',
      on_change=function(val) self:setDumpDirection(val) end,
    },
    widgets.Label{
      frame={t=1, l=0},
      text='Friction',
    },
    widgets.CycleHotkeyLabel{
      frame={t=1, l=9},
      key='CUSTOM_CTRL_F',
      options={NONE, LOW, MEDIUM, HIGH, MAX},
      view_id='friction',
      on_change=function(val) self:setFriction(val) end,
    },
  }
end

OVERLAY_WIDGETS = {
  trackstop=TrackStopOverlay
}

if not dfhack_flags.module then
  main{...}
end
