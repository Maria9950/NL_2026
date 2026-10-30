struct ConversionError <: Exception
    message::String
end

fail(message::AbstractString) = throw(ConversionError(String(message)))

const BLANKS = [' ', '\t', '\n']
const WS = raw"[ \t\n]*"
const WS1 = raw"[ \t\n]+"
const NUM = raw"[+-]?[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?"
const CAPTURED = "(" * NUM * ")"
const COLUMNS = ["id", "temperature", "humidity"]
const SYNTAX_HINT = "неверный синтаксис, ожидается: INSERT INTO measurements (id, temperature, humidity) VALUES (число, число, число)"

const COMMAND = Regex(
    "^INSERT" * WS1 * "INTO" * WS1 * "measurements" * WS * raw"\(" * WS *
    "id" * WS * "," * WS * "temperature" * WS * "," * WS * "humidity" * WS * raw"\)" * WS *
    "VALUES" * WS * raw"\(" * WS * CAPTURED * WS * "," * WS * CAPTURED * WS * "," * WS * CAPTURED * WS * raw"\)\z",
    "i")

const LOOSE = Regex(
    "^INSERT" * WS1 * "INTO" * WS1 * "([A-Za-z_][A-Za-z0-9_]*)" * WS * raw"\(([^()]*)\)" * WS *
    "VALUES" * WS * raw"\((.*)\)\z",
    "is")

const NUMBER_ONLY = Regex("^" * NUM * raw"\z")

function count_newlines(s::AbstractString)
    return count(==('\n'), s)
end

function read_text(path::String)
    bytes = try
        read(path)
    catch e
        fail("не удалось прочитать файл \"$path\": $(sprint(showerror, e))")
    end
    if length(bytes) >= 3 && bytes[1] == 0xEF && bytes[2] == 0xBB && bytes[3] == 0xBF
        bytes = bytes[4:end]
    end
    text = String(bytes)
    isvalid(text) || fail("файл не в кодировке UTF-8")
    text = replace(text, "\r\n" => "\n")
    return replace(text, '\r' => '\n')
end

function split_commands(text::String)
    pieces = split(text, ';'; keepempty = true)
    commands = Tuple{Int,String}[]
    line = 1
    for piece in pieces[1:end-1]
        leading = count_newlines(piece) - count_newlines(lstrip(piece, BLANKS))
        push!(commands, (line + leading, String(strip(piece, BLANKS))))
        line += count_newlines(piece)
    end
    last_piece = pieces[end]
    unterminated = nothing
    if !isempty(strip(last_piece, BLANKS))
        leading = count_newlines(last_piece) - count_newlines(lstrip(last_piece, BLANKS))
        unterminated = line + leading
    end
    return commands, unterminated
end

function explain(body::AbstractString)
    if length(collect(eachmatch(r"\bINSERT\b"i, body))) > 1
        return "в одной команде несколько INSERT, возможно пропущена ';'"
    end
    m = match(LOOSE, body)
    if m === nothing
        if occursin(r"^INSERT\b"i, body)
            return SYNTAX_HINT
        else
            return "поддерживаются только команды INSERT"
        end
    end
    table = m.captures[1]
    columns = [lowercase(strip(c, BLANKS)) for c in split(m.captures[2], ',')]
    fields = [strip(v, BLANKS) for v in split(m.captures[3], ',')]
    if lowercase(table) != "measurements"
        return "поддерживается только таблица measurements, найдена \"$table\""
    elseif columns != COLUMNS
        return "ожидаются столбцы (id, temperature, humidity) именно в таком порядке"
    elseif length(fields) != 3
        return "ожидалось 3 значения, найдено $(length(fields))"
    end
    for field in fields
        occursin(NUMBER_ONLY, field) || return "значение \"$field\" не является числовым литералом (допускаются целые, десятичные и экспоненциальные числа без выражений)"
    end
    return SYNTAX_HINT
end

function parse_commands(commands::Vector{Tuple{Int,String}}, unterminated)
    rows = String[]
    errors = String[]
    for (number, (line, body)) in enumerate(commands)
        if isempty(body)
            push!(errors, "команда №$number (строка $line): пустая команда")
            continue
        end
        m = match(COMMAND, body)
        if m === nothing
            push!(errors, "команда №$number (строка $line): $(explain(body))")
        else
            push!(rows, join(m.captures, ","))
        end
    end
    if unterminated !== nothing
        push!(errors, "команда №$(length(commands) + 1) (строка $unterminated): нет завершающей \";\"")
    end
    return rows, errors
end

function same_file(a::String, b::String)
    abspath(a) == abspath(b) && return true
    ispath(b) || return false
    stat_a = stat(a)
    stat_b = stat(b)
    return stat_a.device == stat_b.device && stat_a.inode == stat_b.inode
end

function write_csv(path::String, rows::Vector{String})
    content = "id,temperature,humidity\n" * join(rows, "\n") * "\n"
    try
        write(path, content)
    catch e
        fail("не удалось записать файл \"$path\": $(sprint(showerror, e))")
    end
end

function convert_file(in_path::String, out_path::String)
    ispath(in_path) || fail("входной файл \"$in_path\" не найден")
    isfile(in_path) || fail("\"$in_path\" не является обычным файлом")
    same_file(in_path, out_path) && fail("входной и выходной файлы совпадают, исходные данные не будут затёрты")
    text = read_text(in_path)
    commands, unterminated = split_commands(text)
    if isempty(commands) && unterminated === nothing
        fail("файл пуст: нет команд INSERT")
    end
    rows, errors = parse_commands(commands, unterminated)
    isempty(errors) || fail(join(errors, "\nОшибка: "))
    write_csv(out_path, rows)
    return length(rows)
end

function main(args)
    if length(args) != 2
        println(stderr, "Использование: julia 5_convert/task_3_julia/main.jl <входной.sql> <выходной.csv>")
        return 1
    end
    try
        total = convert_file(args[1], args[2])
        println("Готово: обработано записей: $total. Результат: $(args[2])")
        return 0
    catch e
        message = e isa ConversionError ? e.message : sprint(showerror, e)
        println(stderr, "Ошибка: ", message)
        return 1
    end
end

exit(main(ARGS))