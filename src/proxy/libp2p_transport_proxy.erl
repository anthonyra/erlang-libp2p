-module(libp2p_transport_proxy).

-behavior(libp2p_transport).

-export([
    start_link/1,
    start_listener/2,
    match_addr/2,
    sort_addrs/1,
    priority/0,
    connect/4
]).

%% ------------------------------------------------------------------
%% libp2p_transport
%% ------------------------------------------------------------------
-spec start_link(ets:tab()) -> ignore.
start_link(_TID) ->
    ignore.

-spec start_listener(pid(), string()) -> {error, unsupported}.
start_listener(_Pid, _Addr) ->
    {error, unsupported}.

-spec match_addr(string(), ets:tab()) -> false.
match_addr(Addr, _TID) when is_list(Addr) ->
    false.

-spec sort_addrs([string()]) -> [string()].
sort_addrs(Addrs) ->
    Addrs.

-spec priority() -> integer().
priority() -> 99.

-spec connect(Transport::pid(), MAddr::string(), Opts::map(), TID::ets:tab()) -> {ok, pid()} | {error, term()}.
connect(_Pid, MAddr, _Options, TID) ->
    {ok, {PAddress, AAddress}} = libp2p_relay:p2p_circuit(MAddr),
    lager:info("init proxy with ~p", [[PAddress, AAddress]]),
    Swarm = libp2p_swarm:swarm(TID),
    ID = crypto:strong_rand_bytes(16),
    Args = [
        {p2p_circuit, MAddr},
        {transport, self()},
        {id, ID}
           ],
    case libp2p_proxy:dial_framed_stream(Swarm, PAddress, Args) of
        {error, Reason} ->
            lager:error("failed to dial proxy server ~p ~p", [PAddress, Reason]),
            {error, fail_dial_proxy};
        {ok, _} ->
            receive
                {proxy_negotiated, Socket, MultiAddr} ->
                    Conn = libp2p_transport_tcp:new_connection(Socket, MultiAddr),
                    lager:info("proxy successful ~p", [Conn]),
                    libp2p_transport:start_client_session(TID, MAddr, Conn)
            after 8000 ->
                      {error, timeout_relay_session}
            end
    end.

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------
