local path = arg[1]
local bookmarks = {}

local MENU = [[

Менеджер закладок
1. Добавить закладку
2. Показать все закладки
3. Найти закладку по названию
4. Удалить закладку по названию
0. Выход]]

local function trim(s)
    return (s:match("^%s*(.-)%s*$"))
end

local function ask(prompt)
    io.write(prompt)
    io.flush()
    local line = io.read("l")
    if line == nil then
        return nil
    end
    return trim((line:gsub("\r$", "")))
end

local function check_field(value, label)
    if value == "" then
        return false, "Поле «" .. label .. "» не может быть пустым."
    end
    if value:find(";", 1, true) then
        return false, "Поле «" .. label .. "» не должно содержать символ «;»."
    end
    return true
end

local function find_index(title)
    for i, bookmark in ipairs(bookmarks) do
        if bookmark.title == title then
            return i
        end
    end
    return nil
end

local function load_bookmarks()
    local file, err, code = io.open(path, "r")
    if not file then
        if code == 2 then
            return {}, false
        end
        return nil, err
    end

    local list, seen = {}, {}
    local number = 0
    while true do
        local line, read_err = file:read("l")
        if line == nil then
            if read_err then
                file:close()
                return nil, read_err
            end
            break
        end
        number = number + 1
        line = line:gsub("\r$", "")
        if number == 1 then
            line = line:gsub("^\239\187\191", "")
        end
        if trim(line) ~= "" then
            local title, url = line:match("^([^;]*);([^;]*)$")
            if title then
                title, url = trim(title), trim(url)
            end
            if not title or title == "" or url == "" then
                print("Предупреждение: строка " .. number .. " файла закладок повреждена и пропущена.")
            elseif seen[title] then
                print("Предупреждение: строка " .. number .. " пропущена, название «" .. title .. "» уже встречалось.")
            else
                seen[title] = true
                list[#list + 1] = { title = title, url = url }
            end
        end
    end
    file:close()
    return list, true
end

local function save_bookmarks()
    local lines = {}
    for _, bookmark in ipairs(bookmarks) do
        lines[#lines + 1] = bookmark.title .. ";" .. bookmark.url .. "\n"
    end
    local file, err = io.open(path, "w")
    if not file then
        return false, err
    end
    local ok, write_err = file:write(table.concat(lines))
    if not ok then
        file:close()
        return false, write_err
    end
    local closed, close_err = file:close()
    if not closed then
        return false, close_err
    end
    return true
end

local function add_bookmark()
    local title = ask("Название: ")
    if title == nil then
        return
    end
    local ok, message = check_field(title, "Название")
    if not ok then
        print(message)
        return
    end
    if find_index(title) then
        print("Закладка «" .. title .. "» уже существует. Одинаковые названия не допускаются.")
        return
    end
    local url = ask("URL: ")
    if url == nil then
        return
    end
    ok, message = check_field(url, "URL")
    if not ok then
        print(message)
        return
    end

    bookmarks[#bookmarks + 1] = { title = title, url = url }
    local saved, err = save_bookmarks()
    if saved then
        print("Закладка «" .. title .. "» добавлена и сохранена.")
    else
        table.remove(bookmarks)
        print("Ошибка записи в файл: " .. tostring(err))
        print("Закладка не добавлена.")
    end
end

local function list_bookmarks()
    if #bookmarks == 0 then
        print("Список закладок пуст.")
        return
    end
    print("Закладок: " .. #bookmarks)
    for i, bookmark in ipairs(bookmarks) do
        print(string.format("%d. %s — %s", i, bookmark.title, bookmark.url))
    end
end

local function search_bookmark()
    local title = ask("Название для поиска: ")
    if title == nil then
        return
    end
    if title == "" then
        print("Поле «Название» не может быть пустым.")
        return
    end
    local index = find_index(title)
    if index then
        print("Найдено: " .. bookmarks[index].title .. " — " .. bookmarks[index].url)
    else
        print("Закладка «" .. title .. "» не найдена.")
    end
end

local function delete_bookmark()
    local title = ask("Название для удаления: ")
    if title == nil then
        return
    end
    if title == "" then
        print("Поле «Название» не может быть пустым.")
        return
    end
    local index = find_index(title)
    if not index then
        print("Закладка «" .. title .. "» не найдена.")
        return
    end

    local removed = table.remove(bookmarks, index)
    local saved, err = save_bookmarks()
    if saved then
        print("Закладка «" .. title .. "» удалена.")
        if #bookmarks == 0 then
            print("Список закладок теперь пуст.")
        end
    else
        table.insert(bookmarks, index, removed)
        print("Ошибка записи в файл: " .. tostring(err))
        print("Закладка не удалена.")
    end
end

if path == nil or path == "" then
    io.stderr:write("Использование: lua5.4 main.lua <файл_закладок>\n")
    os.exit(1)
end

local loaded, existed = load_bookmarks()
if loaded == nil then
    io.stderr:write("Ошибка: не удалось прочитать файл закладок: " .. tostring(existed) .. "\n")
    os.exit(1)
end
bookmarks = loaded

if existed then
    print("Загружено закладок: " .. #bookmarks)
else
    print("Файл закладок ещё не создан, список пуст.")
end

local actions = {
    ["1"] = add_bookmark,
    ["2"] = list_bookmarks,
    ["3"] = search_bookmark,
    ["4"] = delete_bookmark,
}

while true do
    print(MENU)
    local choice = ask("Выберите пункт: ")
    if choice == nil then
        print()
        print("Ввод завершён. До свидания!")
        break
    end
    if choice == "0" then
        print("До свидания!")
        break
    end
    local action = actions[choice]
    if action then
        action()
    else
        print("Неизвестный пункт меню: «" .. choice .. "». Введите число от 0 до 4.")
    end
end