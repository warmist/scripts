item
====

.. dfhack-tool::
    :summary: Perform bulk operations on items based on various properties.
    :tags: fort productivity items

Filter items in you fort by various properties (e.g., item type, material,
wear-level, quality, ...), and perform the bulk operations forbid, dump, melt,
and their inverses. By default, the tool does not consider artifacts. Outputs
the number of items that matched the filters and were modified.

Usage
-----

``item [ count | [un]forbid | [un]dump | [un]hide | [un]melt ] <filter options>``

Action names should be self explanatory. All actions other than ``help`` and
``count`` have implicit filters associated with them. For instance, ``item
forbid --unreachable`` will neither report nor test reachability of items that
are already forbidden.

Examples
--------

``item forbid --unreachable``
    Forbid all items that cannot be reached by any of your citizens.

``item unforbid --inside Cavern1 --type wood``
    Unforbid/reclaim all logs inside the burrow named "Cavern1" (Hint: use 3D
    flood-fill to create a burrow covering an entire cavern layer).

``item melt -t weapon -m steel --max-quality 3``
    Designate all steel weapons whose quality is at most superior for melting.

Options
-------

``-n, --dry-run``
    Get an accurate count of the items that would be affected, including the
    implicit filters of the selected main action.

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
    "metal"). Use ``:lua df.dfhack_material_category`` to get a list of all
    material categories.

``-d, --description <pattern>``
    Filter by item description (singular form without stack sizes). The
    ``pattern`` is a Lua pattern
    (cf. https://www.lua.org/manual/5.4/manual.html#6.4.1), so "cave spider
    silk" will match both "cave spider silk web" as well as "cave spider silk
    cloth". Use ``^pattern$`` to match the entire description.

``-a, --include-artifacts``
    Include artifacts in the item list. Regardless of this setting, artifacts
    are never dumped or melted.

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

``--forbidden``
    Only include forbidden items.

``--melting``
    Only include items designated for melting.

``--dumping``
    only include items designated for dumping.

``--visible``
    Only include visible items (i.e., ignore hidden items).

``--hidden``
    Only include hidden items.
