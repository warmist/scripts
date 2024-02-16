agitation-rebalance
===================

.. dfhack-tool::
    :summary: Rebalance agitation mechanics.
    :tags: fort gameplay

The DF agitation (or "irritation") system gives you challenges to face when
your dwarves impact the natural environment. It adds new depth to gameplay, but
it can also quickly drag the game down, both with constant incursions of
agitated animals and with FPS-killing massive buildups of invisible invaders in
the caverns. This mod changes how the agitation system behaves to ensure the
challenge remains fun and not overwhelming.

The DF agitation system works by maintaining a counter for the surface and each
cavern layer. Your dwarves' activities can increase the counters when they do
things on those layers, like chopping down trees or making noise. Every year,
the counters are decremented by a fixed amount. This means that once you cross
the threshold that starts the attacks, you will suffer near-constant
retribution, at least until the next year. In the caverns, responding to the
invaders makes noise, which increases the counter further, leading to a cycle
of invasions that never ends. You can wall off the caverns and wait for the
counter to subside, but then invaders will continue to build up and start
impacting your FPS.

There are three DF difficulty settings that affect the behavior of this system:

- When the irritation counter exceeds the ``Wilderness sensitivity`` value,
  attacks from agitated wilderness creatures begin on the surface.
- When the irritation counter falls below the ``Wilderness irritation minimum``
  value, surface attacks stop.
- The ``Wilderness irritation decay`` is the amount that the counters decrease
  per year, regardless of activity. Due to a bug in DF, the widget for this
  setting always displays and controls the value for
  ``Wilderness irritation minimum`` and thus cannot be changed from its default
  value of 500 (if initialized by the "Normal" preset) or 100 (if initialized
  by the "Hard" preset).

When enabled, this mod makes the following changes:

When you get an agitation-triggered incursion, the related agitation counter is
immediately decremented below the ``Wilderness irritation minimum``. This means
that the incursions act more like a warning shot than an open floodgate. You
will not be attacked again unless you continue your activities on that layer so
that the counter once again exceeds the ``Winderness sensitivity`` value. You
can set these thresholds in the DF difficulty settings to your liking. The
further apart they are, the longer it will take to suffer a second attack. For
reference, each tree chopped adds 100 to the counter, so a
``Wilderness irritation minimum`` value of 3500 and a
``Winderness sensitivity`` value of 4000 will allow you to initially chop 40
trees before being attacked by agitated creatures, at which the counter will be
set to 3500 and you can chop 5 more trees until you get attacked again. If you
cross a year boundary, then you will have additional leniency granted by the
``Wilderness irritation decay`` value (if it is greater than zero).

The counters for cavern layers are not thresholds, but rather represent the
*liklihood* that a cavern invasion will begin. The counter for a layer will be
reset to 0 when an invasion beings in that layer. This makes it less likely
that a second invasion will occur quickly after the first unless you continue
to disturb that cavern layer.

Finally, if you have walled yourself off from the danger in the caverns, yet
continue to agitate nature down there, this mod will ensure that the number of
creatures that spawn does not exceed the value for
``Cavern dweller maximum attackers`` set in the DF difficulty settings. This
prevents excessive FPS loss during gameplay and keeps the number of creatures
milling around outside your gates to a reasonable number. Note that the maximum
is enforced **per cavern layer**, not cumulative across all cavern layers.

This mod can be enabled (and auto-started for new forts, if desired) on the
"Gameplay" tab of `gui/control-panel`.

Usage
-----

::

    enable agitation-rebalance
    agitation-rebalance [status]
    agitation-rebalance preset <name>
    agitation-rebalance enable|disable <feature>

When run without arguments or with the ``status`` argument, it will print out
whether it is enabled and how many agitated creatures and (visible) cavern
invaders are on the map.

The presets allow you to quickly set the game irritation difficulty settings to
tested, balanced values. Note that ``agitation-rebalance preset`` can be used
to set difficulty with vanilla mechanics even if the mod is not enabled.

Finally some features of the mod can be individually enabled or disabled. More
details below.

Presets
-------

Note that the tree counts in the presets are only estimates. There are other
actions that contribute to agitation, like fishing and hunting.

``off``
    - Trees until first invasion: 1000
    - Additional trees between invasions: 1000
    - Additional trees per year: 1000
    - Max invaders per cavern: 0
``lenient``
    - Trees until first invasion: 40
    - Additional trees between invasions: 20
    - Additional trees per year: 50
    - Max invaders per cavern: 20
``strict``
    - Trees until first invasion: 10
    - Additional trees between invasions: 5
    - Additional trees per year: 10
    - Max invaders per cavern: 100
``insane``
    - Trees until first invasion: 5
    - Additional trees between invasions: 1
    - Additional trees per year: 1
    - Max invaders per cavern: 500

After using one of these presets, remember you can always to go the vanilla
difficulty settings and adjust them to your liking.

Features
--------

Features of the mod can be individually enabled or disabled. Available features are:

``surface``
    Reset surface irritation values to minimum thresholds when agitated
    wilderness creatures enter the map.
``cavern``
    Reset cavern irritation values to 0 when cavern invasions are triggered.
``cap-invaders``
    Ensure the number of active cavern invaders per cavern does not exceed the
    configured maximum.
