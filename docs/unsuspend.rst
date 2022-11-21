unsuspend
=========

.. dfhack-tool::
    :summary: Unsuspends building construction jobs.
    :tags: fort productivity jobs

Unsuspends building construction jobs, except for jobs managed by `buildingplan`
and those where water flow is greater than 1. This allows you to quickly recover
if a bunch of jobs were suspended due to the workers getting scared off by
wildlife or items temporarily blocking building sites.

See `autounsuspend` for periodic automatic unsuspending of suspended jobs.

Usage
-----

::

    unsuspend

Overlay
-------

This script also provides an overlay that is managed by the `overlay` framework.
When enabled, it will display a colored 'X' over suspended buildings. A green
'X' indicates that the building is waiting on materials, and `buildingplan` will
unsuspend it for you when those materials become available. A yellow 'X' means
that the building is suspended and that you can unsuspend it manually or with
the `unsuspend` command. A red 'X' indicates that the building has been
re-suspended multiple times, and that you might need to look into whatever is
preventing the building from being built.
