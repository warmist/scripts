fix/stable-temp
===============

.. dfhack-tool::
    :summary: Solve FPS issues caused by fluctuating temperature.
    :tags: fort bugfix fps map

This tool instantly sets the temperature of all free-lying items to be in
equilibrium with the environment. This effectively halts FPS-draining
temperature updates until something changes, such as letting magma flow to new
tiles.

To maintain this efficient state, use `tweak fast-heat <tweak>`.

Usage
-----

::

    fix/stable-temp
