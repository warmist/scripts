-- common logic for the quickfort modules
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

-- keep deprecated settings in the table so we don't break existing configs
settings = {
    blueprints_dir={value='blueprints'},
    buildings_use_blocks={value=false, deprecated=true},
    force_interactive_build={value=false, deprecated=true},
    force_marker_mode={value=false},
    query_unsafe={value=false},
    stockpiles_max_barrels={value=-1},
    stockpiles_max_bins={value=-1},
    stockpiles_max_wheelbarrows={value=0},
}

verbose = false

function log(...)
    if verbose then print(string.format(...)) end
end

function logfn(target_fn, ...)
    if verbose then target_fn{...} end
end
