warn-stranded
=============

.. dfhack-tool::
    :summary: Reports citizens that are stranded and can't reach any other unit.
    :tags: fort units

If any (live) groups of units are stranded from the main (largest) group,
the game will pause and you'll get a warning dialog telling you which units are isolated.
This gives you a chance to rescue them before they get overly stressed or start starving.

Each unit will be put into a group with the other units stranded together.

There is a command line interface that can print status of units without pausing or bringing up a window.

The GUI and command-line both also have the ability to ignore units so they don't trigger a pause and window.

You can enable ``warn-stranded`` notifications in `gui/control-panel` on the "Maintenance" tab.

Usage
-----

::

    warn-stranded
    warn-stranded status
    warn-stranded clear
    warn-stranded (ignore|ignoregroup|unignore|unignoregroup) <id>

Examples
--------

``warn-stranded status``
    List all stranded units and all ignored units. Includes unit ids in the output.

``warn-stranded clear``
    Clear(unignore) all ignored units.

``warn-stranded ignore 1``
    Ignore unit with id 1.

``warn-stranded ignoregroup 2``
    Ignore stranded unit group 2.

``warn-stranded unignore  1``
    Unignore unit with id 1.

``warn-stranded unignoregroup 3``
    Unignore stranded unit group 3.
