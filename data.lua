local item_sounds = require("__base__.prototypes.item_sounds")
local item_tints = require("__base__.prototypes.item-tints")
local hit_effects = require("__base__.prototypes.entity.hit-effects")
local sounds = require("__base__.prototypes.entity.sounds")
local simulations = require("__base__.prototypes.factoriopedia-simulations")

require("__base__.prototypes.entity.entities")

require("__intrets-lib__.util.data-utils")

data:extend({
    make_recipe {
        name = "dimensional-receiver",
        category = "crafting-with-fluid",
        energy_required = 5,
        ingredients = (function()
            if mods["spage-age"] ~= nil then
                return {
                    { type = "item",  name = "supercapacitor", amount = 8 },
                    { type = "item",  name = "accumulator",    amount = 1 },
                    { type = "fluid", name = "electrolyte",    amount = 80 },
                }
            else
                return {
                    { type = "item",  name = "battery",     amount = 20 },
                    { type = "item",  name = "accumulator", amount = 1 },
                    { type = "fluid", name = "electrolyte", amount = 80 },
                }
            end
        end)(),
        results = { { type = "item", name = "dimensional-receiver", amount = 1 } },
        enabled = true
    },
    make_item { name = "dimensional-receiver", subgroup = "logistic-network", },
    make_entity {
        name = "dimensional-receiver",
        prototype = "electric-energy-interface",
        collision_box = { { -1.8, -1.8 }, { 1.8, 1.8 } },
        selection_box = { { -2, -2 }, { 2, 2 } },
        energy_source =
        {
            type = "electric",
            usage_priority = "secondary-input",
            buffer_capacity = "500MJ",
            input_flow_limit = "1500MW",
        },
        energy_usage = "1000MW",
    },
})

data:extend({
    {
        type = "recipe",
        name = "dimensional-accumulator",
        category = "crafting-with-fluid",
        energy_required = 5,
        ingredients =
        {
            { type = "item",  name = "supercapacitor", amount = 8 },
            { type = "item",  name = "accumulator",    amount = 1 },
            { type = "fluid", name = "electrolyte",    amount = 80 },
        },
        results = { { type = "item", name = "dimensional-accumulator", amount = 1 } },
        enabled = true
    },
    make_item { name = "dimensional-accumulator", subgroup = "logistic-network" },
    make_entity {
        name = "dimensional-accumulator",
        type = "accumulator",
        fast_replaceable_group = "accumulator",
        collision_box = { { -0.9, -0.9 }, { 0.9, 0.9 } },
        selection_box = { { -1, -1 }, { 1, 1 } },
        energy_source =
        {
            type = "electric",
            buffer_capacity = "500000MJ",
            usage_priority = "primary-input",
            input_flow_limit = "500000MW",
            output_flow_limit = "0kW"
        },
    },
})
