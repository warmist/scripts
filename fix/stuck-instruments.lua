-- Fixes instruments that never got played during a performance

local help = [====[

fix/stuck-instruments
=====================

Fixes instruments that were picked up for a performance, but were instead
simulated and are now stuck permanently in a job that no longer exists.

This works around the issue encountered with :bug:`9485`, and should be run
if you notice any instruments lying on the ground that seem to be stuck in a
job.

Run ``fix/stuck-instruments -n`` or ``fix/stuck-instruments --dry-run`` to
list how many instruments would be fixed without performing the action.

]====]


function fixInstruments(args)
    local dry_run = false
    local fixed = 0
    for _, arg in pairs(args) do
        if args[1]:match('-h') or args[1]:match('help') then
            print(dfhack.script_help())
            return
        elseif args[1]:match('-n') or args[1]:match('dry') then
            dry_run = true
        end
    end
    for _, item in ipairs(df.global.world.items.all) do
        if item:getType() == df.item_type.INSTRUMENT then
            for i, ref in pairs(item.general_refs) do
                if ref:getType() == df.general_ref_type.ACTIVITY_EVENT then
                    local activity = df.activity_entry.find(ref.activity_id)
                    if not activity then
                        if not dry_run then
                            --remove dead activity reference
                            item.general_refs:erase(i)
                            if item.flags.in_job then
                                --remove stuck in_job flag if true
                                item.flags.in_job = false
                            end
                        end
                        fixed = fixed + 1
                        break
                    end
                end
            end
        end
    end

    if fixed > 0 or dry_run then
        print(("%s %d stuck instruments."):format(
                dry_run and "Found" or "Fixed",
                fixed
        ))
    end
end


if not dfhack_flags.module then
    fixInstruments{...}
end
