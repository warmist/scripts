ban-cooking
===========

.. dfhack-tool::
    :summary: Protect useful items from being cooked.
    :tags: fort productivity items plants

Some cookable ingredients have other important uses. For example, seeds can be
cooked, but if you cook them all, then your farmers will have nothing to plant
in the fields. Similarly, thread can be cooked, but if you do that, then your
weavers will have nothing to weave into cloth and your doctors will have
nothing to use for stitching up injured dwarves.

If you open the Kitchen screen, you can select individual item types and choose
to ban them from cooking. To prevent all your booze from being cooked, for
example, you'd select the Booze tab and then click each of the visible types of
booze to prevent them from being cooked. Only types that you have in stock are
shown, so if you acquire a different type of booze in the future, you have to
come back to this screen and ban the new types.

Instead of doing all that clicking, ``ban-cooking`` can ban entire classes of
items (e.g. all types of booze) in one go. It can even ban types that you don't
have in stock yet, so when you *do* get some in stock, they will already be
banned. It will never ban items that are only good for eating or cooking, like
meat or non-plantable nuts. It is usually a good idea to run
``ban-cooking all`` as one of your first actions in a new fort.

If you want to re-enable cooking for a banned item type, you can go to the
Kitchen screen and un-ban whatever you like by clicking on the "cook"
icon. You can also un-ban an entire class of items with the
``ban-cooking --unban`` option.

Usage
-----

::

    ban-cooking <type|all> [<type> ...] [<options>]

Valid types are ``booze``, ``brew`` (brewable plants), ``fruit``, ``honey``,
``milk``, ``mill`` (millable plants), ``oil``, ``seeds`` (plantable seeds),
``tallow``, and ``thread``. It is possible to include multiple types or all
types in a single ban-cooking command: ``ban-cooking oil tallow`` will ban both
oil and tallow from cooking. ``ban-cooking all`` will ban all of the above
types.

Examples::

    on-new-fortress ban-cooking all

Ban cooking all otherwise useful ingredients once when starting a new fortress.
Note that this exact command can be enabled via the ``Autostart`` tab of
`gui/control-panel`.

Options
-------

``-u``, ``--unban``
    Un-ban the indicated item types.

``-v``, ``--verbose``
    Print each ban as it happens.
