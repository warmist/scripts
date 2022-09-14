show-unit-syndromes
===================

.. dfhack-tool::
    :summary: Inspect syndrome details.
    :tags: fort inspection units

This tool can list the syndromes affecting game units and the remaining and
maximum duration of those syndromes, along with (optionally) substantial detail
about the effects.

Usage
-----

``show-unit-syndromes selected|dwarves|livestock|wildanimals|hostile [<options>]``
    Shows information for the specified category of units.
``show-unit-syndromes world [<options>]``
    Shows information about all possible syndromes in the world.

Examples
--------

``show-unit-syndromes selected``
    Show a summary of the syndromes affecting the selected unit.
``show-unit-syndromes dwarves showall``
    Show a summary of the syndromes affecting all citizens, including the
    citizens who are not afflicted with any syndromes.
``show-unit-syndromes world showeffects export:allsyndromes.txt``
    Export a detailed description of all the world's syndromes into the
    :file:`allsyndromes.txt` file.

Options
-------

``showall``
    Show units even if not affected by any syndrome.
``showeffects``
    Show detailed effects of each syndrome.
``showdisplayeffects``
    Show effects that only change the look of the unit.
``export:<filename>``
    Send output to the given file instead of the console.
