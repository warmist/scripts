tutorials-be-gone
=================

.. dfhack-tool::
    :summary: Hide new fort tutorial popups.
    :tags: fort interface

If you've played the game before and don't need to see the tutorial popups that
show up on every new fort, ``tutorials-be-gone`` can hide them for you. You can
enable this tool as a system service in the "Services" tab of
`gui/control-panel` so it takes effect for all new or loaded forts.

Specifically, this tool hides:

- The popup displayed when creating a new world
- The "Do you want to start a tutorial embark" popup
- Popups displayed the first time you open the labor, burrows, justice, and
  other similar screens in a new fort

Usage
-----

::

    enable tutorials-be-gone
    tutorials-be-gone

If you haven't enabled the tool, but you run the command while a fort is
loaded, all future popups for the loaded fort will be hidden.
