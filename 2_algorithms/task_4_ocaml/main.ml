type tree = Empty | Node of tree * int * tree

let leaf v = Node (Empty, v, Empty)

let rec mirror a b =
  match a, b with
  | Empty, Empty -> true
  | Node (l1, v1, r1), Node (l2, v2, r2) ->
      v1 = v2 && mirror l1 r2 && mirror r1 l2
  | _ -> false

let is_symmetric t =
  match t with
  | Empty -> true
  | Node (l, _, r) -> mirror l r

let rec to_string t =
  match t with
  | Empty -> "."
  | Node (l, v, r) ->
      "(" ^ to_string l ^ " " ^ string_of_int v ^ " " ^ to_string r ^ ")"

let rec draw prefix t =
  match t with
  | Empty -> ()
  | Node (l, v, r) ->
      draw (prefix ^ "    ") r;
      print_endline (prefix ^ string_of_int v);
      draw (prefix ^ "    ") l

let show t =
  match t with
  | Empty -> print_endline "  (пусто)"
  | Node _ -> draw "  " t

let verdict b = if b then "симметрично" else "несимметрично"

let tests = [
  ("1. Пустое дерево", Empty, true);
  ("2. Один узел", leaf 1, true);
  ("3. Корень с двумя одинаковыми листьями", Node (leaf 2, 1, leaf 2), true);
  ("4. Корень с двумя различающимися листьями", Node (leaf 2, 1, leaf 3), false);
  ("5. Многоуровневое зеркальное дерево",
   Node (Node (leaf 3, 2, leaf 4), 1, Node (leaf 4, 2, leaf 3)), true);
  ("6. Зеркальное дерево с несбалансированными поддеревьями",
   Node (Node (Empty, 2, leaf 3), 1, Node (leaf 3, 2, Empty)), true);
  ("7. Структура зеркальная, одно значение отличается",
   Node (Node (leaf 3, 2, leaf 4), 1, Node (leaf 4, 2, leaf 5)), false);
  ("8. Левое и правое поддеревья равны, но не зеркальны",
   Node (Node (leaf 3, 2, leaf 4), 1, Node (leaf 3, 2, leaf 4)), false);
  ("9. Значения совпадают, потомки с одной и той же стороны",
   Node (Node (Empty, 2, leaf 3), 1, Node (Empty, 2, leaf 3)), false);
  ("10. Разная глубина: у левого поддерева есть потомок, у правого нет",
   Node (Node (Empty, 2, leaf 3), 1, leaf 2), false);
  ("11. Только левое поддерево", Node (leaf 2, 1, Empty), false);
  ("12. Только правое поддерево", Node (Empty, 1, leaf 2), false);
]

let run_test (name, tree, expected) =
  let actual = is_symmetric tree in
  Printf.printf "%s\n" name;
  Printf.printf "  Запись (левое значение правое): %s\n" (to_string tree);
  print_endline "  Схема (правое поддерево выше, левое ниже):";
  show tree;
  Printf.printf "  Ожидается: %s; получено: %s; %s\n\n"
    (verdict expected) (verdict actual)
    (if actual = expected then "OK" else "ОШИБКА");
  actual = expected

let () =
  let all_ok =
    List.fold_left
      (fun acc t -> let ok = run_test t in acc && ok)
      true tests
  in
  Printf.printf "Все тесты пройдены: %s\n" (if all_ok then "да" else "нет");
  if not all_ok then exit 1