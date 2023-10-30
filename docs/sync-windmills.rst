sync-windmills
==============

.. dfhack-tool::
    :summary: Synchronize or randomize windmill movement.
    :tags: fort buildings

This tool can adjust the appearance of running windmills so that they are
either all in synchronization or are all completely randomized.

Usage
-----

::

    sync-windmills [<options>]

Examples
--------

``sync-windmills``
    Make all active windmills synchronize their turning.
``sync-windmills -r``
    Randomize the movement of all active windmills.

Options
-------

``-q``, ``--quiet``
    Suppress non-error console output.
``-r``, ``--randomize``
    Randomize windmill state.
