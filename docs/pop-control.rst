pop-control
===========

.. dfhack-tool::
    :summary: Controls population caps, hermit, and max-wave persistently per-fort.
    :tags: fort units

Controls hermit and the various population caps per-fortress.
Intended to be placed within ``onMapLoad.init`` as ``pop-control on-load``.

If you edit the population caps using `gui/settings-manager` after
running this script, your population caps will be reset and you may
get more migrants than you expected.

Arguments
---------

- ``on-load`` automatically checks for settings for this site and
  prompts them to be entered if not present.

- ``reenter-settings`` lets you revise settings for this site.

- ``view-settings`` shows you the current settings for this site.
