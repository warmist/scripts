fix/ownership
=============

.. dfhack-tool::
    :summary: Fixes instances of dwarves claiming the same item or an item they don't own
    :tags: fort bugfix units

Due to a bug a dwarf can believe they own an item when they actually do not.

`fix/ownership` will run once a day to check units and make sure they dont
mistakenly own an item they shouldn't.

This should help issues of dwarves getting stuck in a "Store owned item" job.

Usage
-----

``enable fix/ownership``
    Enable daily check of ownership.

``disable fix/protect-nicks``
    Disable the daily check.

``fix/protect-nicks now``
    Immediately run check.
