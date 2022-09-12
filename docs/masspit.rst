masspit
=======

.. dfhack-tool::
    :summary: Designate creatures for pitting.
    :tags: fort productivity animals

If you have prepared an animal stockpile on top of a pit zone, and that
stockpile has been filled with animals/prisoners in cages, then this tool can
designate the inhabitants of all those cages for pitting.

Usage
-----

::

    masspit [<zone id>]

If no zone id is given, use the zone under the cursor.

Examples
--------

``masspit``
    Pit all animals within the selected zone.
``masspit 6``
    Pit all animals within the ``Activity Zone #6`` zone.
