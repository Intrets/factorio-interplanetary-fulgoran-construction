require("__intrets-lib__.util.table")
require("__intrets-lib__.util.math")
require("__intrets-lib__.util.vector")
require("__intrets-lib__.rework-control")


local dimensional_builder_range = 30

local dimensional_receiver_table = nil
local dimensional_accumulator_table = nil
local ghosts_table = nil
local item_request_proxy_table = nil
local entities_with_upgrades_table = nil

local dummy_surface = nil
local dummy = nil

rework_control.add_setup(
    "dimensional receivers",
    function()
        dimensional_receiver_table = rework_control.track_entities("dimensional receivers", "dimensional-receiver")
        dimensional_accumulator_table = rework_control.track_entities("dimensional accumulators", "dimensional-accumulator")
        ghosts_table = rework_control.track_entities("ghosts", "entity-ghost")
        item_request_proxy_table = rework_control.track_entities("request proxies", "item-request-proxy", true)
        entities_with_upgrades_table = rework_control.track_upgrades("upgrades")

        dummy_surface = game.get_surface("rework-dummy-dimension")
        if dummy_surface == nil then
            dummy_surface = game.create_surface("rework-dummy-dimension")
        end

        for _, force in pairs(game.forces) do
            force.set_surface_hidden(dummy_surface, true)
        end

        local characters = dummy_surface.find_entities_filtered { name = "character" }
        local character = characters[1]

        if character == nil then
            character = dummy_surface.create_entity { name = "character", position = { 0, 0 }, force = "player" }
        end

        dummy = character
    end
)

rework_control.on_event("hide dummy dimension", defines.events.on_force_created, function(event)
    event.force.set_surface_hidden(dummy_surface, true)
end)

local gui = nil
local gui_value = nil
local redo_count = nil
local undo_count = nil

function add_test_label(gui, name, initial_value)
    local element = gui[name]

    if element == nil then
        element = gui.add {
            type = "label",
            name = name,
            label = initial_value
        }
    end

    return element
end

function add_test_frame(gui, name)
    local element = gui[name]

    if element == nil then
        element = gui.add {
            type = "frame",
            name = name,
            direction = "vertical",
            caption = name
        }
    end

    return element
end

local function play_dimensional_effect(position, surface_index)
    local lightning_position = rmath.sub_vec2(position, rmath.vec2(0, 25))
    game.surfaces[surface_index].create_entity { name = "lightning", position = lightning_position }
end

