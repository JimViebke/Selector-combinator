local Util = {}

function Util.quality_suffix_position(name)
    return string.find(name, "-quality-", 1, true)
end

function Util.signal_name_has_suffix(name)
    return Util.quality_suffix_position(name) ~= nil
end

function Util.without_quality_suffix(name)
    local end_of_name = Util.quality_suffix_position(name)

    if end_of_name then
        return string.sub(name, 1, end_of_name - 1)
    else
        return name
    end
end

-- Janky way of making sure a signal name we're assembling is a real signal
function Util.is_real_signal(name)
    if game.item_prototypes[name] or game.virtual_signal_prototypes[name] then
        return true
    end
    return false
end

return Util
