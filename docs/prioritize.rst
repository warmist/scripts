prioritize
==========

.. dfhack-tool::
    :summary: Set jobs of specified types to high priority.
    :tags: fort auto jobs

This tool can force specified types of jobs to get assigned and completed as
soon as possible. Finally, you can be sure your food will be hauled before
rotting, your hides will be tanned before going bad, and the corpses of your
enemies will be cleared from your entranceway expediently.

You can prioritize a bunch of active jobs that you need done *right now*, or you
can mark certain job types as high priority, and ``prioritize`` will watch for
and prioritize those types of jobs as they are created. This is especially
useful for ensuring important (but low-priority -- according to DF) jobs don't
get ignored indefinitely in busy forts.

It is important to automatically prioritize only the *most* important job types.
If you add too many job types, or if there are simply too many jobs of those
types in your fort, the other tasks in your fort can get ignored. This causes
the same problem the ``prioritize`` script is designed to solve. See below for a
good, playtested set of job types to automatically prioritize.

Also see the ``do-job-now`` `tweak` for adding a hotkey to the jobs screen that
can toggle the priority of specific individual jobs and the `do-job-now` script,
which boosts the priority of just the jobs related to the selected
job/unit/item/building/workorder.

Usage
-----

::

    prioritize [<options>] [<job_type> ...]

Examples
--------

``prioritize``
    Print out which job types are being automatically prioritized and how many
    jobs of each type we have prioritized since we started watching them.
``prioritize -j``
    Print out the list of active jobs that you can prioritize right now.
``prioritize ConstructBuilding DestroyBuilding``
    Prioritize all current building construction and destruction jobs.
``prioritize -a --haul-labor=Food,Body StoreItemInStockpile``
    Prioritize all current and future food and corpse hauling jobs.

Options
-------

``-a``, ``--add``
    Prioritize all current and future jobs of the specified job types.
``-d``, ``--delete``
    Stop automatically prioritizing new jobs of the specified job types.
``-j``, ``--jobs``
    Print out how many unassigned jobs of each type there are. This is useful
    for discovering the types of the jobs that you can prioritize right now. If
    any job types are specified, only returns the count for those types.
``-l``, ``--haul-labor <labor>[,<labor>...]``
    For StoreItemInStockpile jobs, match only the specified hauling labor(s).
    Valid ``labor`` strings are: "Stone", "Wood", "Body", "Food", "Refuse",
    "Item", "Furniture", and "Animals". If not specified, defaults to matching
    all StoreItemInStockpile jobs.
``-n``, ``--reaction-name <name>[,<name>...]``
    For CustomReaction jobs, match only the specified reaction name(s). See the
    registry output (``-r``) for the full list of reaction names. If not
    specified, defaults to matching all CustomReaction jobs.
``-q``, ``--quiet``
    Suppress informational output (error messages are still printed).
``-r``, ``--registry``
    Print out the full list of valid job types, hauling labors, and reaction
    names.

Which job types should I prioritize?
------------------------------------

The following list has been well playtested and works well across a wide variety
of fort types::

    prioritize -a StoreItemInVehicle StoreItemInBag StoreItemInBarrel PullLever
    prioritize -a StoreItemInLocation StoreItemInHospital
    prioritize -a DestroyBuilding RemoveConstruction RecoverWounded DumpItem
    prioritize -a CleanSelf SlaughterAnimal PrepareRawFish ExtractFromRawFish
    prioritize -a TradeAtDepot BringItemToDepot CleanTrap ManageWorkOrders
    prioritize -a --haul-labor=Food,Body StoreItemInStockpile
    prioritize -a --reaction-name=TAN_A_HIDE CustomReaction

You can add those commands to your ``dfhack-config/init/onMapLoad.init`` file to
ensure important and time-sensitive job types are always completed promptly in
your forts.

Glass industry enthusiasts may also want to include::

    prioritize -a CollectSand

You may be tempted to automatically prioritize ``ConstructBuilding`` jobs, but
beware that if you engage in megaprojects where many constructions must be
built, these jobs can consume your entire fortress if prioritized. It is often
better to run ``prioritize ConstructBuilding`` by itself (i.e. without the
``-a`` parameter) as needed to just prioritize the construction jobs that you
have ready at the time.
