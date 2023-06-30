caravan
=======

.. dfhack-tool::
    :summary: Adjust properties of caravans on the map.
    :tags: fort armok bugfix

This tool can help with caravans that are leaving too quickly, refuse to unload,
or are just plain unhappy that you are such a poor negotiator.

Also see `force` for creating caravans.

Usage
-----

::

    caravan [list]
    caravan extend [<days> [<ids>]]
    caravan happy [<ids>]
    caravan leave [<ids>]
    caravan unload

Commands listed with the argument ``[<ids>]`` can take multiple
(space-separated) caravan IDs (see ``caravan list`` to get the IDs). If no IDs
are specified, then the commands apply to all caravans on the map.

Examples
--------

``caravan``
    List IDs and information about all caravans on the map.
``caravan extend``
    Force a caravan that is leaving to return to the depot and extend their
    stay another 7 days.
``caravan extend 30 0 1``
    Extend the time that caravans 0 and 1 stay at the depot by 30 days. If the
    caravans have already started leaving, they will return to the depot.
``caravan happy``
    Make the active caravans willing to trade again (after seizing goods,
    annoying merchants, etc.). If the caravan has already started leaving in a
    huff, they will return to the depot.
``caravan leave``
    Makes caravans pack up and leave immediately.
``caravan unload``
    Fix a caravan that got spooked by wildlife and refuses to fully unload.

Overlays
--------

Additional functionality is provided on the various trade-related screens via
`overlay` widgets.

Trade screen
````````````

- ``Shift+Click checkbox``: Select all items inside a bin without selecting the
    bin itself
- ``Ctrl+Click checkbox``: Collapse or expand a single bin (as is possible in
    the "Move goods to/from depot" screen)
- ``Ctrl+c``: Collapses all bins. The hotkey hint can also be clicked as though
    it were a button.
- ``Ctrl+x``: Collapses everything (all item categories and anything
    collapsible within each category). The hotkey hint can also be clicked as
    though it were a button.

There is also a reminder of the fast scroll functionality provided by the
vanilla game when you hold shift while scrolling (this works everywhere).

You can turn the overlay on and off in `gui/control-panel`, or you can
reposition it to your liking with `gui/overlay`. The overlay is named
``caravan.tradeScreenExtension``.

Bring item to depot
```````````````````

When the trade depot is selected, a button appears to bring up the DFHack
enhanced trade goods screen. You'll get a searchable, sortable list of all your
tradeable items, with options to quickly select or deselect classes of items.

Trade agreement
```````````````

A small panel is shown with a hotkey (``Ctrl-A``) for selecting all/none in the
currently shown category.
