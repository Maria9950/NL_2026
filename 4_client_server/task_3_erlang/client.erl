-module(client).
-export([main/0]).

-define(HOST, {127, 0, 0, 1}).
-define(PORT, 5053).
-define(CONNECT_TIMEOUT, 3000).
-define(REPLY_TIMEOUT, 5000).

main() ->
    io:setopts([{encoding, unicode}]),
    Status = case init:get_plain_arguments() of
                 [] ->
                     say("Использование: erl -noshell -pa /tmp -s client main -extra \"строка\""),
                     1;
                 Args ->
                     run(lists:join(" ", Args))
             end,
    init:stop(Status).

run(Text) ->
    case check(Text) of
        {ok, Reply} ->
            say(Reply),
            0;
        {error, Message} ->
            say(Message),
            1
    end.

check(Text) ->
    case gen_tcp:connect(?HOST, ?PORT, [binary, {active, false}], ?CONNECT_TIMEOUT) of
        {ok, Socket} ->
            Result = exchange(Socket, Text),
            gen_tcp:close(Socket),
            Result;
        {error, econnrefused} ->
            {error, io_lib:format("Ошибка: не удалось подключиться к серверу 127.0.0.1:~p. Запущен ли сервер?",
                                  [?PORT])};
        {error, timeout} ->
            {error, "Ошибка: превышено время ожидания подключения."};
        {error, Reason} ->
            {error, io_lib:format("Ошибка подключения: ~ts", [inet:format_error(Reason)])}
    end.

exchange(Socket, Text) ->
    Line = unicode:characters_to_binary([Text, $\n]),
    case gen_tcp:send(Socket, Line) of
        ok ->
            receive_reply(Socket, <<>>);
        {error, Reason} ->
            {error, io_lib:format("Ошибка отправки: ~ts", [inet:format_error(Reason)])}
    end.

receive_reply(Socket, Acc) ->
    case gen_tcp:recv(Socket, 0, ?REPLY_TIMEOUT) of
        {ok, Data} ->
            receive_reply(Socket, <<Acc/binary, Data/binary>>);
        {error, closed} when Acc =/= <<>> ->
            {ok, string:trim(Acc, trailing, [$\n])};
        {error, closed} ->
            {error, "Ошибка: сервер закрыл соединение без ответа."};
        {error, timeout} ->
            {error, "Ошибка: сервер не ответил вовремя."};
        {error, Reason} ->
            {error, io_lib:format("Ошибка соединения: ~ts", [inet:format_error(Reason)])}
    end.

say(Text) ->
    io:format("~ts~n", [Text]).