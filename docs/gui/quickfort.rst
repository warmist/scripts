gui/quickfort
=============

.. dfhack-tool::
    :summary: Apply pre-designed blueprints to your fort.
    :tags: fort design productivity buildings map stockpiles

This is the graphical interface for the `quickfort` script. Once you load a
blueprint, you will see a blinking "shadow" over the tiles that will be
modified. You can use the cursor to reposition the blueprint or the hotkeys to
rotate and repeat the blueprint up or down z-levels. Once you are satisfied, hit
:kbd:`Enter` to apply the blueprint to the map.

Usage
-----

::

    gui/quickfort [<search terms>]

If the (optional) search terms match a single blueprint (e.g. if the search
terms are copied from the ``quickfort list`` output like
``gui/quickfort library/aquifer_tap.csv -n /dig``), then that blueprint is
pre-loaded into the UI and a preview for that blueprint appears. Otherwise, a
dialog is shown where you can select a blueprint to load.

You can also type search terms in the dialog and the list of matching blueprints
will be filtered as you type. You can search for directory names, file names,
blueprint labels, modes, or comments. Note that, depending on the active list
filters, the id numbers in the list may not be contiguous.

To rotate or flip the blueprint around, enable transformations with :kbd:`t` and
use :kbd:`Ctrl` with the arrow keys to add a transformation step:

:kbd:`Ctrl`:kbd:`Left`:  Rotate counterclockwise (ccw)
:kbd:`Ctrl`:kbd:`Right`: Rotate clockwise (cw)
:kbd:`Ctrl`:kbd:`Up`:    Flip vertically (vflip)
:kbd:`Ctrl`:kbd:`Down`:  Flip horizontally (hflip)

If you have applied several transformations, but there is a shorter sequence
that can be used to get the blueprint into the configuration you want, it will
automatically be used. For example, if you rotate clockwise three times,
``gui/quickfort`` will shorten the sequence to a single counterclockwise
rotation for you.

Any settings you set in the UI, such as search terms for the blueprint list or
transformation options, are saved for the next time you run the script.

Examples
--------

``gui/quickfort``
    Open the quickfort interface with saved settings.
``gui/quickfort dreamfort``
    Open with a custom filter that shows only blueprints that match the string
    ``dreamfort``.
``gui/quickfort myblueprint.csv``
    Open with the ``myblueprint.csv`` blueprint pre-loaded.
