gui/settings-manager
====================

.. dfhack-tool::
    :summary: Import and export DF settings.
    :tags: embark interface

This tool allows you to save and load DF settings.

Usage
-----

::

    gui/settings-manager save-difficulty
    gui/settings-manager load-difficulty
    gui/settings-manager save-standing-orders
    gui/settings-manager load-standing-orders

Difficulty can be saved and loaded on the embark "preparation" screen or in an
active fort. Standing orders can only be saved and loaded in an active fort.

If auto-restoring of difficulty settings is turned on, it happens when the
embark "preparation" screen is loaded. If auto-restoring of standing orders
settings is turned on, it happens when the fort is loaded for the first time
(just like all other Autostart commands configured in `gui/control-panel`).

Overlays
--------

When embarking or when a fort is loaded, if you click on the
``Custom settings`` button for game difficulty, you will see a new panel at the
top. You can save the current difficulty settings and load the saved settings
back. You can also toggle an option to automatically load the saved settings
for new embarks.

When a fort is loaded, you can also go to the Labor -> Standing Orders page.
You will see a new panel that allows you to save and restore your settings for
standing orders. You can also toggle whether the saved standing orders are
automatically restored when you embark on a new fort. This will toggle the
relevant command in `gui/control-panel` on the Automation -> Autostart page.
