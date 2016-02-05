%%
%% @doc direct test check (dtchk) provider for rebar3
%%
%% This provider will determine the length of the call path between a test 
%% function and any function called in the target module.
%%
%% This code based in part on the xref provider from the rebar3 project
%% https://github.com/rebar/rebar3/blob/master/src/rebar_prv_xref.erl
%%
%% Copyright Lutz Behnke 2016
%%
%% The code is licensed under the Apache 2.0 License.

-module(dtchk_prv).
-behaviour(provider).

-export([init/1, 
         do/1, 
         format_error/1]).

-include("rebar.hrl").
-include_lib("providers/include/providers.hrl").

-define(PROVIDER, dtchk).
-define(DEPS, [compile]).

%% ===================================================================
%% Public API
%% ===================================================================
-spec init(rebar_state:t()) -> {ok, rebar_state:t()}.
init(State) ->
    Provider = providers:create([
            {name, ?PROVIDER},          % The 'user friendly' name of the task
            {module, ?MODULE},          % The module implementation of the task
            {bare, true},               % The task can be run by the user, always true
            {deps, ?DEPS},              % The list of dependencies
            {example, "rebar dtchk"},   % How to use the plugin
            {opts, []},                 % list of options understood by the plugin
            {short_desc, short_desc()},
            {desc, desc()}
    ]),
    {ok, rebar_state:add_provider(State, Provider)}.


-spec do(rebar_state:t()) -> {ok, rebar_state:t()} | {error, string()}.
do(State) ->
    code:add_pathsa(rebar_state:code_paths(State, all_deps)),
    XrefChecks = prepare(State),

    %% Run xref checks
    ?INFO("Running cross reference analysis...", []),
    XrefResults = xref_checks(XrefChecks),

    %% Run custom queries
    QueryChecks = rebar_state:get(State, xref_queries, []),
    QueryResults = lists:foldl(fun check_query/2, [], QueryChecks),
    stopped = xref:stop(xref),
    rebar_utils:cleanup_code_path(rebar_state:code_paths(State, default)),
    case XrefResults =:= [] andalso QueryResults =:= [] of
        true ->
            {ok, State};
        false ->
            ?PRV_ERROR({xref_issues, XrefResults, QueryResults})
    end.

-spec format_error(any()) -> iolist().
format_error(Reason) ->
    io_lib:format("~p", [Reason]).

%% ===================================================================
%% Internal functions
%% ===================================================================

short_desc() ->
    "List the minimal call path distance between tests and target module".

desc() ->
    io_lib:format(
      "~s~n"
      "~n"
      "Valid rebar.config options:~n"
      "  ~p~n"
      "  ~p~n"
      "  ~p~n"
      "  ~p~n",
      [short_desc()
      ]).

