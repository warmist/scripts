modtools/create-item
====================

.. dfhack-tool::
    :summary: Create arbitrary items.
    :tags: unavailable dev

This tool provides a commandline interface for creating items of your choice.

Usage
-----

::

    modtools/create-item <options>

Options
-------

    -creator id
        specify the id of the unit who will create the item,
        or \\LAST to indicate the unit with id df.global.unit_next_id-1
        examples:
            0
            2
            \\LAST
    -material matstring
        specify the material of the item to be created
        examples:
            INORGANIC:IRON
            CREATURE_MAT:DWARF:BRAIN
            PLANT_MAT:MUSHROOM_HELMET_PLUMP:DRINK
    -item itemstr
        specify the itemdef of the item to be created
        examples:
            WEAPON:ITEM_WEAPON_PICK
    -quality qualitystr
        specify the quality level of the item to be created (df.item_quality)
        examples: Ordinary, WellCrafted, FinelyCrafted, Masterful, or 0-5
    -matchingShoes
        create two of this item
    -matchingGloves
        create two of this item, and set handedness appropriately
