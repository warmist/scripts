gui/launcher
============

.. dfhack-tool::
    :summary: In-game DFHack command launcher with integrated help.
    :tags: dfhack

This tool is the primary GUI interface for running DFHack commands. You can open
it from any screen with the \` hotkey. Tap \` again (or hit :kbd:`Esc`) to
close.

Usage
-----

::

    gui/launcher [initial commandline]

Examples
--------

``gui/launcher``
    Open the launcher dialog with a blank initial commandline.
``gui/launcher prospect --show ores,veins``
    Open the launcher dialog with the edit area pre-populated with the given
    command, ready for modification or running. Tools related to ``prospect``
    will appear in the autocomplete list, and help text for ``prospect`` will be
    displayed in the help area.

Editing and running commands
----------------------------

Enter the command you want to run by typing its name. If you want to start over,
:kbd:`Ctrl`:kbd:`C` will clear the line. When you are happy with the command,
hit :kbd:`Enter` or click on the ``run`` button to run it. Any output from the
command will appear in the help area. If you want to run the command but close
the dialog immediately so you can get back to the game, use
:kbd:`Shift`:kbd:`Enter` or hold down the :kbd:`Shift` key and click on the
``run`` button instead. The dialog also closes automatically if you run a
command that brings up a new GUI screen. In any case, the command output will
also be written to the DFHack terminal console.

Autocomplete
------------

As you type, autocomplete options for DFHack commands appear in the right
column. If the first word of what you've typed matches a valid command, then the
autocomplete options will also include commands that have similar functionality
to the one that you've named. Click on an autocomplete option to select it or
cycle through them with :kbd:`Tab` or :kbd:`Shift`:kbd:`Tab`.

Context-sensitive help
----------------------

When you start ``gui/launcher`` without parameters, it shows some useful
information in the help area about how to get started.

Once you have typed (or autocompleted) a word that matches a valid command, the
help area shows the help for that command, including usage instructions and
examples. You can scroll the help text by half pages by left/right clicking or
with :kbd:`PgUp` and :kbd:`PgDn`. You can also scroll line by line with
:kbd:`Ctrl`:kbd:`Up` and :kbd:`Ctrl`:kbd:`Down`.

Command history
---------------

``gui/launcher`` keeps a history of commands you have run to let you quickly run
those commands again. You can scroll through your command history with the
:kbd:`Up` and :kbd:`Down` cursor keys, or you can search your history for
something specific with the :kbd:`Alt`:kbd:`S` hotkey. When you hit
:kbd:`Alt`:kbd:`S`, start typing to search your history for a match. To find the
next match for what you've already typed, hit :kbd:`Alt`:kbd:`S` again. You can
run the matched command immediately with :kbd:`Enter` (or
:kbd:`Shift`:kbd:`Enter`), or hit :kbd:`Esc` to edit the command before running
it.

Dev mode
--------

By default, commands intended for developers and modders are filtered out of the
autocomplete list. You can toggle this filtering by hitting :kbd:`Ctrl`:kbd:`D`
at any time.
