devel/tile-browser
==================

.. dfhack-tool::
    :summary: Browse graphical tile textures by their texpos values.
    :tags: dev

This script pops up a panel that shows a page of 1000 textures. You can change
the starting texpos index with :kbd:`Ctrl`:kbd:`A` or scan forward or backwards
in increments of 1000 with :kbd:`Shift` :kbd:`Up`/:kbd:`Down`.

Textures that take up more than one grid position may have only their upper-left
tiles shown. Increase the tile browser window (drag the bottom right corner to
resize) to see larger tiles Note there may be transparent space visible through
the window for tiles that don't take up the entire allotted space.

Usage
-----

::

    devel/tile-browser
