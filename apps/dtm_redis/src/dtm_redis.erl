%% Copyright (C) 2011-2013 IMVU Inc.
%%
%% Permission is hereby granted, free of charge, to any person obtaining a copy of
%% this software and associated documentation files (the "Software"), to deal in
%% the Software without restriction, including without limitation the rights to
%% use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
%% of the Software, and to permit persons to whom the Software is furnished to do
%% so, subject to the following conditions:
%%
%% The above copyright notice and this permission notice shall be included in all
%% copies or substantial portions of the Software.
%%
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
%% SOFTWARE.

-module(dtm_redis).
-export([get/1, set/2, delete/1]).
-export([watch/1, unwatch/0, multi/0, exec/0]).

-include("protocol.hrl").

-type value() :: binary() | list() | atom().
-type display_status() :: ok | error.
-type display_integer() :: integer().
-type display_value() :: binary() | none.
-type display_list() :: [display_status() | display_integer() | display_value()].
-type display_multi() :: [display_status() | display_integer() | display_value() | display_list()].

% public api

-spec get(value()) -> display_value(). 
get(Key) -> show_reply(session:call(shell, make_operation(<<"GET">>, Key))).

-spec set(value(), value()) -> display_status().
set(Key, Value) -> show_reply(session:call(shell, make_operation(<<"SET">>, Key, [Value]))).

-spec delete(value()) -> display_integer().
delete(Key) -> show_reply(session:call(shell, make_operation(<<"DEL">>, Key))).

-spec watch(value()) -> display_status().
watch(Key) -> show_reply(session:call(shell, make_operation(<<"WATCH">>, Key))).

-spec unwatch() -> display_status().
unwatch() -> show_reply(session:call(shell, make_operation(<<"UNWATCH">>))).

-spec multi() -> display_status().
multi() -> show_reply(session:call(shell, make_operation(<<"MULTI">>))).

-spec exec() -> display_multi().
exec() -> show_reply(session:call(shell, make_operation(<<"EXEC">>))).

% private methods

-spec make_operation(binary()) -> #operation{}.
make_operation(Command) ->
    make_operation(Command, none).

-spec make_operation(binary(), value()) -> #operation{}.
make_operation(Command, Key) ->
    make_operation(Command, Key, []).

-spec make_operation(binary(), value() | none, [value()]) -> #operation{}.
make_operation(Command, none, []) ->
    #operation{command=Command, key=none, arguments=[]};
make_operation(Command, Key, Arguments) ->
    #operation{command=Command, key=redis_stream:make_binary(Key), arguments=[redis_stream:make_binary(Arg) || Arg <- Arguments]}.

-spec show_reply(simple_reply() | #multi_bulk_reply{}) -> display_status() | display_integer() | display_value() | display_list() | display_multi().
show_reply(#status_reply{message=Message}) ->
    status_to_atom(Message);
show_reply(#error_reply{type=Type, message=Message}) ->
    lists:flatten(io_lib:format("error ~s ~s", [binary_to_list(Type), binary_to_list(Message)]));
show_reply(#integer_reply{value=Value}) ->
    list_to_integer(binary_to_list(Value));
show_reply(#bulk_reply{content=none}) ->
    nil;
show_reply(#bulk_reply{content=Content}) ->
    binary_to_list(Content);
show_reply(#multi_bulk_reply{items=Items}) ->
    [show_reply(X) || X <- Items];
show_reply(Replies) when is_list(Replies) ->
    [show_reply(X) || X <- Replies].

-spec status_to_atom(binary()) -> atom().
status_to_atom(<<"OK">>) -> ok;
status_to_atom(<<"STORED">>) -> stored.

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

make_command_only_operation_test() ->
    #operation{command= <<"foo">>, key=none, arguments=[]} = make_operation(<<"foo">>).

make_command_with_key_operation_test() ->
    #operation{command= <<"foo">>, key= <<"bar">>, arguments=[]} = make_operation(<<"foo">>, <<"bar">>).

make_command_with_key_and_arguments_test() ->
    #operation{command= <<"foo">>, key= <<"bar">>, arguments=[<<"baz">>]} = make_operation(<<"foo">>, <<"bar">>, [<<"baz">>]).

show_status_reply_test() ->
    ok = show_reply(#status_reply{message= <<"OK">>}),
    stored = show_reply(#status_reply{message= <<"STORED">>}).

show_error_reply_test() ->
    "error ERR foo bar baz" = show_reply(#error_reply{type= <<"ERR">>, message= <<"foo bar baz">>}).

show_integer_reply_test() ->
    0 = show_reply(#integer_reply{value= <<"0">>}),
    1 = show_reply(#integer_reply{value= <<"1">>}),
    42 = show_reply(#integer_reply{value= <<"42">>}).

show_bulk_reply_test() ->
    "foo" = show_reply(#bulk_reply{content= <<"foo">>}).

show_empty_bulk_reply_test() ->
    nil = show_reply(#bulk_reply{content=none}).

show_multi_bulk_reply_test() ->
    [ok, 1, "foo"] = show_reply(#multi_bulk_reply{count=3, items=[
        #status_reply{message= <<"OK">>},
        #integer_reply{value= <<"1">>},
        #bulk_reply{content= <<"foo">>}
    ]}).

show_multi_replies_test() ->
    [ok, 1, "foo"] = show_reply([
        #status_reply{message= <<"OK">>},
        #integer_reply{value= <<"1">>},
        #bulk_reply{content= <<"foo">>}
    ]).

-endif.

