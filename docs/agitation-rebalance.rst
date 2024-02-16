agitation-rebalance
===================

.. dfhack-tool::
    :summary: Rebalance agitation mechanics.
    :tags: fort gameplay

The DF agitation (or "irritation") system gives you challenges to face when
your dwarves impact the natural environment. It adds new depth to gameplay, but
it can also quickly drag the game down, both with constant incursions of
agitated animals and with FPS-killing massive buildups of hidden invaders in
the caverns. This mod changes how the agitation system behaves to ensure the
challenge remains fun and not overwhelming.

For the surface, the DF agitation system works by maintaining a counter. Your
dwarves increase the counter when they chop down trees or catch fish. Once a
year, the counter is decremented by a fixed amount. This means that once you
cross the threshold that starts the agitation attacks, you will suffer
near-constant retribution, at least until the next year.

DF also maintains counters for each cavern layer, but instead of attacks
starting when the counter crosses a threshold, larger values of the counter
represent a larger *chance* of an invasion (checked once per season). The
cavern irritation counter is increased for tree felling and fishing within the
cavern's area. Moreover, doing anything that makes noise will increase the
irritation level further. Responding to invaders in the caverns makes noise,
which leads to a cycle of invasions that never ends. You can wall off the
caverns, but then invaders will continue to build up and their sheer numbers
will start impacting your FPS. The irritation counters for the cavern layers do
not decay over time.

There are five DF difficulty settings that affect the behavior of this system:

``Wilderness sensitivity``
    When the irritation counter exceeds this value, attacks from agitated
    wilderness creatures begin on the surface.
``Wilderness irritation minimum``
    When the irritation counter falls below this value, surface attacks stop.
``Wilderness irritation decay``
    This is the amount that the surface irritation counter decreases per year,
    regardless of activity. Due to a bug in DF, the widget for this setting in
    the difficulty settings panel always displays and controls the value for
    ``Wilderness irritation minimum`` and thus the setting cannot be changed in
    the vanilla interface from its default value of 500 (if initialized by the
    "Normal" preset) or 100 (if initialized by the "Hard" preset).
``Cavern dweller maximum attackers``
    This controls the maximum number of cavern invaders that can spawn in a
    single invasion. The number of invaders in the caverns can grow beyond this
    number if the invaders from the previous invasion are still alive.
``Cavern dweller scale``
    This affects how many more members a cavern invasion can have in comparison
    to the previous invasion in that cavern.

When enabled, this mod makes the following changes:

When you get an agitation-triggered incursion on the surface, the surface
irritation counter is immediately decremented below the
``Wilderness irritation minimum``. This means that the incursions act more like
a warning shot than an open floodgate. You will not be attacked again unless
you continue your activities on that layer so that the counter once again
exceeds the ``Wilderness sensitivity`` value. You can set these thresholds in
the DF difficulty settings to your liking. The further apart they are, the
longer it will take to suffer a second attack. For reference, each tree chopped
adds 100 to the counter, so a ``Wilderness irritation minimum`` value of 3500
and a ``Wilderness sensitivity`` value of 4000 will allow you to initially chop
40 trees before being attacked by agitated creatures, at which point the
counter will be set to 3500 and you can chop 5 more trees until you get
attacked again. If you cross a year boundary, then you will have additional
leniency granted by the ``Wilderness irritation decay`` value (if it is set to
a value greater than zero).

For the caverns, the counter for the respective layer will be reset to 0 when
an attack begins. This makes it less likely that a second invasion will occur
quickly after the first unless you continue to disturb that cavern layer.

Finally, if you have walled yourself off from the danger in the caverns, yet
continue to agitate nature down there, this mod will ensure that the number of
creatures that spawn never exceeds the value for
``Cavern dweller maximum attackers``. This prevents excessive FPS loss during
gameplay and keeps the number of creatures milling around outside your gates to
a reasonable number. Note that the maximum is enforced **per cavern layer**,
not cumulative across all cavern layers.

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
actions that contribute to agitation, like fishing.

``off``
    - Trees until first invasion: 1000
    - Additional trees between invasions: 1000
    - Additional trees per year: 1000
    - Max invaders per cavern: 0
``lenient``
    - Trees until first invasion: 100
    - Additional trees between invasions: 25
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
