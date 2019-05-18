%%%-------------------------------------------------------------------
%% @doc
%% == Libp2p Relay ==
%% @end
%%%-------------------------------------------------------------------
-module(libp2p_relay).

%% ------------------------------------------------------------------
%% API Function Exports
%% ------------------------------------------------------------------
-export([
    init/1,
    protocol_id/0,
    add_stream_handler/1,
    dial/3,
    p2p_circuit/1, p2p_circuit/2, is_p2p_circuit/1,
    reg_addr_sessions/1 ,reg_addr_sessions/2, unreg_addr_sessions/1,
    reg_addr_stream/1, reg_addr_stream/2, unreg_addr_stream/1
]).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

-define(RELAY_VERSION, "relay/1.0.0").
-define(P2P_CIRCUIT, "/p2p-circuit").

%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec init(pid()) -> {ok, pid()} | {error, any()} | ignore.
init(Swarm) ->
    libp2p_relay_server:relay(Swarm).

%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec protocol_id() -> binary().
protocol_id() ->
    <<?RELAY_VERSION>>.

%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec add_stream_handler(ets:tab()) -> ok.
add_stream_handler(TID) ->
    libp2p_swarm:add_stream_handler(TID, {protocol_id(), {libp2p_stream_relay, #{swarm => TID}}}).

%%--------------------------------------------------------------------
%% @doc
%% Dial relay stream
%% @end
%%--------------------------------------------------------------------
-spec dial(Swarm::pid(), MAddr::string(), Opts::map()) -> {ok, pid()} | {error, any()} | ignore.
dial(Swarm, Address, Opts) ->
    libp2p_swarm:dial(Swarm, Address, {protocol_id(), {libp2p_stream_relay, Opts#{swarm => Swarm}}}).

%%--------------------------------------------------------------------
%% @doc
%% Split p2p circuit address
%% @end
%%--------------------------------------------------------------------
-spec p2p_circuit(string()) -> {ok, {string(), string()}} | error.
p2p_circuit(P2PCircuit) ->
    case string:split(P2PCircuit, ?P2P_CIRCUIT) of
        [R, A] -> {ok, {R, A}};
        _ -> error
    end.

%%--------------------------------------------------------------------
%% @doc
%% Create p2p circuit address
%% @end
%%--------------------------------------------------------------------
-spec p2p_circuit(string(), string()) -> string().
p2p_circuit(R, A) ->
    R ++ ?P2P_CIRCUIT ++ A.

%%--------------------------------------------------------------------
%% @doc
%% Split p2p circuit address
%% @end
%%--------------------------------------------------------------------
-spec is_p2p_circuit(string()) -> boolean().
is_p2p_circuit(Address) ->
    case string:find(Address, ?P2P_CIRCUIT) of
        nomatch -> false;
        _ -> true
    end.

-spec reg_addr_sessions(string()) -> atom().
reg_addr_sessions(Address) ->
    erlang:list_to_atom(Address ++ "/sessions").

-spec reg_addr_sessions(string(), pid()) -> true.
reg_addr_sessions(Address, Pid) ->
    erlang:register(?MODULE:reg_addr_sessions(Address), Pid).

-spec unreg_addr_sessions(string()) -> true.
unreg_addr_sessions(Address) ->
    erlang:unregister(?MODULE:reg_addr_sessions(Address)).

-spec reg_addr_stream(string()) -> atom().
reg_addr_stream(Address) ->
    erlang:list_to_atom(Address ++ "/stream").

-spec reg_addr_stream(string(), pid()) -> true.
reg_addr_stream(Address, Pid) ->
    RegName = ?MODULE:reg_addr_stream(Address),
    case erlang:whereis(RegName) of
        undefined ->
            ok;
        RegPid ->
            RegPid ! stop,
            _ = ?MODULE:unreg_addr_stream(Address)
    end,
    erlang:register(RegName, Pid).

-spec unreg_addr_stream(string()) -> true.
unreg_addr_stream(Address) ->
    erlang:unregister(?MODULE:reg_addr_stream(Address)).

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

%% ------------------------------------------------------------------
%% EUNIT Tests
%% ------------------------------------------------------------------
-ifdef(TEST).

p2p_circuit_1_test() ->
    ?assertEqual(
        {ok, {"/ip4/192.168.1.61/tcp/6601", "/ip4/192.168.1.61/tcp/6600"}}
        ,p2p_circuit("/ip4/192.168.1.61/tcp/6601/p2p-circuit/ip4/192.168.1.61/tcp/6600")
    ),
    ok.

p2p_circuit_2_test() ->
    ?assertEqual("/abc/p2p-circuit/def", p2p_circuit("/abc", "/def")),
    ok.

is_p2p_circuit_test() ->
    ?assert(is_p2p_circuit("/ip4/192.168.1.61/tcp/6601/p2p-circuit/ip4/192.168.1.61/tcp/6600")),
    ?assertNot(is_p2p_circuit("/ip4/192.168.1.61/tcp/6601")),
    ?assertNot(is_p2p_circuit("/ip4/192.168.1.61/tcp/6601p2p-circuit/ip4/192.168.1.61/tcp/6600")),
    ok.

reg_addr_sessions_1_test() ->
    ?assertEqual(
        '/ip4/192.168.1.61/tcp/6601/sessions'
        ,reg_addr_sessions("/ip4/192.168.1.61/tcp/6601")
    ),
    ok.

reg_addr_sessions_2_test() ->
    ?assertEqual(
        true
        ,reg_addr_sessions("/ip4/192.168.1.61/tcp/6601", self())
    ),
    reg_addr_sessions("/ip4/192.168.1.61/tcp/6601") ! test,
    receive M -> ?assertEqual(M, test) end,
    ?assertEqual(
        true
        ,unreg_addr_sessions("/ip4/192.168.1.61/tcp/6601")
    ),
    ok.

reg_addr_stream_1_test() ->
    ?assertEqual(
        '/ip4/192.168.1.61/tcp/6601/stream'
        ,reg_addr_stream("/ip4/192.168.1.61/tcp/6601")
    ),
    ok.

reg_addr_stream_2_test() ->
    ?assertEqual(
        true
        ,reg_addr_stream("/ip4/192.168.1.61/tcp/6601", self())
    ),
    reg_addr_stream("/ip4/192.168.1.61/tcp/6601") ! test,
    receive M -> ?assertEqual(M, test) end,
    erlang:spawn(fun() ->
        ?assertEqual(
            true
            ,reg_addr_stream("/ip4/192.168.1.61/tcp/6601", self())
        )
    end),
    receive M1 -> ?assertEqual(M1, stop) end,
    ok.

-endif.
