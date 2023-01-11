combine-plants
==============

.. dfhack-tool::
    :summary: Merge stacks of plants in the selected container or stockpile.
    :tags: untested fort productivity items plants

Usage
-----

::

    combine-plants [<options>]

Note that this command can only combine plants and plant growths that are in the
same stockpile or container. It cannot combine items that are in different
stockpiles/containers or are loose on the ground.

Examples
--------

``combine-plants``
    Combine drinks in the currently selected stockpile or container into as few
    stacks as possible, with a maximum of 12 units per stack.
``combine-plants --max 100``
    Increase the maximum stack size for fewer stacks.

Options
-------

``--max <num>``
    Set the maximum number of units of a drink type each barrel can contain.
    Defaults to 30.
``--stockpile <id>``
    The building id of the target stockpile. If not specified, the stockpile
    selected in the UI is used.
``--container <id>``
    The item id of the target container. If not specified, and ``--stockpile``
    is also not specified, then the container item selected in the UI is used.
