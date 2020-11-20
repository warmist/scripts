-- fixes some equipment corruption issues (bug 11014)

--[====[

fix/corrupt-equipment
=====================

Fixes some corruption that can occur in equipment lists, as in :bug:`11014`.

]====]

function fix_equipment ()
  local categories =
    {{"FLASK", df.item_flaskst},
     {"WEAPON", df.item_weaponst},
     {"ARMOR", df.item_armorst},
     {"SHOES", df.item_shoesst},
     {"SHIELD", df.item_shieldst},
     {"HELM", df.item_helmst},
     {"GLOVES", df.item_glovesst},
     {"AMMO", df.item_ammost},
     {"PANTS", df.item_pantsst},
     {"BACKPACK", df.item_backpackst},
     {"QUIVER", df.item_quiverst}}

  for i, element in ipairs (categories) do
    for k = #df.global.ui.equipment.items_unassigned [element [1]] - 1, 0, -1 do
      if df.global.ui.equipment.items_unassigned [element [1]] [k]._type ~= element [2] then
        dfhack.printerr ("Corrupted unassigned " .. element [1] .. ", removing", k)
        df.global.ui.equipment.items_unassigned [element [1]]:erase (k)
      end
    end
  end

  for i, element in ipairs (categories) do
    for k = #df.global.ui.equipment.items_assigned [element [1]] - 1, 0, -1 do
      if df.global.ui.equipment.items_assigned [element [1]] [k]._type ~= element [2] then
        dfhack.printerr ("Corrupted assigned " .. element [1] .. ", removing", k)
        df.global.ui.equipment.items_assigned [element [1]]:erase (k)
      end
    end
  end

  for i, squad in ipairs (df.global.world.squads.all) do
    if squad.entity_id == df.global.ui.group_id then
      local squad_name = dfhack.TranslateName (squad.name, true)
      if squad.alias ~= "" then
        squad_name = squad.alias
      end

--      dfhack.println (squad_name, i)

      for k, position in ipairs (squad.positions) do
        for l, item_id in ipairs (position.assigned_items) do
          local legal_type_found = false
          local item = df.item.find (item_id)

          if not item then
            dfhack.printerr ("Nonexistent item assigned to squad member " .. tostring (k) .. " of squad " .. squad_name ..
                             ". Detection only. No action performed.")

          else
            for m, element in ipairs (categories) do
              if item._type == element [2] then
                legal_type_found = true
                break
              end
            end

            if not legal_type_found then
              dfhack.printerr ("Item " .. tostring (l) .. " assigned to squad member " .. tostring (k) .. " of squad " .. squad_name ..
                               " is of unexpected type " .. tostring (item._type) ..  ". Detection only. No action performed.")
            end
          end
        end
      end
    end
  end
end

fix_equipment ()
