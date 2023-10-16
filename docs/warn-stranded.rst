warn-stranded
=============

.. dfhack-tool::
    :summary: Reports citizens that are stranded and can't reach any other citizens.
    :tags: fort units

If any (live) groups of fort citizens are stranded from the main (largest) group,
the game will pause and you'll get a warning dialog telling you which citizens are isolated.
This gives you a chance to rescue them before they get overly stressed or start starving.

Each citizen will be put into a group with the other citizens stranded together.

There is a command line interface that can print status of citizens without pausing or bringing up a window.

The GUI and command-line both also have the ability to ignore citizens so they don't trigger a pause and window.

You can enable ``warn-stranded`` notifications in `gui/control-panel` on the "Maintenance" tab.

Usage
-----

::

    warn-stranded
    warn-stranded status
    warn-stranded clear
    warn-stranded (ignore|ignoregroup|unignore|unignoregroup) <id>

Examples
--------

``warn-stranded``
    Standard command that checks citizens and pops up a warning if any are stranded.
    Does nothing when there are no unignored stranded citizens.

``warn-stranded status``
    List all stranded citizens and all ignored citizens. Includes citizen unit ids.

``warn-stranded clear``
    Clear (unignore) all ignored citizens.

``warn-stranded ignore 1``
    Ignore citizen with unit id 1.

``warn-stranded ignoregroup 2``
    Ignore stranded citizen group 2.

``warn-stranded unignore  1``
    Unignore citizen with unit id 1.

``warn-stranded unignoregroup 3``
    Unignore stranded citizen group 3.
