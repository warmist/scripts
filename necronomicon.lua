-- Author: Ajhaa

-- lists books that contain secrets to life and death

function get_book_interactions(item)
    local book_interactions = {}
    for _, improvement in ipairs(item.improvements) do
        if improvement._type == df.itemimprovement_pagesst or
           improvement._type == df.itemimprovement_writingst then
            for _, content_id in ipairs(improvement.contents) do
                written_content = df.written_content.find(content_id)

                for _, ref in ipairs (written_content.refs) do
                    if ref._type == df.general_ref_interactionst then
                        local interaction = df.global.world.raws.interactions[ref.interaction_id]
                        table.insert(book_interactions, interaction)
                    end
                end
            end
        end
    end

    return book_interactions
end

-- should we check that the interaction is actually a SECRET
function is_secrets_book(item)
    local interactions = get_book_interactions(item)

    return next(interactions) ~= nil
end

function check_slab_secrets(item)
    local type_id = item.engraving_type
    local type = df.slab_engraving_type[type_id]
    return type == "Secrets"
end

function get_item_artifact(item)
    for _, ref in ipairs(item.general_refs) do
        if ref._type == df.general_ref_is_artifactst then
            return df.global.world.artifacts.all[ref.artifact_id]
        end
    end
end

function print_interactions(interactions)
    for _, interaction in ipairs(interactions) do
        -- Search interaction.str for the tag [CDI:ADV_NAME:<string>]
        -- for example: [CDI:ADV_NAME:Raise fetid corpse]
        for _, str in ipairs(interaction.str) do
            local _, e = string.find(str.value, "ADV_NAME")
            if e then
                print("\t", string.sub(str.value, e + 2, #str.value - 1))
            end
        end
    end
end

function necronomicon(scope)
    if scope == "fort" then
        print("SLABS:")
        for _, item in ipairs(df.global.world.items.other.SLAB) do
            if check_slab_secrets(item) then
                artifact = get_item_artifact(item)
                name = dfhack.TranslateName(artifact.name)
                print(dfhack.df2console(name))
            end
        end
        print("\nBOOKS:")
        for _, item in ipairs(df.global.world.items.other.BOOK) do
            if is_secrets_book(item) then
                print(item.title)
                print_interactions(interactions)
            end
        end
    elseif scope == "world" then
        -- currently not in use by the script, because the information might be invalid and useless
        -- use written contents instead of artifacts?
        for _, artifact in ipairs(df.global.world.artifacts.all) do
            local item = artifact.item

            if item._type == df.item_bookst then
                local interactions = get_book_interactions(item)
                if next(interactions) ~= nil then
                    print(item.title, artifact.id)
                    print_interactions(interactions)
                end
            end

            if item._type == df.item_slabst then
                if check_slab_secrets(item) then
                    local name = dfhack.TranslateName(artifact.name)
                    print(dfhack.df2console(name))
                end
            end
        end
    end
end


local args = {...}
local cmd = args[1]


if cmd == "" or cmd == nil then
    necronomicon("fort")
else
    print("invalid argument")
end
