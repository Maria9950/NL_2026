open System
open System.Collections.Generic
open System.IO
open System.Text
open System.Text.Json

exception ConversionError of string

type Node = { Id: string; Label: string }
type Edge = { From: string; To: string }

let fail (message: string) : 'a = raise (ConversionError message)

let dotKeywords = set [ "node"; "edge"; "graph"; "digraph"; "subgraph"; "strict" ]

let isAsciiLetter (c: char) =
    (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')

let isValidId (name: string) =
    name.Length > 0
    && isAsciiLetter name.[0]
    && name |> Seq.forall (fun c -> isAsciiLetter c || (c >= '0' && c <= '9') || c = '_')

let readText (path: string) : string =
    try
        let bytes = File.ReadAllBytes(path)
        let hasBom =
            bytes.Length >= 3
            && bytes.[0] = 0xEFuy
            && bytes.[1] = 0xBBuy
            && bytes.[2] = 0xBFuy
        let start = if hasBom then 3 else 0
        let encoding = UTF8Encoding(false, true)
        encoding.GetString(bytes, start, bytes.Length - start)
    with
    | :? FileNotFoundException
    | :? DirectoryNotFoundException ->
        fail (sprintf "входной файл \"%s\" не найден" path)
    | :? DecoderFallbackException ->
        fail "файл не в кодировке UTF-8"
    | ex ->
        fail (sprintf "не удалось прочитать файл \"%s\": %s" path ex.Message)

let requireObject (owner: string) (item: JsonElement) =
    if item.ValueKind <> JsonValueKind.Object then
        fail (sprintf "%s: элемент должен быть объектом" owner)

let requiredArray (root: JsonElement) (name: string) : JsonElement list =
    match root.TryGetProperty(name) with
    | true, value when value.ValueKind = JsonValueKind.Array ->
        [ for item in value.EnumerateArray() -> item ]
    | true, _ -> fail (sprintf "поле \"%s\" должно быть массивом" name)
    | false, _ -> fail (sprintf "отсутствует обязательное поле \"%s\"" name)

let requiredString (owner: string) (item: JsonElement) (name: string) : string =
    match item.TryGetProperty(name) with
    | true, value when value.ValueKind = JsonValueKind.String -> value.GetString()
    | true, _ -> fail (sprintf "%s: поле \"%s\" должно быть строкой" owner name)
    | false, _ -> fail (sprintf "%s: отсутствует поле \"%s\"" owner name)

let readNodes (items: JsonElement list) : Node list =
    items
    |> List.mapi (fun i item ->
        let owner = sprintf "nodes[%d]" i
        requireObject owner item
        { Id = requiredString owner item "id"
          Label = requiredString owner item "label" })

let readEdges (items: JsonElement list) : Edge list =
    items
    |> List.mapi (fun i item ->
        let owner = sprintf "edges[%d]" i
        requireObject owner item
        { From = requiredString owner item "from"
          To = requiredString owner item "to" })

let parseGraph (text: string) : Node list * Edge list =
    if String.IsNullOrWhiteSpace text then
        fail "исходный файл пуст"
    try
        use doc = JsonDocument.Parse(text)
        let root = doc.RootElement
        if root.ValueKind <> JsonValueKind.Object then
            fail "корневой элемент JSON должен быть объектом"
        let nodes = requiredArray root "nodes" |> readNodes
        let edges = requiredArray root "edges" |> readEdges
        nodes, edges
    with
    | :? JsonException as ex ->
        fail (sprintf "некорректный JSON: %s" ex.Message)

let checkNodes (nodes: Node list) =
    let seen = HashSet<string>(StringComparer.Ordinal)
    nodes
    |> List.iteri (fun i node ->
        let owner = sprintf "nodes[%d]" i
        if node.Id = "" then
            fail (sprintf "%s: идентификатор вершины не может быть пустым" owner)
        if not (isValidId node.Id) then
            fail (sprintf "%s: недопустимый идентификатор \"%s\": допускаются латинские буквы, цифры и _, первым должна быть буква" owner node.Id)
        if not (seen.Add(node.Id)) then
            fail (sprintf "%s: повторяющийся идентификатор \"%s\"" owner node.Id))

let checkEdges (nodes: Node list) (edges: Edge list) =
    let ids = nodes |> List.map (fun n -> n.Id)
    let known = HashSet<string>(ids, StringComparer.Ordinal)
    edges
    |> List.iteri (fun i edge ->
        if not (known.Contains(edge.From)) then
            fail (sprintf "edges[%d]: поле \"from\" ссылается на несуществующую вершину \"%s\"" i edge.From)
        if not (known.Contains(edge.To)) then
            fail (sprintf "edges[%d]: поле \"to\" ссылается на несуществующую вершину \"%s\"" i edge.To))

let escapeLabel (text: string) : string =
    let normalized = text.Replace("\r\n", "\n").Replace('\r', '\n')
    let builder = StringBuilder()
    for c in normalized do
        match c with
        | '\\' -> builder.Append("\\\\") |> ignore
        | '"' -> builder.Append("\\\"") |> ignore
        | '\n' -> builder.Append("\\n") |> ignore
        | '\t' -> builder.Append("    ") |> ignore
        | _ when Char.IsControl c -> builder.Append(' ') |> ignore
        | _ -> builder.Append(c) |> ignore
    builder.ToString()

let dotId (name: string) : string =
    if Set.contains (name.ToLowerInvariant()) dotKeywords then
        "\"" + name + "\""
    else
        name

let buildDot (nodes: Node list) (edges: Edge list) : string =
    let nodeLines =
        nodes
        |> List.map (fun n -> sprintf "  %s [label=\"%s\"];" (dotId n.Id) (escapeLabel n.Label))
    let edgeLines =
        edges
        |> List.map (fun e -> sprintf "  %s -> %s;" (dotId e.From) (dotId e.To))
    let separator =
        if List.isEmpty nodeLines || List.isEmpty edgeLines then [] else [ "" ]
    let lines = [ "digraph G {" ] @ nodeLines @ separator @ edgeLines @ [ "}" ]
    String.concat "\n" lines + "\n"

let writeText (path: string) (text: string) =
    try
        File.WriteAllText(path, text, UTF8Encoding(false))
    with ex ->
        fail (sprintf "не удалось записать файл \"%s\": %s" path ex.Message)

let convert (inPath: string) (outPath: string) : int * int =
    if Path.GetFullPath(inPath) = Path.GetFullPath(outPath) then
        fail "входной и выходной файлы совпадают, исходные данные не будут затёрты"
    let text = readText inPath
    let nodes, edges = parseGraph text
    checkNodes nodes
    checkEdges nodes edges
    writeText outPath (buildDot nodes edges)
    nodes.Length, edges.Length

let scriptArguments () : string[] =
    let argv = Environment.GetCommandLineArgs()
    match argv |> Array.tryFindIndex (fun arg -> arg.EndsWith(".fsx", StringComparison.OrdinalIgnoreCase)) with
    | Some index -> argv.[index + 1 ..]
    | None -> [||]

let main () =
    Console.OutputEncoding <- UTF8Encoding(false)
    let args = scriptArguments ()
    if args.Length <> 2 then
        eprintfn "Использование: dotnet fsi 5_convert/task_2_fsharp/main.fsx <graph.json> <graph.dot>"
        1
    else
        try
            let nodeCount, edgeCount = convert args.[0] args.[1]
            printfn "Готово: вершин: %d, рёбер: %d. Результат: %s" nodeCount edgeCount args.[1]
            0
        with
        | ConversionError message ->
            eprintfn "Ошибка: %s" message
            1
        | ex ->
            eprintfn "Ошибка: %s" ex.Message
            1

exit (main ())