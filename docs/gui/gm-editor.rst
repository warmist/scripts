gui/gm-editor
=============

.. dfhack-tool::
    :summary: Inspect and edit DF game data.
    :tags: dfhack armok inspection animals buildings items jobs map plants stockpiles units workorders

This editor allows you to inspect or modify almost anything in DF. Press
:kbd:`?` for in-game help.

Usage
-----

``gui/gm-editor``
    Open the editor on whatever is selected or viewed (e.g. unit/item
    description screen)
``gui/gm-editor <lua expression>``
    Evaluate a lua expression and opens the editor on its results.
``gui/gm-editor dialog``
    Show an in-game dialog to input the lua expression to evaluate. Works the
    same as version above.
``gui/gm-editor toggle``
    Hide (if shown) or show (if hidden) the editor at the same position you left
    it.

Examples
--------

``gui/gm-editor``
    Opens the editor on the selected unit/item/job/workorder/etc.
``gui/gm-editor df.global.world.items.all``
    Opens the editor on the items list.

Screenshot
----------

.. image:: /docs/images/gm-editor.png
