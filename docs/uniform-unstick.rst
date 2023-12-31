uniform-unstick
===============

.. dfhack-tool::
    :summary: Make military units reevaluate their uniforms.
    :tags: fort bugfix military

This tool prompts military units to reevaluate their uniform, making them
remove and drop potentially conflicting worn items.

Unlike a "replace clothing" designation, it won't remove additional clothing if
it's coexisting with a uniform item already on that body part. It also won't
remove clothing (e.g. shoes, trousers) if the unit has yet to claim an armor
item for that bodypart (e.g. if you're still manufacturing them).

Uniforms that have no issues are being properly worn will not be affected.

Note that this tool cannot fix the case where the same item is assigned to
multiple squad members.

Usage
-----

``uniform-unstick [--all]``
    List problems with the uniform for the currently selected unit (or all
    units).
``uniform-unstick [--all] <strategy options>``
    Fix the problems with the unit's uniform (or all units' uniforms) using the
    specified strategies.

Examples
--------

``uniform-unstick --all --drop --free``
    Fix all issues with uniforms that have only one item per body part (like all
    default uniforms).

Strategy options
----------------

``--drop``
    Force the unit to drop conflicting worn items onto the ground, where they
    can then be reclaimed in the correct order.
``--free``
    Remove to-equip items from containers or other's inventories and place them
    on the ground, ready to be claimed. This is most useful when someone else
    is wearing/holding the required items.
``--multi``
    Attempt to fix issues with uniforms that allow multiple items per body part.
