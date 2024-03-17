fix/ownership
=============

.. dfhack-tool::
    :summary: Fixes instances of units claiming the same item or an item they don't own
    :tags: fort bugfix units

Due to a bug a unit can believe they own an item when they actually do not.

`fix/ownership` will run once a day to check units and make sure they dont
mistakenly own an item they shouldn't.

This should help issues of units getting stuck in a "Store owned item" job.

Usage
-----

``fix/ownership``
    Check ownership.

``fix/ownership help``
    Display help details.
