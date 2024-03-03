local SelectorAppearance = {}

---@param selector Selector
function SelectorAppearance.update_combinator_appearance(selector)
    local mode = selector.settings.mode

    ---@class LuaControlBehavior
    local cb = selector.input_entity.get_or_create_control_behavior()
    local parameters = cb.parameters

    if mode == SelectorMode.index then
        if selector.settings.index_order == "ascending" then
            parameters.operation = "/"
        else
            parameters.operation = "*"
        end
    elseif mode == SelectorMode.count_inputs then
        parameters.operation = "-"
    elseif mode == SelectorMode.random_input then
        parameters.operation = "+"
    elseif mode == SelectorMode.stack_size then
        parameters.operation = "%"
    elseif mode == SelectorMode.quality_transfer then
        parameters.operation = "%"
    end
    
    -- All of parameters must be written back, not just particular fields.
    cb.parameters = parameters

end

return SelectorAppearance