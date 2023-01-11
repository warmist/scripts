geld
====

.. dfhack-tool::
    :summary: Geld and ungeld animals.
    :tags: untested fort armok animals

Usage
-----

::

    geld [--ungeld|--toggle] [--unit <id>]

Examples
--------

``geld``
    Gelds the selected animal.
``geld --toggle``
    Toggles the gelded status for the selected animal.
``geld --ungeld --unit 24242``
    Ungelds the unit with the specified id.

Options
-------

``--unit <id>``
    Selects the unit with the specified ID.
``--ungeld``
    Ungelds the specified unit instead of gelding it (see also `ungeld`).
``--toggle``
    Toggles the gelded status of the specified unit.
