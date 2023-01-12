create-items
============

.. dfhack-tool::
    :summary: Spawn items under the cursor.
    :tags: untested fort armok items

This script is handy to create basic resources you need to get your fortress
started.

Usage
-----

::

    create-items <category> list
    create-items <category> <material> [<quantity>]

If a quantity is not specified, it defaults to 20.

Note that the script does not enforce anything, and will let you create boulders
of toad blood and stuff like that. However the ``list`` mode will only show
'normal' materials.

Examples
--------

::

    create-items boulders COAL_BITUMINOUS 12
    create-items plant tail_pig
    create-items web CREATURE:SPIDER_CAVE_GIANT:SILK
    create-items bar CREATURE:CAT:SOAP
    create-items bar adamantine

Categories
----------

The currently supported item categories are: ``boulder``, ``bar``, ``plant``,
``log``, and ``web``.

The ``web`` item category will create an uncollected cobweb on the floor.
