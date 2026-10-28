-module(server).
-export([main/0]).

-define(PORT, 5053).
-define(RECV_TIMEOUT, 5000).
-define(MAX_LINE, 1048576).

main() ->
    io:setopts([{encoding, unicode}]),
    Options = [binary, {active, false}, {reuseaddr, true}, {ip, {127, 0, 0, 1}}],
    case gen_tcp:listen(?PORT, Options) of
        {ok, Listen} ->
            say(io_lib:format("Сервер запущен: 127.0.0.1:~p. Остановка: Ctrl+C, затем a и Enter.", [?PORT])),
            accept_loop(Listen);
        {error, Reason} ->
            say(io_lib:format("Ошибка: не удалось запустить сервер на порту ~p: ~ts",
                              [?PORT, inet:format_error(Reason)])),
            init:stop(1)
    end.

accept_loop(Listen) ->
    case gen_tcp:accept(Listen) of
        {ok, Socket} ->
            try
                serve(Socket)
            catch
                Class:Why ->
                    say(io_lib:format("Внутренняя ошибка: ~p:~p", [Class, Why]))
            after
                gen_tcp:close(Socket)
            end;
        {error, Reason} ->
            say(io_lib:format("Ошибка приёма соединения: ~ts", [inet:format_error(Reason)])),
            timer:sleep(200)
    end,
    accept_loop(Listen).

serve(Socket) ->
    case recv_line(Socket, <<>>) of
        {ok, Line} ->
            Reply = answer(Line),
            say(io_lib:format("Запрос: ~tp -> ~ts", [preview(Line), Reply])),
            send_reply(Socket, Reply);
        {error, closed} ->
            say("Клиент отключился, не прислав строку.");
        {error, timeout} ->
            say("Клиент не прислал строку за 5 секунд."),
            send_reply(Socket, "ERROR: строка не получена за 5 секунд");
        {error, too_long} ->
            say("Строка слишком длинная."),
            send_reply(Socket, io_lib:format("ERROR: строка длиннее ~p байт", [?MAX_LINE]));
        {error, Reason} ->
            say(io_lib:format("Ошибка чтения: ~ts", [inet:format_error(Reason)]))
    end.

recv_line(Socket, Acc) ->
    case gen_tcp:recv(Socket, 0, ?RECV_TIMEOUT) of
        {ok, Data} ->
            All = <<Acc/binary, Data/binary>>,
            case binary:split(All, <<"\n">>) of
                [Line, _Rest] -> {ok, Line};
                [_Incomplete] when byte_size(All) > ?MAX_LINE -> {error, too_long};
                [_Incomplete] -> recv_line(Socket, All)
            end;
        {error, closed} when Acc =/= <<>> ->
            {ok, Acc};
        {error, Reason} ->
            {error, Reason}
    end.

send_reply(Socket, Reply) ->
    gen_tcp:send(Socket, unicode:characters_to_binary([Reply, $\n])).

answer(Line) ->
    case normalize(Line) of
        {ok, Letters} ->
            case is_palindrome(Letters) of
                true -> "YES";
                false -> "NO"
            end;
        {error, Reason} ->
            "ERROR: " ++ Reason
    end.

normalize(Line) ->
    Chars = binary_to_list(Line),
    case lists:all(fun allowed/1, Chars) of
        false ->
            {error, "допустимы только латинские буквы и пробелы"};
        true ->
            case string:lowercase([C || C <- Chars, C =/= $\s]) of
                [] -> {error, "строка пуста или состоит только из пробелов"};
                Letters -> {ok, Letters}
            end
    end.

allowed(C) when C >= $a, C =< $z -> true;
allowed(C) when C >= $A, C =< $Z -> true;
allowed($\s) -> true;
allowed(_) -> false.

is_palindrome(Letters) ->
    Letters =:= lists:reverse(Letters).

preview(Line) ->
    binary:part(Line, 0, min(byte_size(Line), 60)).

say(Text) ->
    io:format("~ts~n", [Text]).