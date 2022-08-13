add-recipe
==========

.. dfhack-tool::
    :summary: Add crafting recipies to a civ.
    :tags: adventure fort gameplay

Some civilizations never learn to craft high boots. This script can help with
that. Only weapons, armor, and tools are currently supported; things such as
instruments are not.

Usage:

``add-recipe native`` adds all native (but unknown) crafting recipes.
    Civilizations pick randomly from a pool of possible recipes, which means not
    all civs get high boots, for instance. This command gives you all the
    recipes your civilization could have gotten.
``add-recipe all``
    Adds *all* available weapons and armor, including exotic items like
    blowguns, two-handed swords, and capes.
``add-recipe single <item token>``
    Adds a single item by the given item token.

Example
-------

``add-recipe single SHOES:ITEM_SHOES_BOOTS``
    Allow your civ to craft high boots.
