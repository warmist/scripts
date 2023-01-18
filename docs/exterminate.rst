exterminate
===========

.. dfhack-tool::
    :summary: Kills creatures.
    :tags: fort armok units

Kills any unit, or all units of a given race. You can target any unit on a
revealed tile of the map, including ambushers, but caged/chained creatures are
ignored.

If ``method`` is specified, ``exterminate`` will kill the selected units
using the provided method. ``Instant`` will instantly kill the units.
``Butcher`` will mark the units for butchering, not kill them, useful for pets
and not for armed enemies. ``Drown`` and ``Magma`` will spawn a 7/7 column of
water or magma on the units respectively, cleaning up the liquid as they move
and die. Magma not recommended for magma-safe creatures...

Usage
-----

``exterminate``
    List the available targets.
``exterminate this [--method <method>] [--only-visible] [--only-hostile]``
    Kills the selected unit, instantly by default.
``exterminate <race>[:<caste>] [--method <method>] [--only-visible] [--only-hostile]``
    Kills all available units of the specified race, or all undead units.

Examples
--------

``exterminate this``
    Kill the selected unit.
``exterminate``
    List the targets on your map.
``exterminate BIRD_RAVEN:MALE``
    Kill the ravens flying around the map (but only the male ones).
``exterminate GOBLIN --method MAGMA --only-visible --only-hostile``
    Kill all visible, hostile goblins on the map by drowning them in magma.

Options
-------

``--method <method>``
    Specifies the "method" of killing units. See ``exterminate --help`` for a
    list of possible methods.
``--only-visible``
    Specifies the tool should only kill units that are visible to the player
    on the map.
``--only-hostile``
    Specifies the tool should only kill units that are hostile to the player.

Technical details
-----------------

This tool kills by setting a unit's ``blood_count`` to 0, which means
immediate death at the next game tick. For creatures where this is not enough,
such as vampires, it also sets animal.vanish_countdown to 2.

The script drowns units in the liquid of choice by modifying the tile with a
liquid level of 7 every tick, and watching for changes in the units' positions
cleaning up the liquids in the previous tiles.
