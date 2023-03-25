fix/general-strike
==================

.. dfhack-tool::
    :summary: Prevent dwarves from getting stuck and refusing to work.
    :tags: fort bugfix

This script attempts to fix known causes of the "general strike bug", where
dwarves just stop accepting work and stand around with "No job".

You can enable automatic running of this fix in the "Maintenance" tab of
`gui/control-panel`.

Usage
-----

::

    fix/general-strike [<options>]

Options
-------

``-q``, ``--quiet``
    Only output status when something was actually fixed.
