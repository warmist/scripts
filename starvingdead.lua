-- Weaken and eventually destroy undead over time.

local argparse = require('argparse')

StarvingDead = defclass(StarvingDead)
StarvingDead.ATTRS{
  decay_rate = 1,
  death_threshold = 6
}

function StarvingDead:init()
  self.timeout_id = nil
  -- Percentage goal each attribute should reach before death.
  self.attribute_goal = 10
  self.attribute_decay = (self.attribute_goal ^ (1 / ((self.death_threshold * 28 / self.decay_rate)))) / 100
  self.undead_count = 0

  self:checkDecay()
  print(([[StarvingDead started, checking every %s days and killing off at %s months]]):format(self.decay_rate, self.death_threshold))
end

function StarvingDead:checkDecay()
  self.undead_count = 0
  for _, unit in pairs(df.global.world.units.active) do
    if (unit.enemy.undead and not unit.flags1.inactive) then
      self.undead_count = self.undead_count + 1

      -- time_on_site is measured in ticks, a month is 33600 ticks.
      -- @see https://dwarffortresswiki.org/index.php/Time
      for _, attribute in pairs(unit.body.physical_attrs) do
        attribute.value = math.floor(attribute.value - (attribute.value * self.attribute_decay))
      end

      if unit.curse.time_on_site > (self.death_threshold * 33600) then
        unit.flags1.inactive = true
        unit.curse.rem_tags2.FIT_FOR_ANIMATION = true
      end
    end
  end

  self.timeout_id = dfhack.timeout(self.decay_rate, 'days', self:callback('checkDecay'))
end

if not dfhack.isMapLoaded() then
  qerror('This script requires a fortress map to be loaded')
end

local options, args = {
  decay_rate = 1,
  death_threshold = 6
}, {...}

local positionals = argparse.processArgsGetopt(args, {
  {'h', 'help', handler = function() options.help = true end},
  {'r', 'decay-rate', hasArg = true, handler=function(arg) options.decay_rate = argparse.positiveInt(arg, 'decay-rate') end },
  {'t', 'death-threshold', hasArg = true, handler=function(arg) options.death_threshold = argparse.positiveInt(arg, 'death-threshold') end },
})

if positionals[1] == "help" or options.help then
  return print(dfhack.script_help())
end

if positionals[1] == "stop" then
  if not starvingDeadInstance then
    qerror("StarvingDead is not running!")
  end

  dfhack.timeout_active(starvingDeadInstance.timeout_id, nil)
  starvingDeadInstance = nil
end

if positionals[1] == "start" then
  if starvingDeadInstance then
    print("Stopping previous instance of StarvingDead...")
    dfhack.timeout_active(starvingDeadInstance.timeout_id, nil)
  end

  starvingDeadInstance = StarvingDead{options.decay_rate, options.death_threshold}
end
