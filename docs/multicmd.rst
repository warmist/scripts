multicmd
========

.. dfhack-tool::
    :summary: Run multiple DFHack commands.
    :tags: dfhack

This utility command allows you to specify multiple DFHack commands on a single
line.

The string is split around the :kbd:`;` character(s), and all parts are run
sequentially as independent dfhack commands. This is especially useful for
hotkeys, where you only have one line to specify what the hotkey will do.

Usage
-----

::

    multicmd <command>; <command>[; <command> ...]

Example
-------

::

    multicmd :lua require('gui.dwarfmode').enterSidebarMode(df.ui_sidebar_mode.DesignateMine); locate-ore IRON; digv; digcircle 16
