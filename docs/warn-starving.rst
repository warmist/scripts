warn-starving
=============

.. dfhack-tool::
    :summary: Report units that are dangerously hungry, thirsty, or drowsy.
    :tags: fort animals units

If any (live) units are starving, very thirsty, or very drowsy, the game will
pause and you'll get a warning dialog telling you which units are in danger.
This gives you a chance to rescue them (or take them out of their cages) before
they die.

This script is set to run periodically by default in `gui/control-panel`.

Usage
-----

::

    warn-starving [all] [sane]

Examples
--------

``warn-starving all sane``
    Report on all currently distressed units, excluding insane units that you
    wouldn't be able to save anyway.

Options
-------

``all``
    Report on all distressed units, even if they have already been reported. By
    default, only newly distressed units that haven't already been reported are
    listed.
``sane``
    Ignore insane units.
