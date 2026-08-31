-module(executable_ffi).

-export([run_executable/3, find_executable/1]).

-spec run_executable(Name :: binary(), Directory :: binary(), Arguments :: [binary()]) ->
                        {ok, integer()} | {error, nil}.
run_executable(Name, Directory, Arguments) ->
    try
        StringName = unsafe_characters_to_list(Name),
        Port =
            erlang:open_port({spawn_executable, StringName},
                             [{args, Arguments},
                              {cd, Directory},
                              hide,
                              exit_status,
                              stderr_to_stdout,
                              use_stdio]),
        ExitStatus =
            receive
                {Port, {exit_status, Code}} ->
                    Code
            end,
        {ok, ExitStatus}
    catch
        error:_ ->
            {error, nil}
    end.

-spec find_executable(Name :: binary()) -> {ok, binary()} | {error, nil}.
find_executable(Name) ->
    case os:find_executable(unsafe_characters_to_list(Name)) of
        false ->
            {error, nil};
        Path ->
            {ok, unsafe_characters_to_binary(Path)}
    end.

-spec unsafe_characters_to_list(Name :: binary()) -> string().
unsafe_characters_to_list(Name) ->
    case unicode:characters_to_list(Name) of
        Result when is_list(Result) ->
            Result;
        Error ->
            throw({unsafe_characters_to_list, Error})
    end.

-spec unsafe_characters_to_binary(Name :: string()) -> binary().
unsafe_characters_to_binary(Name) ->
    case unicode:characters_to_binary(Name) of
        Result when is_binary(Result) ->
            Result;
        Error ->
            throw({unsafe_characters_to_binary, Error})
    end.
