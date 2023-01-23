fix/restore-nicks
=================

.. dfhack-tool::
    :summary: Workaround for the v50.x bug where Dwarf Fortress occasionally erase Dwarf's nicknames.
    :tags: fort bugfix units

Units occasionally lose their nicknames, in event such as killing a forgotten beast.

`fix/restore-nicks` will save the nicknames of the units once an in-game day, and restore any removed
nickname.

.. note::
    It does not make the difference between a nickname removed by the player or by a bug, so
    it will also prevent to remove the nickname of a dwarf.

Usage
-----

``enable fix/restore-nicks``
    Enable saving and restoring of the nicknames daily.

``disable fix/restore-nicks``
    Disable saving and restoring the nicknames daily.

``fix/restore-nicks now``
    Save and restore the nicknames once.

``fix/restore-nicks forget``
    Forget all the saved nicknames. Useful in order to actually remove nicknames.