rework_control.on_event(
    "dimensional roboport testing",
    defines.events.on_tick,
    function(event)
        local powered_surfaces = {}

        local accumulator_charged = false

        local process_dimensional_accumulator = function(accumulator_info)
            local accumulator = accumulator_info[1]
            if accumulator.valid then
                if accumulator.energy >= 5000000000 then
                    accumulator_charged = true
                end
                accumulator_charged = true

                accumulator.energy = 0
                return true
            else
                return false
            end
        end

        for surface_index, accumulators in pairs(dimensional_accumulator_table) do
            rvector.filter(accumulators, process_dimensional_accumulator)
        end


        if accumulator_charged then
            local process_dimensional_receiver = function(receiver_info)
                local receiver = receiver_info[1]
                if receiver.valid then
                    if receiver.energy >= receiver.power_usage then
                        powered_surfaces[receiver.surface_index] = true
                    end
                    return true
                else
                    return false
                end
            end

            for surface_index, receivers in pairs(dimensional_receiver_table) do
                rvector.filter(receivers, process_dimensional_receiver)
            end
        end

        local loop_count = 100
        local spawns = 1

        for surface_index, entities_with_upgrades in pairs(entities_with_upgrades_table) do
            local end_index = entities_with_upgrades.end_index

            if powered_surfaces[surface_index] ~= nil and end_index ~= 0 then
                local spawn_chances = 10

                local surface = game.surfaces[surface_index]
                local logistic_network = surface.find_closest_logistic_network_by_position({ 0, 0 }, "player")

                if logistic_network ~= nil then
                    for i = 1, loop_count do
                        local current_index = (entities_with_upgrades.current_index or 0) % end_index

                        local entity_with_upgrade_info = entities_with_upgrades.elements[current_index]

                        if entity_with_upgrade_info ~= nil then
                            local entity_with_upgrade = entity_with_upgrade_info[1]
                            if entity_with_upgrade.valid then
                                local upgrade_target, quality = entity_with_upgrade.get_upgrade_target()
                                if upgrade_target ~= nil then
                                    local items = upgrade_target.items_to_place_this

                                    for _, _item in pairs(items) do
                                        local item = { name = _item.name, count = 1, quality = quality }

                                        local result = logistic_network.get_item_count(item)
                                        if result ~= 0 and logistic_network.remove_item(item) ~= 0 then
                                            local entity_position = entity_with_upgrade.position
                                            local entity_force = entity_with_upgrade.force

                                            dummy.teleport({ 0, 0 }, surface)

                                            local result = game.surfaces[surface_index].create_entity {
                                                name = upgrade_target.name,
                                                position = entity_position,
                                                quality = item.quality,
                                                force = entity_force,
                                                fast_replace = true,
                                                -- player = game.players[1],
                                                character = dummy,
                                            }

                                            if result ~= nil then
                                                local spill_inventory = dummy.get_main_inventory()
                                                local spill_items = spill_inventory.get_contents()
                                                for _, spill_item in pairs(spill_items) do
                                                    local result_inserted = logistic_network.insert(spill_item)
                                                    local remaining = spill_item.count - result_inserted
                                                    if remaining > 0 then
                                                        spill_item.count = remaining
                                                        surface.spill_item_stack {
                                                            position = entity_position,
                                                            stack = spill_item,
                                                            force = entity_force,
                                                            allow_belts = false
                                                        }
                                                    end
                                                end
                                                spill_inventory.clear()

                                                dummy.teleport({ 0, 0 }, dummy_surface)

                                                play_dimensional_effect(entity_position, surface_index)
                                                spawns = spawns - 1
                                                if spawns == 0 then
                                                    goto stop
                                                end
                                            else
                                                logistic_network.insert(item)

                                                spawn_chances = spawn_chances - 1
                                                if spawn_chances == 0 then
                                                    goto stop
                                                end
                                            end
                                            break
                                        end
                                    end

                                    spawn_chances = spawn_chances - 1
                                    if spawn_chances == 0 then
                                        goto stop
                                    end
                                else
                                    rework_control.remove_upgrade_by_index(entities_with_upgrades, current_index)
                                end
                            else
                                rework_control.remove_upgrade_by_index(entities_with_upgrades, current_index)
                            end
                        end

                        entities_with_upgrades.current_index = current_index - 1
                    end
                end
            end
        end

        for surface_index, proxies in pairs(item_request_proxy_table) do
            local end_index = proxies.end_index

            if powered_surfaces[surface_index] ~= nil and end_index ~= 0 then
                local spawn_chances = 10

                local logistic_network = game.surfaces[surface_index].find_closest_logistic_network_by_position({ 0, 0 }, "player")

                if logistic_network ~= nil then
                    for i = 1, loop_count do
                        local current_index = (proxies.current_index or 0) % end_index

                        local proxy_info = proxies.elements[current_index]

                        if proxy_info ~= nil then
                            local proxy = proxy_info[1]

                            if proxy.valid then
                                local entity_target = proxy.proxy_target

                                local insert_plans = proxy.insert_plan

                                for insert_plan_index, insert_plan in pairs(insert_plans) do
                                    local item = insert_plan.id

                                    local available = logistic_network.get_item_count(item)
                                    if available > 0 then
                                        local item_inventory_positions = insert_plan.items

                                        if item_inventory_positions.in_inventory ~= nil then
                                            for index, inventory_position in pairs(item_inventory_positions.in_inventory) do
                                                local inventory_index = inventory_position.inventory

                                                -- 0 indexed: https://forums.factorio.com/viewtopic.php?f=7&t=118217
                                                local stack_index = inventory_position.stack + 1

                                                local item_count = inventory_position.count or 1

                                                local item_inserted = false
                                                local item_stack_target = entity_target.get_inventory(inventory_index)[stack_index]
                                                if not item_stack_target.valid_for_read then -- empty stack
                                                    item_stack_target.set_stack(item)
                                                    item_inserted = true
                                                else -- items in the slot
                                                    if item_stack_target.name == item.name then
                                                        item_stack_target.count = item_stack_target.count + 1
                                                        item_inserted = true
                                                    end
                                                end
                                                a = 1

                                                if item_inserted then
                                                    logistic_network.remove_item(item)

                                                    if item_count == 1 then
                                                        table.remove(item_inventory_positions.in_inventory, index)
                                                        if #item_inventory_positions.in_inventory == 0 then
                                                            table.remove(insert_plans, insert_plan_index)
                                                        end
                                                    else
                                                        item_inventory_positions.in_inventory[index].count = item_count - 1
                                                    end

                                                    play_dimensional_effect(entity_target.position, surface_index)

                                                    proxy.insert_plan = insert_plans

                                                    goto stop
                                                end
                                            end
                                        end
                                    end
                                end
                            else
                                rework_control.remove_by_index(proxies, current_index)
                            end
                        end

                        proxies.current_index = current_index - 1
                    end
                end
            end
        end

        for surface_index, ghosts in pairs(ghosts_table) do
            local end_index = ghosts.end_index
            if powered_surfaces[surface_index] ~= nil and end_index ~= 0 then
                local spawn_chances = 10

                local logistic_network = game.surfaces[surface_index].find_closest_logistic_network_by_position({ 0, 0 }, "player")

                if logistic_network ~= nil then
                    for i = 1, loop_count do
                        local current_index = (ghosts.current_index or 0) % end_index

                        local ghost_info = ghosts.elements[current_index]

                        if ghost_info ~= nil then
                            local ghost = ghost_info[1]


                            if ghost.valid then
                                local items = ghost.ghost_prototype.items_to_place_this

                                for _, _item in pairs(items) do
                                    local item = { name = _item.name, count = 1, quality = ghost.quality }

                                    local result = logistic_network.get_item_count(item)
                                    if result ~= 0 and logistic_network.remove_item(item) ~= 0 then
                                        local entity_position = ghost.position
                                        local collisions, created_entity, item_request_proxy = ghost.revive { raise_revive = true }
                                        if created_entity ~= nil then
                                            play_dimensional_effect(entity_position, surface_index)
                                            rework_control.remove_by_index(ghosts, current_index)
                                            spawns = spawns - 1
                                            if spawns == 0 then
                                                goto stop
                                            end
                                        end

                                        spawn_chances = spawn_chances - 1
                                        if spawn_chances == 0 then
                                            goto stop
                                        end

                                        break
                                    end
                                end

                                spawn_chances = spawn_chances - 1
                                if spawn_chances == 0 then
                                    goto stop
                                end

                                ghosts.current_index = current_index - 1
                            else
                                rework_control.remove_by_index(ghosts, current_index)
                            end
                        end

                        ghosts.current_index = current_index - 1
                    end
                end
            end
        end

        ::stop::
    end)
