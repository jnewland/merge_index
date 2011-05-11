-module(merge_index_tests).
-compile(export_all).
-import(common, [g_i/0, g_f/0, g_t/0, g_props/0, g_value/0]).

-include_lib("eqc/include/eqc.hrl").
-include_lib("eqc/include/eqc_statem.hrl").
-include_lib("eunit/include/eunit.hrl").
-include("common.hrl").

-record(state, {server_pid,
                postings=[]}).

prop_api_test_() ->
    {timeout, 60,
     fun() ->
            ?assert(eqc:quickcheck(?QC_OUT(prop_api())))
     end
    }.

prop_api() ->
    application:load(merge_index),

    ?FORALL(Cmds, commands(?MODULE),
            begin
                {_H, _S, Res} = run_commands(?MODULE, Cmds),

                case Res of
                    ok -> true;
                    _ -> io:format(user,
                                   "QC History: ~p~n"
                                   "QC State: ~p~n"
                                   "QC result: ~p~n",
                                   [_H, _S, Res])
                end
            end).

%% ====================================================================
%% eqc_statem callbacks
%% ====================================================================

initial_state() ->
    #state{}.

command(#state{server_pid=undefined}) ->
    {call,?MODULE,init,[]};
command(S) ->
    P = S#state.server_pid,
    oneof([{call,?MODULE,index, [P,g_postings()]},
           {call,?MODULE,is_empty, [P]}]).

next_state(S, Pid, {call,_,init,_}) ->
    S#state{server_pid=Pid};
next_state(S, _Res, {call,_,index,[_,Postings]}) ->
    case Postings of
        [] -> S;
        _ ->
            Postings0 = S#state.postings,
            S#state{postings=Postings0++Postings}
    end;
next_state(S, _Res, {call,_,is_empty,_}) -> S.

precondition(_,_) ->
    true.

postcondition(S, {call,_,is_empty,[P]}, V) ->
    case S#state.postings of
        [] -> V =:= true;
        _ -> V =:= false
    end;
postcondition(_,_,_) -> true.

%% ====================================================================
%% generators
%% ====================================================================

g_pos_tstamp() ->
    choose(0, ?POW_2(31)).

g_postings() ->
    list({g_i(), g_f(), g_t(), g_value(), g_props(), g_pos_tstamp()}).

%% ====================================================================
%% wrappers
%% ====================================================================
init() ->
    Root = "/tmp/test/prop_api",
    os:cmd(?FMT("rm -rf ~s; mkdir -p ~s", [Root, Root])),
    merge_index:start_link(Root),
    {ok, Pid} = merge_index:start_link(Root),
    Pid.

index(Pid, Postings) ->
    merge_index:index(Pid, Postings).

is_empty(Pid) ->
    merge_index:is_empty(Pid).