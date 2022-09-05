fix/population-cap
==================

.. dfhack-tool::
    :summary: Ensure the population cap is respected.
    :tags: fort bugfix units

Run this after every migrant wave to ensure your population cap is not exceeded.

The reason for population cap problems is that the population value it is
compared to comes from the last dwarven caravan that successfully left for
mountainhomes. This tool ensures the population value reflects the current
population of your fort.

Note that a migration wave can still overshoot the limit by 1-2 dwarves because
of the last migrant bringing his family. Likewise, king arrival ignores cap.

Usage
-----

::

    fix/population-cap

Examples
--------

``repeat --time 1 --timeUnits months --command [ fix/population-cap ]``
    Automatically run this fix after every migrant wave to keep the population
    values up to date.
