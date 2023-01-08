lever
=====

.. dfhack-tool::
    :summary: Inspect and pull levers.
    :tags: untested fort armok inspection productivity buildings

Usage
-----

``lever list``
    Print out a list of your fort's levers, including their ID, name, activation
    state, and what they are linked to (if anything).
``lever pull --id <id> [<options>]``
    Queue a job so a dwarf will pull the specified lever. This is the same as
    :kbd:`q` querying the building and queueing a :kbd:`P` pull job.
``lever show --id <id>``
    Center the display on the specified lever and print information about it.

Examples
--------

``lever pull --id 42 --priority``
    Queue a job to pull lever 42 at high priority.
``lever pull --id 42 --cheat``
    Skip the job and pull the lever with the hand of Armok!

Options
-------

``--priority``
    Queue a job at high priority.
``--cheat``
    Magically toggle the lever immediately.
