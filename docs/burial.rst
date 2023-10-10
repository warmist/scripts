burial
======

.. dfhack-tool::
    :summary: Allows burial in unowned coffins.
    :tags: fort productivity buildings

Creates a 1x1 tomb zone for each built coffin that doesn't already have one.

Usage
-----

    ``burial [-d] [-p]``

Created tombs allow both dwarves and pets by default. By specifying ``-d`` or
``-p``, they can be restricted to dwarves or pets, respectively.

Options
-------

``-d``
    Create dwarf-only tombs
``-p``
    Create pet-only tombs
