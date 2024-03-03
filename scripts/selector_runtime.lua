local SelectorAppearance = require("scripts.selector_appearance")

-- Get the different implementations of on_tick
local IndexMode = require("scripts.on_tick.index_mode")
local CountInputsMode = require("scripts.on_tick.count_inputs_mode")
local RandomInputMode = require("scripts.on_tick.random_input_mode")
local StackSizeMode = require("scripts.on_tick.stack_size_mode")
local QualityTransferMode = require("scripts.on_tick.quality_transfer_mode")

---@class SelectorRuntime
local SelectorRuntime = {}

-- [ mode ]
-- "index"
-- - sort the input signals in ascending or descending order, then output the signal at the specified index

-- "count_inputs"
-- - count the number of input signals, then output the result

-- "random_input"
-- - output a randomly selected signal from among the inputs

-- "stack_size"
-- - output the stack sizes of the input signals

-- "quality_transfer"
-- - transfer the quality of an input signal to the output signal(s)

---@class Selector
---@field settings SelectorSettings
---@field input_entity LuaEntity
---@field output_entity LuaEntity
---@field control_behavior LuaConstantCombinatorControlBehavior
---@field on_tick function?
---@field cache SelectorCache?


---@class SelectorSettings
---@field mode string
---@field index_order string
---@field index_constant number
---@field index_signal SignalID|string?
---@field count_signal SignalID|string?
---@field interval number
---@field quality_selection_signal SignalID|string?
---@field quality_target_signal SignalID|string?


---@class SelectorCache
---@field old_inputs table<number, SignalID>?
---@field sort function?
---@field input_count number?
---@field output table?

function SelectorRuntime.init()
    ---@type table<number, Selector>
    global.selector_combinators = {}
    global.rng = game.create_random_generator()
end

---@param unit_number number
---@return Selector?
function SelectorRuntime.find_selector_entry_by_unit_number(unit_number)
    return global.selector_combinators[unit_number]
end

---@param event EventData.on_built_entity | EventData.on_robot_built_entity
function SelectorRuntime.add_combinator(event)
    local entity = event.created_entity

    -- Register the entity for the destruction event.
    script.register_on_entity_destroyed(entity)

    -- Create the invisible output constant combinator
    local output_entity = assert(
        entity.surface.create_entity {
            name = "selector-out-combinator",
            position = entity.position,
            force = entity.force,
            fast_replace = false,
            raise_built = false,
            create_build_effect_smoke = false,
        },
        "Failed to create output entity"
    )

    -- Create a control behavior so that the output combinator can have signals set on it.
    ---@class LuaConstantCombinatorControlBehavior
    local control_behavior = assert(output_entity.get_or_create_control_behavior(), "Failed to get/create control behavior")

    -- Connect the output entity to the outputs of the selector combinator, so that the outputs are connected 
    -- parallel with the actual outputs of the selector combinator.
    entity.connect_neighbour {
        wire = defines.wire_type.red,
        target_entity = output_entity,
        source_circuit_id = defines.circuit_connector_id.combinator_output,
    }

    entity.connect_neighbour {
        wire = defines.wire_type.green,
        target_entity = output_entity,
        source_circuit_id = defines.circuit_connector_id.combinator_output,
    }

    -- Create and store the global data entry
    ---@type Selector
    local selector = {
        settings = {
            mode = "index",

            index_order = "descending",
            index_constant = 0,
            index_signal = nil,

            count_signal = nil,
            
            interval = 0,

            quality_selection_signal = nil,
            quality_target_signal = nil,
        },

        input_entity = entity,
        output_entity = output_entity,

        control_behavior = control_behavior,
        cache = nil,
    }

    local tags = event.tags and event.tags["selector-combinator"] or nil
    if (type(tags) == "table") then
        selector.settings = util.table.deepcopy(tags)
    end

    global.selector_combinators[entity.unit_number] = selector

    -- Update the initial appearance
    SelectorAppearance.update_combinator_appearance(selector)

    -- Get this selector into its running state
    SelectorRuntime.clear_caches_and_force_update(selector)
end

function SelectorRuntime.remove_combinator(unit_number)
    local selector = global.selector_combinators[unit_number]

    global.selector_combinators[unit_number] = nil

    if selector and selector.output_entity then
        selector.output_entity.destroy()
    end
end

-- Reset the caches of a selector and force an update.
-- Trigger this whenever we migrate, change anything in the Selector GUI, or paste settings.
-- By doing this work only when settings change, we minimize the work required in each on_tick.
---@param selector Selector
function SelectorRuntime.clear_caches_and_force_update(selector)
    -- 1. Reset cache and output
    selector.on_tick = nil
    selector.cache = {}
    selector.control_behavior.parameters = nil

    -- 2. Detect the mode, set our cached on_tick hander, and create the caches we need
    if selector.settings.mode == "index" then
        selector.on_tick = IndexMode.on_tick

        selector.cache.old_inputs = {}

        if selector.settings.index_order == "ascending" then
            selector.cache.sort = function(a, b) return a.count < b.count end
        else
            selector.cache.sort = function(a, b) return a.count > b.count end
        end

    elseif selector.settings.mode == "count_inputs" then
        selector.on_tick = CountInputsMode.on_tick

        selector.cache.input_count = 0

        if selector.settings.count_signal then
            selector.cache.output = {{
                signal = selector.settings.count_signal,
                -- Don't set .count; it will be written before we ever output it.
                index = 1
            }}
        end

    elseif selector.settings.mode == "random_input" then
        selector.on_tick = RandomInputMode.on_tick

    elseif selector.settings.mode == "stack_size" then
        selector.on_tick = StackSizeMode.on_tick

        selector.cache.old_inputs = {}

    elseif selector.settings.mode == "quality_transfer" then
        selector.on_tick = QualityTransferMode.on_tick

    else
        game.print("Selector combinator: mode unrecognized: " .. selector.settings.mode)
    end

    -- 3. Update this combinator
    selector:on_tick()
end

return SelectorRuntime
