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
challenge remains fun, commensurate with your dwarves' current activities, and
not overwhelming.

In short, this mod changes agitation attacks from a constant flood to a system
that is responsive to your recent actions on the surface and in the caverns.
If you irritate the natural environment past a threshold, you will be attacked
exactly once. You will not be attacked further unless you continue to
antagonize nature. This mod can be enabled (and auto-started for new forts, if
desired) on the "Gameplay" tab of `gui/control-panel`.

Usage
-----

::

    enable agitation-rebalance
    agitation-rebalance [status]
    agitation-rebalance preset <name>
    agitation-rebalance enable|disable <feature>

When run without arguments or with the ``status`` argument, it will print out
whether it is enabled, the current configuration, and how many agitated
creatures and (visible) cavern invaders are on the map.

The `Presets`_ allow you to quickly set the game irritation difficulty settings
to tested, balanced values. You can adjust them further (or set your own values)
on the DF difficulty settings screen. Note that ``agitation-rebalance preset``
can be used to set the difficulty settings even if the mod is not enabled.

Finally, some features of the mod can be individually enabled or disabled. More
details in the `Features`_ section below.

Examples
--------

``agitation-rebalance preset lenient``
    Load the ``lenient`` preset, which allows for a fair amount of tree cutting
    and other activity between attacks. This preset is loaded automatically if
    you have the "Enemies" settings at their default "Normal" values.

``enable agitation-rebalance``
    Manually enable the mod (not needed if you are using `gui/control-panel`)

How the DF agitation system works
---------------------------------

For the surface wilderness, the DF agitation system works by maintaining a
counter. Your dwarves increase the counter when they chop down trees or catch
fish. Once it crosses a threshold, wildlife that enters the map will be
agitated and will aggressively attack your units. Once a year, the counter is
decremented by a fixed amount. This means that once you cross the threshold
that starts the agitation attacks, you will suffer near-constant retribution
until you stop all tree cutting and fishing on the surface for years until the
counter fall lows enough again.

DF also maintains counters for each cavern layer, but instead of attacks
starting when the counter crosses a threshold, larger values of the counter
represent a larger *chance* of an invasion (randomized and checked once per
season). This counter also affects the chance of a forgotten beasts attack. The
cavern irritation counter is increased for tree felling and fishing within the
cavern's area. Moreover, doing anything that makes noise will increase the
irritation level further. Responding to invaders in the caverns makes noise,
which leads to a cycle of invasions that never ends. You can wall off the
caverns, but then invaders will continue to build up and their sheer numbers
will start impacting your FPS. The irritation counters for the cavern layers do
not decay over time, so once attacks begin, they will not stop.

There are five variables that affect the behavior of this system, all
customizable in the DF difficulty settings:

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
    "Normal" vanilla preset) or 100 (if initialized by the "Hard" vanilla
    preset).
``Cavern dweller maximum attackers``
    This controls the maximum number of cavern invaders that can spawn in a
    single invasion. The number of invaders in the caverns can grow beyond this
    number if the invaders from a previous invasion are still alive.
``Cavern dweller scale``
    This affects how many more units a cavern invasion can have in comparison
    to the previous invasion in that cavern.

What does this mod do?
----------------------

When enabled, this mod makes the following changes:

When you get an agitation-triggered incursion on the surface, the surface
irritation counter is immediately decremented below the
``Wilderness irritation minimum``. This means that the incursions act more like
a warning shot than an open floodgate. You will not be attacked again unless
you continue your activities on the surface so that the counter once again
exceeds the ``Wilderness sensitivity`` value. The further apart these settings
are, the longer it will take to suffer a second attack. For reference, each
tree chopped adds 100 to the counter, so a ``Wilderness irritation minimum``
value of 3500 and a ``Wilderness sensitivity`` value of 4000 will allow you to
initially chop 40 trees before being attacked by agitated creatures, at which
point the counter will be set to 3500 and you can chop 5 more trees until you
get attacked again. If you cross a year boundary, then you will have additional
leniency granted by the ``Wilderness irritation decay`` value (if it is set to
a value greater than zero).

For the caverns, the irritation counters behave differently, so we use a
different method to modify the behavior of cavern invasions. When a cavern
attack begins, we record the current irritation counter value. Any further
attacks will be prevented until the counter increments past a higher threshold.
That threshold is equal to the saved irritation counter value plus the
difference between the ``Wilderness sensitivity`` and
``Wilderness irritation minimum`` difficulty setting values. This makes cavern
agitation behave similarly to surface agitation. The frequency of forgotten
beast attacks, which is also affected by cavern irritation, is unchanged by
this mod.

Finally, if you have walled yourself off from the danger in the caverns, yet
continue to irritate nature down there, this mod will ensure that the number of
active cavern invaders across all cavern levels never exeeds the value set for
``Cavern dweller maximum attackers``. This prevents excessive FPS loss during
gameplay and keeps the number of creatures milling around outside your gates to
a reasonable number.

Presets
-------

The tree counts in these presets are only estimates. There are other actions
that contribute to irritation, like fishing. :wiki:`Noise` also contributes to
irritation in the caverns.

``casual``
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
difficulty settings and adjust them further to your liking.

If the ``auto-preset`` feature is enabled and the difficulty settings exactly
match any of the vanilla "Enemies" presets when the mod is enabled, a
corresponding mod preset will be loaded. See the `Features`_ section below for
details.

Note that if you have `gui/settings-manager` auto-restoring your difficulty
settings for new forts, you don't have to reload these presets yourself. Just
be sure to save your settings on the DFHack-added panel on the DF difficulty
settings screen so they can be auto-restored later.

Features
--------

Features of the mod can be individually enabled or disabled. All features are
enabled by default. Available features are:

``auto-preset``
    Auto-load a preset based on which vanilla "Enemies" preset is active:
    - "Off" loads the "casual" preset
    - "Normal" loads the "lenient" preset
    - "Hard" loads the "strict" preset
    This feature takes effect at the time when the mod is enabled, so if you
    don't want your default vanilla settings changed, be sure to disable this
    feature before enabling ``agitation-rebalance``.
``surface``
    Manage surface agitated wildlife frequency.
``cavern``
    Manage cavern invasion frequency.
``cap-invaders``
    Ensure the number of active invaders per cavern does not exceed the
    configured maximum.
