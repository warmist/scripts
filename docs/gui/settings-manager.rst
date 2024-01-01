gui/settings-manager
====================

.. dfhack-tool::
    :summary: Dynamically adjust global DF settings.
    :tags: unavailable

This tool is an in-game editor for settings defined in
:file:`data/init/init.txt` and :file:`data/init/d_init.txt`. Changes are written
back to the init files so they will be loaded the next time you start DF. For
settings that can be dynamically adjusted, such as the population cap, the
active value used by the game is updated immediately.

Editing the population caps will override any modifications made by scripts such
as `max-wave`.

Usage
-----

::

    gui/settings-manager
