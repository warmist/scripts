fix/empty-wheelbarrows
======================

.. dfhack-tool::
    :summary: Empties stuck items from wheelbarrows.
    :tags: fort bugfix items

Empties all wheelbarrows which contain rocks that have become 'stuck' in them.

This works around the issue encountered with :bug:`6074`, and should be run
if you notice wheelbarrows lying around with rocks in them that aren't
being used in a task.

Usage
-----
::

    fix/empty-wheelbarrows [<options>]

Examples
--------

``fix/empty-wheelbarrows``
    Empties all items, listing all wheelbarrows emptied and their contents.
``fix/empty-wheelbarrows --dry-run``
    Lists all wheelbarrows that would be emptied and their contents without performing the action.
``fix/empty-wheelbarrows --quiet``
    Does the action while surpressing output to console.
``repeat --name empty-wheelbarrows --time 1200 command [ fix/empty-wheelbarrows --quiet ]``
    Runs empty-wheelbarrows quietly every 1200 game ticks, which is once per in-game day.

Options
-------

``-q``, ``--quiet``
    Surpress console output (final status update is still printed if at least one item was affected).
``-d``, ``--dry-run``
    Dry run, don't commit changes.
