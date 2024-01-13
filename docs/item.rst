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

``item [ help | count | [un]forbid | [un]dump | [un]melt ] <filter option>``

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
    flood-fill to create a burrow covering an entire cavern layer)

``item melt -t weapon -m steel --max-quality 3``
    Designate all steel weapons whose quality is less than "exceptional" for
    melting.

Options
-------

``-n, --dry-run``
    Use get an accurate count of the items that would be affected, including the
    implicit filters of the selected main action.

``-i, --inside <burrow>``
    Only include items inside the given burrow.

``-o, --outside <burrow>``
    Only include items outside the given burrow.

``-r, --reachable``
    Only include items reachable by one of your citizens.

``-u, --unreachable``
    Only include items not reachable by one of your citizens.

``-t, --type <string>``
    Filter by item type (e.g., BOULDER, CORPSE, ...). Also accepts lower case
    spelling (e.g. "corpse"). Use ``:lua @df.item_type`` to get the list of all
    item types.

``-m, --material <string>``
    Filter by material the item is made out of (e.g., "iron").

``-c, --mat-category <string>``
    Filter by material category of the material item is made out of (e.g.,
    "metal"). Use ``:lua df.dfhack_material_category`` to get have a list of all
    material categories.

``-d, --description <string>``
    Filter by item description (singular form without stack sizes). Example:
    "cave spider silk web". Note: Due to a bug, this is of limited use for some
    animal products such as wool, because their description always includes the
    stack size.

``-a, --include-artifacts``
    Include artifacts in the item list. Regardless of this setting, artifacts
    are never dumped or melted

``-w, --min-wear <integer>``
    Only include items whose wear/damage level is at least ``integer``. Useful
    values are 0 (pristine) to 3 (XX).

``-W, --max-wear <integer>``
    Only include items whose wear/damage level is at most ``integer``. Useful
    values are 0 (pristine) to 3 (XX).

``-q, --min-quality <integer>``
    Only include items whose quality level is at least ``integer``. Useful
    values are 0 (standard) to 5 (masterwork).

``-Q, --max-quality <integer>``
    Only include items whose quality level is at most ``integer``. Useful
    values are 0 (standard) to 5 (masterwork).
