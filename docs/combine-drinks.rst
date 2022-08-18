combine-drinks
==============

.. dfhack-tool::
    :summary: Merge stacks of drinks in the selected stockpile.
    :tags: fort productivity items

Usage
-----

::

    combine-drinks [--max <num>] [--stockpile <id>]

Note that this command can only combine drinks that are in the same stockpile.
It cannot combine drinks that are in different stockpiles or are not in a
stockpile at all.

Examples
--------

``combine-drinks``
    Combine drinks in the currently selected stockpile into as few barrels as
    possible, with a maximum of 30 units of drink per barrel.
``combine-drinks --max 100``
    Stuff more drinks into each barrel.

Options
-------

``--max <num>``
    Set the maximum number of units of a drink type each barrel can contain.
    Defaults to 30.
``--stockpile <id>``
    The building id of the target stockpile. If not specified, the stockpile
    selected in the UI is used.
