devel/tile-browser
==================

.. dfhack-tool::
    :summary: Browse graphical tile textures by their texpos values.
    :tags: dev

This script pops up a panel that shows a page of 1000 textures. You can change
the starting texpos index with :kbd:`Ctrl`:kbd:`A` or scan forward or backwards
in increments of 1000 with :kbd:`Shift` :kbd:`Up`/:kbd:`Down`.

For textures that take up more than one grid position, only the upper-left tile
of the texture will be shown. For large enough textures, though, you can see the
rest of it peeking out from behind the Tile Browser window.

Usage
-----

::

    devel/tile-browser
