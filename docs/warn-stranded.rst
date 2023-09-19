warn-stranded
=============

.. dfhack-tool::
    :summary: Reports citizens that are stranded and can't reach any other unit.
    :tags: fort units

If any (live) units are stranded from the main group, the game will pause and you'll get a warning dialog telling you
which units are isolated. This gives you a chance to rescue them before they get overly stressed or start starving.

Each unit will be put into a group with the other units stranded together.

There is a command line interface that can print status of units without pausing or bringing up a window.

The GUI and command-line both also have the ability to ignore units so they don't trigger a pause and window.

You can enable ``warn-stranded`` notifications in `gui/control-panel` on the "Maintenance" tab.

Usage
-----

``warn-stranded -[wicg] [status|ignore|unignore] <id>``

    -w, --walkgroups: List the raw pathability walkgroup number of each unit in all views.

    -i, --ids: List the id of each unit in all views.

    -g, --group: Only affects ignore/unignore. Interpret positional argument as group ID and perform operation to the entire group.

    -c, --clear: Clear the entire ignore list first before doing anything else.

Examples
--------

``warn-stranded -c``
    Clear all ignored units and then check for ones that are stranded.

``warn-stranded -wi``
    Standard GUI invocation, but list walkgroups and ids in the table.

``warn-stranded -wic status``
    Clear all ignored units. Then list all stranded units and all ignored units. Include walkgroups and ids in the output.

``warn-stranded ignore 1``
    Ignore unit with id 1.

``warn-stranded ignore -g 2``
    Ignore stranded unit group 2.

``warn-stranded unignore [-g] 1``
    Unignore unit or stranded group 1.
