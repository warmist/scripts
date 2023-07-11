fix/empty-wheelbarrows
=====================

.. dfhack-tool::
    :summary: Empties stuck items from wheelbarrows
    :tags: fort bugfix items

Empties all wheelbarrows which contain rocks that have become 'stuck' in them.

This works around the issue encountered with :bug:`6074`, and should be run
if you notice wheelbarrows lying around with rocks in them that aren't
being used in a task.


Usage
-----

``fix/empty-wheelbarrows``
    Empties all items, listing all wheelbarrows emptied and their contents
``fix/empty-wheelbarrows --dryrun``
    Lists all wheelbarrows that would be emptied and their contents without performing the action.
``fix/empty-wheelbarrows --quiet``
    Does the action while surpressing output to console
