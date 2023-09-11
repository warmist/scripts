warn-stranded
=============

.. dfhack-tool::
    :summary: Reports citizens that are stranded and can't reach any other unit
    :tags: fort units

If any (live) units are stranded the game will pause and you'll get a warning dialog telling you
which units are isolated. This gives you a chance to rescue them before
they get overly stressed or start starving.

You can enable ``warn-stranded`` notifications in `gui/control-panel` on the "Maintenance" tab.

If you ignore a unit, either call ``warn-stranded clear`` in the dfhack console or if you have multiple
stranded you can toggle/clear all units in the warning dialog.

Usage
-----

::

    warn-stranded [clear]

Examples
--------

``warn-stranded clear``
   Clear all ignored units and then check for ones that are stranded.

Options
-------

``clear``
  Will clear all ignored units so that warnings will be displayed again.
