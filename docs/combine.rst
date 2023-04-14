combine
=======

.. dfhack-tool::
    :summary: Combine stacks of food and plants.
    :tags: fort productivity items plants stockpiles

Usage
-----

::

    combine (all|here) [<options>]

Examples
--------
``combine``
    Displays help
``combine all --dry-run``
    Preview stack changes for all types in all stockpiles.
``combine all``
    Merge stacks for all stockpile and all types
``combine all --types=meat,plant``
    Merge ``meat`` and ``plant`` type stacks in all stockpiles.
``combine here``
    Merge stacks in stockpile located at game cursor.

Commands
--------
``all``
    Search all stockpiles.
``here``
    Search the stockpile under the game cursor.

Options
-------
``-h``, ``--help``
    Prints help text. Default if no options are specified.
``-d``, ``--dry-run``
    Display the stack changes without applying them.
``-t``, ``--types <comma separated list of types>``
    Filter item types. Default is ``all``. Valid types are:

        ``all``:   all of the types listed here.

        ``ammo``: AMMO

        ``drink``: DRINK

        ``fat``:   GLOB and CHEESE

        ``fish``:  FISH, FISH_RAW and EGG

        ``food``:  FOOD

        ``meat``:  MEAT

        ``plant``: PLANT and PLANT_GROWTH

        ``powders``: POWDERS_MISC

        ``seeds``: SEEDS

``-q``, ``--quiet``
    Only print changes instead of a summary of all processed stockpiles.
    
``-v``, ``--verbose n``
    Print verbose output, n from 1 to 4.

Notes
-----
The following conditions prevent an item from being combined:
1. An item is not in a stockpile.
2. An item is sand or plaster.
3. An item is rotten, forbidden/hidden, marked for dumping/melting, 
on fire, encased, owned by a trader/hostile/dwarf or is in a spider web.

The following categories are used for combining:
1. Item has a race/caste: category=type + race + caste
2. Item is ammo, created by for masterwork. category=type + material + quality (+ created by)
3. Or: category= type + material

A default stack size of 30 applies to a category, unless a larger stack exists.
