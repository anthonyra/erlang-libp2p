-module(libp2p_group_relcast_handler).


-callback init(Args::any()) ->
    {ok, TargetAddrs::[libp2p_crypto:address()], State::handler_state()}
        | {error, term()}.
-callback handle_input(Msg::binary(), State::any()) -> handler_result().
-callback handle_message(Index::pos_integer(), Msg::binary(), State::any()) -> handler_result().
-callback serialize_state(State :: any()) -> handler_state().
-callback deserialize_state(handler_state()) -> any().

-type handler_state() :: binary().

-type handler_result() :: {State::handler_state(), ok | defer | {send, [message()]}}.

-type message() ::
        {unicast, Index::pos_integer(), Msg::message_value()} |
        {multicast, Msg::message_value()}.

-type message_key_prefix() :: <<_:128>>.
-type message_value() ::
        {message_key_prefix(), binary()} |
        binary().