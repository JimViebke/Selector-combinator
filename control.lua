require("__selector-combinator__.scripts.constants")
local util = require("__core__/lualib/util")
local SelectorAppearance = require("scripts.selector_appearance")
local SelectorGui = require("scripts.selector_gui")
local SelectorRuntime = require("scripts.selector_runtime")

script.on_init(function()
    SelectorRuntime.init()
end)

local selector_filter = {
    filter = "name",
    name = Constants.combinator_name,
}

local function on_added(event)
    SelectorRuntime.add_combinator(event)
end

local function on_entity_settings_pasted(event)
    local source = event.source
    local destination = event.destination

    if not source or not destination or
        source.name ~= Constants.combinator_name or
        destination.name ~= Constants.combinator_name then
        return
    end

    source = global.selector_combinators[source.unit_number]
    destination = global.selector_combinators[destination.unit_number]

    if not source or not destination then return end

    destination.settings = util.table.deepcopy(source.settings)

    SelectorAppearance.update_combinator_appearance(destination)

    -- Get this selector into its running state
    SelectorRuntime.clear_caches_and_force_update(destination)
end

local function get_blueprint(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    local bp = player.blueprint_to_setup
    if bp and bp.valid_for_read then
        return bp
    end

    bp = player.cursor_stack
    if not bp or not bp.valid_for_read then return end

    if bp.type == "blueprint-book" then
        local item_inventory = bp.get_inventory(defines.inventory.item_main)
        if item_inventory then
            bp = item_inventory[bp.active_index]
        else
            return
        end
    end

    return bp
end

local function on_player_setup_blueprint(event)
    local blueprint = get_blueprint(event)
    if not blueprint then return end

    local entities = blueprint.get_blueprint_entities()
    if not entities then return end

    for i, entity in pairs(entities) do
        if entity.name == Constants.combinator_name then
            local selector = event.surface.find_entity(entity.name, entity.position)
            if selector then
                selector = global.selector_combinators[selector.unit_number]
                if selector then
                    blueprint.set_blueprint_entity_tag(i, Constants.combinator_name,
                        util.table.deepcopy(selector.settings))
                end
            end
        end
    end
end

local function on_entity_destroyed(event)
    SelectorRuntime.remove_combinator(event.entity.unit_number)
end

local function on_destroyed(event)
    SelectorRuntime.remove_combinator(event.unit_number)
end

local function on_gui_opened(event)
    local entity = event.entity

    if not entity or not entity.valid or entity.name ~= Constants.combinator_name then
        return
    end

    local player = game.get_player(event.player_index)

    if player then
        SelectorGui.on_gui_added(player, entity)
    end
end

local function on_gui_closed(event)
    local element = event.element

    if not element or element.name ~= "selector_gui" then
        return
    end

    local player = game.get_player(event.player_index)

    if player then
        SelectorGui.on_gui_removed(player)
    end
end

SelectorGui.bind_all_events()

-- Added Events
script.on_event(defines.events.on_built_entity, on_added, { selector_filter })
script.on_event(defines.events.on_robot_built_entity, on_added, { selector_filter })

-- Paste events
script.on_event(defines.events.on_entity_settings_pasted, on_entity_settings_pasted)

-- Blueprint events
script.on_event(defines.events.on_player_setup_blueprint, on_player_setup_blueprint)

-- Removed Events
script.on_event(defines.events.on_player_mined_entity, on_entity_destroyed, { selector_filter })
script.on_event(defines.events.on_robot_mined_entity, on_entity_destroyed, { selector_filter })
script.on_event(defines.events.script_raised_destroy, on_entity_destroyed, { selector_filter })

-- *Special* Removed Events
script.on_event(defines.events.on_entity_destroyed, on_destroyed)

-- GUI Events
script.on_event(defines.events.on_gui_opened, on_gui_opened)
script.on_event(defines.events.on_gui_closed, on_gui_closed)

-- Update Event
functions_set_up = false
script.on_event(defines.events.on_tick, function()
    -- It's icky to check for this at runtime, but functions do not persist in global,
    -- and we cannot modify global in on_load(). It's still faster than having every
    -- combinator check its mode within a unified on_tick().
    if not functions_set_up then
        SelectorRuntime.set_functions()
        functions_set_up = true
    end

    for _, selector in pairs(global.selector_combinators) do
        selector:on_tick()
    end
end)
