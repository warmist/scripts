item
====

.. dfhack-tool::
    :summary: Perform bulk operations on groups of items.
    :tags: fort productivity items

Filter items in you fort by various properties (e.g., item type, material,
wear-level, quality, ...), and perform bulk operations like forbid, dump, melt,
and their inverses. By default, the tool does not consider artifacts. Outputs
the number of items that matched the filters and were modified.

Usage
-----

``item [ count | [un]forbid | [un]dump | [un]hide | [un]melt ] <filter options>``

The ``count`` action just counts up the items that would be matched by the
given filter options. Otherwise, the named property is set (or unset) on all
the items that the filter options match. The counts reported when you actually
apply a property might differ from what is output by the ``count`` action if
some items already have the property set to the desired state.

Examples
--------

``item forbid --unreachable``
    Forbid all items that cannot be reached by any of your citizens.

``item unforbid --inside Cavern1 --type wood``
    Unforbid/reclaim all logs inside the burrow named "Cavern1" (Hint: use 3D
    flood-fill to create a burrow covering an entire cavern layer).

``item melt -t weapon -m steel --max-quality 3``
    Designate all steel weapons whose quality is at most superior for melting.

``item hide -t boulder --scattered``
    Hide all scattered boulders, i.e. those that are not in stockpiles.

Options
-------

``-n, --dry-run``
    Get a count of the items that would be modified by an operation, which will be the
    number returned by the ``count`` action minus the number of items with the desired
    property already set.

``-a, --include-artifacts``
    Include artifacts in the item list. Regardless of this setting, artifacts
    are never dumped or melted.

``-i, --inside <burrow>``
    Only include items inside the given burrow.

``-o, --outside <burrow>``
    Only include items outside the given burrow.

``-r, --reachable``
    Only include items reachable by one of your citizens.

``-u, --unreachable``
    Only include items not reachable by any of your citizens.

``-t, --type <string>``
    Filter by item type (e.g., BOULDER, CORPSE, ...). Also accepts lower case
    spelling (e.g. "corpse"). Use ``:lua @df.item_type`` to get the list of all
    item types.

``-m, --material <string>``
    Filter by material the item is made out of (e.g., "iron").

``-c, --mat-category <string>``
    Filter by material category of the material item is made out of (e.g.,
    "metal"). Use ``:lua @df.dfhack_material_category`` to get a list of all
    material categories.

``-d, --description <pattern>``
    Filter by item description (singular form without stack sizes). The
    ``pattern`` is a Lua pattern
    (cf. https://www.lua.org/manual/5.4/manual.html#6.4.1), so "cave spider
    silk" will match both "cave spider silk web" as well as "cave spider silk
    cloth". Use ``^pattern$`` to match the entire description.

``-w, --min-wear <integer>``
    Only include items whose wear/damage level is at least ``integer``. Useful
    values are 0 (pristine) to 3 (XX).

``-W, --max-wear <integer>``
    Only include items whose wear/damage level is at most ``integer``. Useful
    values are 0 (pristine) to 3 (XX).

``-q, --min-quality <integer>``
    Only include items whose quality level is at least ``integer``. Useful
    values are 0 (ordinary) to 5 (masterwork).

``-Q, --max-quality <integer>``
    Only include items whose quality level is at most ``integer``. Useful
    values are 0 (ordinary) to 5 (masterwork).

``--stockpiled``
    Only include items that are in stockpiles. Does not include empty bins,
    barrels, and wheelbarrows assigned as storage and transport for stockpiles.

``--scattered``
    Opposite of ``--stockpiled``

``--forbidden``
    Only include forbidden items.

``--melting``
    Only include items designated for melting.

``--dumping``
    Only include items designated for dumping.

``--visible``
    Only include visible items (i.e., ignore hidden items).

``--hidden``
    Only include hidden items.


API
---

The item script can be called programmatically by other scripts, either via the
commandline interface with ``dfhack.run_script()`` or via the API functions
defined in :source-scripts:`item.lua`, available from the return value of
``reqscript('item')``:

* ``item.execute(action, conditions, options)``
* ``item.executeWithPrinting(action, conditions, options)``

Performs ``action`` (``forbid``, ``melt``, etc.) on all items satisfying
``conditions`` (a table containing functions from item to boolean). ``options``
is a table containing the boolean flags ``artifact``, ``dryrun``, and
``bytype``, which correspond to the (filter) options described above.

The function ``execute`` performs no output, while the ``WithPrinting``
variant performs the same output as the ``item`` tool.

The API provides a number of helper functions to aid in the construction of the
filter table. The first argument ``tab`` is always the table to which the filter
should be added.

* ``item.condition_burrow(tab, burrow, outside)``
    Corresponds to ``--inside`` or ``--outside`` (when ``outside=true``). The
    ``burrow`` argument must be a burrow object, not a string.

* ``item.condition_type(tab, match)``
    If ``match`` is a string, this corresponds to ``--type <match>``. Also
    accepts numbers, matching against ``item:getType()``

* ``item.condition_reachable(tab)``
    Corresponds to ``--reachable``

* ``item.condition_unreachable(tab)``
    Corresponds to ``--unreachable``

* ``item.condition_description(tab, pattern)``
    Corresponds to ``--description <pattern>``

* ``item.condition_material(tab, match)``
    Corresponds to ``--material <match>``

* ``item.condition_matcat(tab, match)``
    Corresponds to ``--mat-category <match>``

* ``item.condition_wear(tab, lower, upper)``
    Selects items with wear level between ``lower`` and ``upper`` (Range 0-3, see above).

* ``item.condition_quality(tab, lower, upper)``
    Selects items with quality between ``lower`` and ``upper`` (Range 0-5, see above).

* ``item.condition_stockpiled(tab, invert)``
    Selects stockpiled items, or scattered items when ``invert=true``.

* ``item.condition_forbidden(tab)``
    Checks for ``item.flags.forbid``

* ``item.condition_melt(tab)``
    Checks for ``item.flags.melt``

* ``item.condition_dump(tab)``
    Checks for ``item.flags.dump``

* ``item.condition_hidden(tab)``
    Checks for ``item.flags.hidden``

* ``item.condition_visible(tab)``
    Checks for ``not item.flags.hidden``

 API usage example::

   local itemtools = reqscript('item')
   local cond = {}

   itemtools.condition_type(cond, "BOULDER")
   itemtools.execute('unhide', cond, {}) -- reveal all boulders

   itemtools.condition_stockpiled(cond, true)
   itemtools.execute('hide', cond, {})   -- hide all boulders not in stockpiles
