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
    Merge stacks in the selected stockpile.

Commands
--------
``all``
    Search all stockpiles.
``here``
    Search the currently selected stockpile.

Options
-------
``-h``, ``--help``
    Prints help text. Default if no options are specified.
``-d``, ``--dry-run``
    Display the stack changes without applying them.
``-t``, ``--types <comma separated list of types>``
    Filter item types. Default is ``all``. Valid types are:

        ``all``:   all of the types listed here.

        ``drink``: DRINK

        ``fat``:   GLOB and CHEESE

        ``fish``:  FISH, FISH_RAW and EGG

        ``food``:  FOOD

        ``meat``:  MEAT

        ``plant``: PLANT and PLANT_GROWTH

``-q``, ``--quiet``
    Only print changes instead of a summary of all processed stockpiles.

``-v``, ``--verbose``
    Print verbose output.
