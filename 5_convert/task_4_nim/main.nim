import std/[json, os, strutils]
from std/net import isIpAddress
from std/unicode import validateUtf8

type
  LogRecord = object
    ip: string
    datetime: string
    request: string
    status: int
    bytes: int
    hasBytes: bool

  ReadResult = object
    records: seq[LogRecord]
    skipped: int

  ConversionError = object of CatchableError

const
  Months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
            "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
  Utf8Bom = "\xEF\xBB\xBF"
  MaxByteDigits = 18
  Digits = {'0' .. '9'}

proc isDigits(s: string): bool =
  if s.len == 0:
    return false
  for c in s:
    if c notin Digits:
      return false
  true

proc numberAt(s: string, start, length: int): int =
  parseInt(s[start ..< start + length])

proc isValidTimestamp(s: string): bool =
  if s.len != 26:
    return false
  if s[2] != '/' or s[6] != '/' or s[11] != ':' or s[14] != ':' or
      s[17] != ':' or s[20] != ' ' or s[21] notin {'+', '-'}:
    return false
  for (start, length) in [(0, 2), (7, 4), (12, 2), (15, 2), (18, 2), (22, 4)]:
    if not isDigits(s[start ..< start + length]):
      return false
  if s[3 ..< 6] notin Months:
    return false
  let day = numberAt(s, 0, 2)
  let hour = numberAt(s, 12, 2)
  let minute = numberAt(s, 15, 2)
  let second = numberAt(s, 18, 2)
  day >= 1 and day <= 31 and hour <= 23 and minute <= 59 and second <= 60

proc readToken(line: string, pos: var int): string =
  let start = pos
  while pos < line.len and line[pos] != ' ':
    inc pos
  line[start ..< pos]

proc expectSpace(line: string, pos: var int): bool =
  if pos < line.len and line[pos] == ' ':
    inc pos
    result = true

proc readBracketed(line: string, pos: var int, value: var string): bool =
  if pos >= line.len or line[pos] != '[':
    return false
  inc pos
  let start = pos
  while pos < line.len and line[pos] != ']':
    inc pos
  if pos >= line.len:
    return false
  value = line[start ..< pos]
  inc pos
  true

proc readQuoted(line: string, pos: var int, value: var string): bool =
  if pos >= line.len or line[pos] != '"':
    return false
  inc pos
  let start = pos
  while pos < line.len:
    if line[pos] == '\\' and pos + 1 < line.len:
      pos += 2
    elif line[pos] == '"':
      value = line[start ..< pos]
      inc pos
      return true
    else:
      inc pos
  false

proc parseStatus(token: string, status: var int): bool =
  if token.len != 3 or not isDigits(token):
    return false
  status = parseInt(token)
  status >= 100 and status <= 599

proc parseBytes(token: string, hasBytes: var bool, bytes: var int): bool =
  if token == "-":
    hasBytes = false
    return true
  if token.len > MaxByteDigits or not isDigits(token):
    return false
  bytes = parseInt(token)
  hasBytes = true
  true

proc parseLine(line: string, record: var LogRecord): string =
  var pos = 0

  record.ip = readToken(line, pos)
  if not isIpAddress(record.ip):
    return "ожидался IP-адрес клиента"
  if not expectSpace(line, pos):
    return "ожидался пробел после адреса клиента"

  if readToken(line, pos).len == 0:
    return "пустое поле идентификации (%l)"
  if not expectSpace(line, pos):
    return "ожидался пробел после поля идентификации"

  if readToken(line, pos).len == 0:
    return "пустое поле пользователя (%u)"
  if not expectSpace(line, pos):
    return "ожидался пробел после поля пользователя"

  if not readBracketed(line, pos, record.datetime):
    return "ожидалась дата и время в квадратных скобках"
  if not isValidTimestamp(record.datetime):
    return "неверный формат даты и времени (ожидается ДД/Мес/ГГГГ:ЧЧ:ММ:СС +ЧЧММ)"
  if not expectSpace(line, pos):
    return "ожидался пробел после даты и времени"

  if not readQuoted(line, pos, record.request):
    return "ожидался HTTP-запрос в двойных кавычках"
  if not expectSpace(line, pos):
    return "ожидался пробел после HTTP-запроса"

  if not parseStatus(readToken(line, pos), record.status):
    return "неверный код ответа (ожидается число 100-599)"
  if not expectSpace(line, pos):
    return "ожидался пробел и размер ответа после кода"

  if not parseBytes(readToken(line, pos), record.hasBytes, record.bytes):
    return "неверный размер ответа (ожидается число или -)"
  if pos < line.len:
    return "лишние данные после размера ответа (Combined Log Format не поддерживается)"
  ""

proc reportSkipped(number: int, reason: string) =
  stderr.writeLine("Строка " & $number & " пропущена: " & reason)

proc readRecords(path: string): ReadResult =
  var number = 0
  try:
    for rawLine in lines(path):
      inc number
      var line = rawLine
      if number == 1 and line.startsWith(Utf8Bom):
        line = line[Utf8Bom.len .. ^1]
      line = line.strip(leading = false)
      if line.len == 0:
        continue
      if validateUtf8(line) != -1:
        reportSkipped(number, "недопустимые байты UTF-8")
        inc result.skipped
        continue
      var record: LogRecord
      let reason = parseLine(line, record)
      if reason.len == 0:
        result.records.add(record)
      else:
        reportSkipped(number, reason)
        inc result.skipped
  except IOError as error:
    raise newException(ConversionError,
                       "не удалось прочитать файл " & path & ": " & error.msg)

proc toJson(record: LogRecord): JsonNode =
  result = newJObject()
  result["ip"] = %record.ip
  result["datetime"] = %record.datetime
  result["request"] = %record.request
  result["status"] = %record.status
  if record.hasBytes:
    result["bytes"] = %record.bytes
  else:
    result["bytes"] = newJNull()

proc buildJson(records: seq[LogRecord]): JsonNode =
  result = newJArray()
  for record in records:
    result.add(toJson(record))

proc convertLog(inPath, outPath: string): ReadResult =
  if not fileExists(inPath):
    if dirExists(inPath):
      raise newException(ConversionError, inPath & " является каталогом, а не файлом")
    raise newException(ConversionError, "входной файл " & inPath & " не найден")
  if fileExists(outPath) and sameFile(inPath, outPath):
    raise newException(ConversionError,
                       "входной и выходной файлы совпадают, исходные данные не будут затёрты")
  result = readRecords(inPath)
  let text = pretty(buildJson(result.records)) & "\n"
  try:
    writeFile(outPath, text)
  except IOError as error:
    raise newException(ConversionError,
                       "не удалось записать файл " & outPath & ": " & error.msg)

proc run(args: seq[string]): int =
  if args.len != 2:
    stderr.writeLine("Использование: main <входной.log> <выходной.json>")
    return 1
  try:
    let summary = convertLog(args[0], args[1])
    echo "Готово: обработано записей: ", summary.records.len,
         ", пропущено некорректных: ", summary.skipped,
         ". Результат: ", args[1]
    return 0
  except ConversionError as error:
    stderr.writeLine("Ошибка: " & error.msg)
    return 1
  except CatchableError as error:
    stderr.writeLine("Ошибка: " & error.msg)
    return 1

when isMainModule:
  quit(run(commandLineParams()))