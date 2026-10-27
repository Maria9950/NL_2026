fun fail msg =
  (TextIO.output (TextIO.stdErr, "Ошибка: " ^ msg ^ "\n");
   OS.Process.exit OS.Process.failure)

fun check (cond, msg) = if cond then fail msg else ()

fun describe (IO.Io {cause = OS.SysErr (msg, _), ...}) = msg
  | describe (IO.Io {cause, ...}) = General.exnMessage cause
  | describe e = General.exnMessage e

fun readable path =
  OS.FileSys.access (path, [OS.FileSys.A_READ]) handle OS.SysErr _ => false

fun exists path =
  OS.FileSys.access (path, []) handle OS.SysErr _ => false

fun isDirectory path =
  OS.FileSys.isDir path handle OS.SysErr _ => false

fun sameFile (a, b) =
  a = b orelse
  (exists b andalso
   OS.FileSys.compare (OS.FileSys.fileId a, OS.FileSys.fileId b) = EQUAL)
  handle OS.SysErr _ => false

fun isLetter c =
  (c >= #"a" andalso c <= #"z") orelse (c >= #"A" andalso c <= #"Z")

fun words line =
  List.map (String.map Char.toLower) (String.tokens (not o isLetter) line)

fun addLine n lines =
  case lines of
    x :: _ => if x = n then lines else n :: lines
  | [] => [n]

fun addWord (word, n, []) = [(word, [n])]
  | addWord (word, n, (w, lines) :: rest) =
      case String.compare (word, w) of
        EQUAL => (w, addLine n lines) :: rest
      | LESS => (word, [n]) :: (w, lines) :: rest
      | GREATER => (w, lines) :: addWord (word, n, rest)

fun readIndex ins =
  let
    fun loop (n, index) =
      case TextIO.inputLine ins of
        NONE => index
      | SOME line =>
          loop (n + 1, List.foldl (fn (w, acc) => addWord (w, n, acc)) index (words line))
  in
    loop (1, [])
  end

fun readFile path =
  let
    val ins = TextIO.openIn path
    val index = readIndex ins
    val () = TextIO.closeIn ins
  in
    index
  end
  handle e => fail ("не удалось прочитать " ^ path ^ ": " ^ describe e)

fun formatEntry (word, lines) =
  word ^ ": " ^ String.concatWith ", " (List.map Int.toString (List.rev lines)) ^ "\n"

fun formatIndex index = String.concat (List.map formatEntry index)

fun writeFile (path, text) =
  let
    val outs = TextIO.openOut path
    val () = TextIO.output (outs, text)
    val () = TextIO.closeOut outs
  in
    ()
  end
  handle e => fail ("не удалось записать отчёт " ^ path ^ ": " ^ describe e)

fun main () =
  case CommandLine.arguments () of
    [inPath, outPath] =>
      let
        val () = check (not (readable inPath),
                        "входной файл " ^ inPath ^ " не найден или недоступен для чтения.")
        val () = check (isDirectory inPath,
                        inPath ^ " является каталогом, а не файлом.")
        val () = check (sameFile (inPath, outPath),
                        "входной и выходной файлы совпадают, исходный текст не будет затёрт.")
        val index = readFile inPath
        val () = check (null index,
                        "в файле нет слов из латинских букв, указатель пуст, выходной файл не создан.")
        val report = formatIndex index
        val () = writeFile (outPath, report)
      in
        print report
      end
  | _ =>
      (TextIO.output (TextIO.stdErr,
         "Использование: " ^ CommandLine.name () ^ " <входной_файл> <файл_указателя>\n");
       OS.Process.exit OS.Process.failure)

val () = main ()