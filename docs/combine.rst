combine
=======

.. dfhack-tool::
    :summary: Combine stacks of food and plant from one or every stockpile.
    :tags: fort productivity stockpiles items plants


Usage
-----

::

    combine [help] [<mode opts>] [<stockpile opts>] [<stack opts>] [<output opts>]


Examples
--------
``combine``
    Displays help
``combine --preview --stockpile=all``
    Preview stack changes for all types in all stockpiles.
``combine --preview --stockpile=all --max=500``
    Preview stacks changes with max of 500 per stack for all stockpiles.
``combine --preview --types=meat,plant``
    Preview meat and plant stacks changes in all stockpiles.
``combine --merge --stockpile=all --max=500``
    Merge stacks for all stockpiles with max of 500 per stack.
``combine --merge --stockpile=here``
    Merge stacks for stockpile under cursor; enable cursor through DF settings.
``combine --merge --stockpile=<num> --types=meat,plant``
    Merge meat stacks for stockpile id <num>.
``combine --info=stockpiles.txt``
    Preview stack changes and write detailed info to stockpiles.txt.
``combine --merge --info=stockpiles.txt``
    Merge stack changes and write detailed info to stockpiles.txt.


Options
-------------

``-h, --help``
    Prints help text. Default if no options are specified.


Mode options
------------

``-p, --preview``
    Display the stack changes without applying them. Default is preview.

``-m, --merge``
    Merge the stacks.


Stockpile options
-----------------
Specify all stockpiles, the stockpile located at the game cursor, or a stockpile id; id's can be found in the file created by the --info option.

``-s, --stockpile=all|here|<num>``
    Valid option values are:

        all:   Search all stockpiles. Default is all.

        here:  Search the stockpile under the game cursor.

        <num>: Search stockpile <num>.


Stack options
-------------
These options allow you to specify item types and a maximum for the stacks.

Note: The key/rule used to determine if an item can be combined is: item type + race + caste, or item type + material type + material index. Examples of items with different race/caste include eggs and fish. Examples of items with a different material index include sheep.

``-t, --types=<comma separated list of types>``
    Filter item types. Valid types are:

        all:   all of the types listed here. Default is all.

        drink: DRINK

        fat:   GLOB and CHEESE

        fish:  FISH, FISH_RAW and EGG

        meal:  FOOD

        meat:  MEAT

        plant: PLANT and PLANT_GROWTH


``-x, --max=<num>``
    Use maximum stack size <num>. Default is maximum current stack size for comparable items.


Output options
--------------

``-i, --info=filename``
    Save detailed stockpile and item information to filename.

``-d, --debug=<num>``
    Print debugging output to level <num>.
