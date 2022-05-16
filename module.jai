// simple state machine system

#scope_file
BUILD_EXAMPLE :: false; // set to true & build this file to see it in action
#scope_export

State_Machine_Definition :: struct {
    states: [..] State_Definition;
    state_names: Table(string, int);
    State_Definition :: struct {
        name:      string;
        on_start:  (*State);
        on_update: (*State, float) -> bool;
        on_end:    (*State);
    }
}
State_Machine :: struct {
    definition: *State_Machine_Definition;
    data: *void;
    current_state: State;
    current_state_index: int;
    next_state_index: int = 1;
    started: bool;
    ended: bool;
}
State :: struct {
    definition: *State_Machine_Definition.State_Definition;
    data: *void;
    machine: *State_Machine;
}

define :: (
    using sm: *State_Machine_Definition,
    state_definitions: [] State_Machine_Definition.State_Definition
) {
    for state_definitions {
        if it.name != "" then table_add(*sm.state_names, it.name, sm.states.count);
        array_add(*sm.states, it);
    }
}
define :: (
    using sm: *State_Machine_Definition,
    state_definitions: ..State_Machine_Definition.State_Definition
) {
    for state_definitions {
        if it.name != "" then table_add(*sm.state_names, it.name, sm.states.count);
        array_add(*sm.states, it);
    }
}

init :: (smd: *State_Machine_Definition, sm_data: *void = null) -> State_Machine {
    assert(smd.states.count > 0);
    sm: State_Machine;
    using sm;
    definition = smd;
    data = sm_data;

    return sm;
}

update :: (using sm: *State_Machine, dt: float) -> bool {
    assert(!ended);
    if !started {
        current_state.definition = *definition.states[current_state_index];
        current_state.machine = sm;
        on_start := current_state.definition.on_start;
        if on_start then on_start(*current_state);
        started = true;
    }
    on_update := current_state.definition.on_update;
    if !on_update || on_update(*current_state, dt) {
        on_end := current_state.definition.on_end;
        if on_end then on_end(*current_state);
        current_state = .{};
        current_state_index = next_state_index;
        next_state_index += 1;
        if current_state_index >= definition.states.count {
            ended = true;
            return true;
        }
        current_state.definition = *definition.states[current_state_index];
        current_state.machine = sm;
        on_start := current_state.definition.on_start;
        if on_start then on_start(*current_state);
    }
    return false;
}

set_next :: (using sm: *State_Machine, state_name: string) {
    result, found := table_find(*sm.definition.state_names, state_name);
    assert(found);
    set_next(sm, result);
}
set_next :: (using sm: *State_Machine, state_index: int) {
    next_state_index = state_index;
}

#if BUILD_EXAMPLE then main :: () {
    Example_State_Machine_Data :: struct {
        foo: int;
        iterations_remaining: int = 2;
    }
    Example_State_Data :: struct {
        bar: int;
    }

    smd: State_Machine_Definition;
    define(*smd, .[
        .{"first",
            (state: *State) {
                log("does this work?");
                sleep_milliseconds(250);
            },
            (state: *State, dt: float) -> bool {
                log("heck yeah it does");
                sleep_milliseconds(250);
                return true;
            },
            (state: *State) {
                log("that was a trip");
                sleep_milliseconds(250);
            }
        }, .{"test_data",
            (state: *State) {
                log("now let's try to huck some data in there");
                sleep_milliseconds(250);
            },
            (state: *State, dt: float) -> bool {
                data := cast(*Example_State_Machine_Data) state.machine.data;
                old_foo := data.foo;
                data.foo += 1;
                log("wew % -> %", old_foo, data.foo);
                sleep_milliseconds(100);
                return data.foo > 4;
            },
            (state: *State) {
                log("hey, that worked!");
                sleep_milliseconds(250);
            }
        }, .{"test_state_data",
            (state: *State) {
                log("now let's see if we can make per-state data work too");
                state.data = New(Example_State_Data);
                sleep_milliseconds(250);
            },
            (state: *State, dt: float) -> bool {
                data := cast(*Example_State_Data) state.data;
                old_bar := data.bar;
                data.bar += 1;
                log("woah % -> %", old_bar, data.bar);
                sleep_milliseconds(100);
                return data.bar > 7;
            },
            (state: *State) {
                free(state.data);
                log("hey, THAT worked TOO!");
                sleep_milliseconds(250);
            }
        }, .{"penultimate",
            null,
            (state: *State, dt: float) -> bool {
                log("let's just show that you don't need an on_start");
                sleep_milliseconds(250);
                return true;
            },
            null
        }, .{"last",
            null,
            null,
            (state: *State) {
                log("heck, you can even just have an on_end, not that that makes sense");
                sleep_milliseconds(250);
                log("now let's try running the whole thing again unless we've done that twice in which case we're done");
                data := cast(*Example_State_Machine_Data) state.machine.data;
                data.iterations_remaining -= 1;
                if data.iterations_remaining > 0 then set_next(state.machine, "first");
            }
        }
    ]);

    data: Example_State_Machine_Data;
    sm := init(*smd, *data);
    // the empty loop here is kinda weird but you won't use a while loop (or a
    // hardcoded dt) when you use this for real (that's kinda the whole point)
    while !update(*sm, 0.016) {}
    log("...and we're done!");
}

#import "Basic";
#import "Hash_Table";
