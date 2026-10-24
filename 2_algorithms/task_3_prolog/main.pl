:- encoding(utf8).

edge(a, b).
edge(b, c).
edge(c, d).
edge(d, b).
edge(c, e).
edge(x, y).
edge(y, z).
edge(z, x).

graph_vertex(V) :-
    (   edge(V, _)
    ;   edge(_, V)
    ).

vertex_exists(V) :-
    once(graph_vertex(V)).

reachable(Start, End) :-
    vertex_exists(Start),
    vertex_exists(End),
    walk(Start, End, [Start]).

walk(End, End, _).
walk(Current, End, Visited) :-
    edge(Current, Next),
    \+ memberchk(Next, Visited),
    walk(Next, End, [Next|Visited]).

print_graph :-
    format("Ориентированный граф, рёбра:~n"),
    forall(edge(From, To), format("  ~w -> ~w~n", [From, To])),
    setof(V, graph_vertex(V), Vertices),
    atomic_list_concat(Vertices, ', ', Text),
    format("Вершины: ~w~n", [Text]).

read_vertex(Prompt, Vertex) :-
    format("~w: ", [Prompt]),
    flush_output,
    read_line_to_string(user_input, Line),
    (   Line == end_of_file
    ->  Text = ""
    ;   normalize_space(string(Text), Line)
    ),
    atom_string(Vertex, Text).

check_vertex(Vertex, Role) :-
    (   Vertex == ''
    ->  format("Ошибка: ~w не введена.~n", [Role]),
        halt(1)
    ;   \+ vertex_exists(Vertex)
    ->  format("Ошибка: вершины ~q нет в графе.~n", [Vertex]),
        halt(1)
    ;   true
    ).

report(Start, End) :-
    (   once(reachable(Start, End))
    ->  format("Путь из ~w в ~w существует.~n", [Start, End])
    ;   format("Пути из ~w в ~w нет.~n", [Start, End])
    ).

main :-
    set_stream(user_input, encoding(utf8)),
    set_stream(user_output, encoding(utf8)),
    print_graph,
    read_vertex('Начальная вершина', Start),
    read_vertex('Конечная вершина', End),
    check_vertex(Start, 'начальная вершина'),
    check_vertex(End, 'конечная вершина'),
    report(Start, End).

:- initialization(main, main).