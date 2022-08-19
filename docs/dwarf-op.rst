dwarf-op
========

.. dfhack-tool::
    :summary: Tune units to perform underrepresented job roles in your fortress.
    :tags: fort armok units

``dwarf-op`` examines the distribution of skills and attributes across the
dwarves in your fortress and can rewrite the characteristics of a dwarf (or
group of dwarves) so that they are fit to excel at the jobs that your current
dwarves don't adequately cover.

It uses a library of profiles to define job classes, and generates dwarves with
random variation so each dwarf is unique.

``dwarf-op`` can also be used in a mode more similar to `assign-profile`, where
you can specify precisely what archtype you want a for given dwarf, and
``dwarf-op`` can generate a random dwarf that matches that archetype.

Usage::

    dwarf-op --list <table>
    dwarf-op --reset|--resetall
    dwarf-op [--select <criteria>] <commands>

Examples
--------

``dwarf-op --select unoptimized --clear --optimize``
    Transform newly arrived dwarves into the workers that your fort needs most.
``dwarf-op --select all --clear --optimize``
    Rebalance the distribution of skills and attributes across your units.
``dwarf-op --select [ waves 14 ] --applyjobs [ MINER ]``
    Make all migrants in wave 14 competent miners.
``dwarf-op --select [ jobs Stoneworker ] --applytypes [ fast3 strong5 ]``
    Boost the speed and strength of your masons so they can carry boulders
    to their workshop faster.

Selection criteria
------------------

Note that dwarves whose name or profession starts with ``.`` or ``,`` are
considered "protected", and will not be matched by the selection criteria
options below unless specifically noted.

You can prepend the letter ``p`` to any option to include protected dwarves in
your selection. For example, to truly select all dwarves, specify ``pall``
instead of ``all``.

``highlighted``
    Selects only the in-game highlighted dwarf (from any screen), regardless of
    protection status. This is the default if no ``--select`` option is
    specified.
``all``
    Selects all dwarves.
``<name>``
    Selects any dwarf with <name> anywhere in their name or nickname. This
    option ignores protection status.
``named``
    Selects dwarves with user-given names.
``unnamed``
    Selects dwarves without user-given names.
``employed```
    Selects dwarves with custom professions. Does not include optimized dwarves.
``optimized``
    Selects dwarves that have been previously optimized by ``dwarf-op``.
``unoptimized``
    Selects any dwarves that have not been previously optimized by ``dwarf-op``.
``protected``
    Selects protected dwarves.
``unprotected``
    Selects unprotected dwarves.
``drunks``
    Selects any dwarves who have the ``DRUNK`` profession, including those who
    have been zeroed by the ``--clear`` command option.
``jobs "[" jobs <jobname> [<jobname> ...] "]"``
    Selects any dwarves with the specified custom professions.
``waves "[" waves <num> [<num> ...] "]"``
    Selects dwarves from the specified migration waves. Waves are enumerated
    starting at 0 and increasing by 1 with each wave. The waves go by season and
    year and thus should match what you see in `list-waves` or Dwarf Therapist.
    It is recommended that you ``--show`` the selected dwarves before modifying
    them.

Options
-------

``--reset``
    Forget which dwarves have been optimized. However, if you reload an existing
    save, the optimization list will be reloaded.
``--resetall``
    Forget which dwarves have been optimized and remove the persisted
    optimization data.
``--show``
    Lists the selected dwarves. Useful for previewing selected dwarves before
    modifying them or looking up the migration wave number for a group.
``--clean <value>``
    Checks for skills with a rating of ``<value>`` and removes them from the
    dwarf's skill list.
``--clear``
    Zeroes the skills and attributes of selected dwarves. No attributes, no
    labors. Assigns ``DRUNK`` profession.
``--reroll [inclusive]``
    Clears attributes of selected dwarves, then rerolls that dwarf based on
    their jobs. Run ``dwarf-op --list attrib_levels`` to see how stats are
    distributed. If ``inclusive`` is specified, then attributes are not cleared,
    but rather will only be changed if the current reroll is better. This
    command ignores dwarves with jobs that are not listed in the ``jobs`` table.
``--optimize``
    Performs a job search for unoptimized dwarves. Run
    ``dwarf-op --list job_distribution`` to see how jobs are distributed.
``--applyjobs "[" <job> [<job> ...] "]"``
    Applies the listed jobs to the selected dwarves. Run
    ``dwarf-op --list jobs`` to see available jobs.
``--applyprofessions "[" <profession> [<profession> ...] "]"``
    Applies the listed professions to the selected dwarves. Run
    ``dwarf-op --list professions`` to see available professions.
``--applytypes "[" <profession> [<profession> ...] "]"``
    Applies the listed types to the selected dwarves. Run
    ``dwarf-op --list dwf_types`` to see available types.
``--renamejob <name>``
    Renames the selected dwarves' custom professions to the specified name.

.. _dorf_tables:

Data tables
-----------

The data tables that ``dwarf-op`` uses are described below. They can be
inspected with ``dwarf-op --list <table name>``.

``job_distributions``
    Defines thresholds for each column of distributions. The columns must add up
    to the values in the thresholds row for that column.  Every other row
    references an entry in the ``jobs`` table.

``attrib_levels``
    Defines stat distributions for both physical and mental attributes.
    Each level has a probability (p-value, or p) which indicates how likely
    a level will be used for a particular stat such as strength or spacial
    awareness. The levels range from incompetent to unbelievable (god-like)
    and are mostly inline with what the game uses already, but adds one
    level more than what the game uses to push the unbelievable even higher
    on average.

    In addition to a bell shaped p-value curve for the levels, there is
    additionally a standard deviation used to generate the value once a
    level has been selected, this makes the bell curve not so bell shaped in
    the end. Labours do not follow the same stat system and are more uniformly
    random, which are compensated for in the description of jobs/professions.

``jobs``
    Defines ``dwarf-op``'s nameable jobs. Each job is comprised of required
    professions, optional professions, probabilities for each optional
    profession, a 'max' number of optional professions, and a list of types
    (from the ``types`` table below) to apply to dwarves in the defined job.

``professions``
    These are a subset of the professions DF has. All professions listed should
    match a profession dwarf fortress has built in, however not all the
    built-ins are defined here.

    Each profession is defined with a set of job skills which match the skills
    built into Dwarf Fortress. Each skill is given a value which represents the
    bonus a dwarf will get for this skill. The skills are added in a random
    order, with the first few receiving the highest values (excluding the bonus
    just mentioned). Thus the bonuses are to ensure a minimum threshold is
    passed for certain skills deemed critical to a profession.

``types``
    These are a sort of archetype system for applying to dwarves. It primarily
    includes physical and mental attributes, but can include skills as well.

    Each type has a probability of being applied to a dwarf just by pure luck -
    this is in addition to types applied by other means. Each type also has a
    list of attribute(s) each attribute has an ``attrib_level`` entry associated
    with it. Additionally each type may define a list of job skills, with each
    skill having a minimum and maximum value. The chosen values will be evenly
    distributed between these two numbers (inclusive).

To see a full list of built-in professions and jobs, you can run these commands::

    devel/query -table df.profession
    devel/query -table df.job_skill
