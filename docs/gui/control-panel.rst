gui/control-panel
=================

.. dfhack-tool::
    :summary: Configure DFHack.
    :tags: dfhack

The DFHack control panel has three pages. The first page shows tools that you
can toggle on and off. Enabled tools will have a green check in the far left
column. Clicking on that far left column or hitting :kbd:`Enter` will toggle
whether the tool is enabled. Note that
some tools require a map to be loaded before they can be enabled. Those tools
will be grayed out in the list and cannot be enabled or have their GUI config
screens shown until you have loaded a fortress.

You can click on the ``[help]`` button next to each tool or hit :kbd:`Ctrl`:kbd:`H`
to open `gui/launcher` to show its help text or to run commandline commands to
configure it. If the tool has an associated GUI config screen, a ``[config]``
button will also appear next to the tool name. Click it or hit :kbd:`Ctrl`:kbd:`G`
to launch the configuration interface.

Usage
-----

::

    gui/control-panel
