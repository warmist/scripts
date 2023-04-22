modtools/create-item
====================

.. dfhack-tool::
    :summary: Create arbitrary items.
    :tags: dev

This tool provides a commandline interface for creating items of your choice.

Usage
-----

::

    modtools/create-item <options>

Examples
--------

``modtools/create-item -u 23145 -i WEAPON:ITEM_WEAPON_PICK -m INORGANIC:IRON -q4``
    Have unit 23145 create an exceptionally crafted iron pick.
``modtools/create-item -u 323 -i CORPSEPIECE:NONE -m CREATURE_MAT:DWARF:BRAIN``
    Have unit 323 produce a lump of brain.
``modtools/create-item -i BOULDER:NONE -m INORGANIC:RAW_ADAMANTINE -c 5``
    Spawn 5 raw adamantine boulders.
``modtools/create-item -i DRINK:NONE -m PLANT:MUSHROOM_HELMET_PLUMP:DRINK``
    Spawn a barrel of dwarven ale.

Options
-------

``-u``, ``--unit <id>`` (default: first citizen)
    The ID of the unit to use as the item's creator. You can also pass the
    string "\\LAST" to use the most recently created unit.
``-i``, ``--item <itemdef>`` (required)
    The def string of the item you want to create.
``-m``, ``--material`` (required)
    That def string of the material you want the item to be made out of.
``-q``, ``--quality`` (default: ``0``, which is ``df.item_quality.Ordinary``)
    The quality of the created item.
``-d``, ``--description`` (required if you are creating a slab)
    The text that will be engraved on the created slab.
``-c``, ``--count`` (default: ``1``)
    The number of items to create. If the item is stackable, this will be the
    stack size.
