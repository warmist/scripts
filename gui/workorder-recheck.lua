-- Makes selected `Active` work order `Checking`.
--[====[

gui/workorder-recheck
====================
Sets the status to ``Checking`` (from ``Active``) of the selected work order (in the j-m or u-m screens). This makes the manager reevaluate its conditions.

Example keybinding (put it in your ``dfhack*.init``-file):
 ``keybinding add Alt-A@jobmanagement/Main gui/workorder-recheck``
]====]
local scr = dfhack.gui.getCurViewscreen()
if df.viewscreen_jobmanagementst:is_instance(scr) then
    local orders = df.global.world.manager_orders
    local idx = scr.sel_idx
    if idx < #orders then
        orders[idx].status.active = false
    else
        dfhack.printerr("Invalid order selected")
    end
else
    dfhack.printerr('Must be called on the manager screen (j-m or u-m)')
end
