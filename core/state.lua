local State = {}

State.current = "BOOT"

function State.set(state)

    State.current = state

end

function State.get()

    return State.current

end

function State.is(state)

    return State.current == state

end

return State