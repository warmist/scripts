suspendmanager
==============

.. dfhack-tool::
    :summary: Intelligently suspend and unsuspend jobs.
    :tags: fort auto jobs

This tool will watch your active jobs and:

- unsuspend jobs that have become suspended due to inaccessible materials,
    items temporarily in the way, or worker dwarves getting scared by wildlife
- suspend construction jobs that would prevent a dwarf from reaching an adjacent
    construction job, such as when building a wall corner.
- suspend construction jobs on top of a smoothing, engraving or track carving
  job. This prevent the construction job to be completed first, which would
  erase the other

Usage
-----

``suspendmanager``
    Display the current status

``suspendmanager (enable|disable)``
    Enable or disable ``suspendmanager``

``suspendmanager set preventblocking (true|false)``
    Prevent construction jobs from blocking each others (enabled by default). See `suspend`.
