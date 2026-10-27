import std.stdio;
import std.algorithm : sort;
import std.array : split;
import std.conv : to, ConvException;
import std.file : exists, isFile, readText;
import std.math : isFinite;
import std.string : strip, toStringz;
import std.utf : UTFException;
import core.sys.posix.sys.stat : stat, stat_t;

struct Product
{
    string name;
    string price;
    double value;
    size_t line;
}

bool isDigits(string s)
{
    if (s.length == 0)
        return false;
    foreach (c; s)
    {
        if (c < '0' || c > '9')
            return false;
    }
    return true;
}

bool isPriceText(string s)
{
    auto parts = s.split('.');
    if (parts.length == 0 || parts.length > 2)
        return false;
    return isDigits(parts[0]) && (parts.length == 1 || isDigits(parts[1]));
}

bool sameFile(string a, string b)
{
    if (a == b)
        return true;
    stat_t first, second;
    if (stat(a.toStringz, &first) != 0 || stat(b.toStringz, &second) != 0)
        return false;
    return first.st_dev == second.st_dev && first.st_ino == second.st_ino;
}

string parseProduct(string line, size_t number, out Product product)
{
    auto fields = line.split(';');
    if (fields.length != 2)
        return "ожидалось 2 поля, найдено " ~ fields.length.to!string;

    auto name = fields[0].strip;
    auto price = fields[1].strip;
    if (name.length == 0)
        return "пустое название товара";
    if (price.length == 0)
        return "пустая цена";
    if (price[0] == '-' && isPriceText(price[1 .. $]))
        return "цена не может быть отрицательной";
    if (!isPriceText(price))
        return "цена должна быть неотрицательным числом вида 120 или 89.90";

    double value;
    try
    {
        value = price.to!double;
    }
    catch (ConvException)
    {
        return "цена вне допустимого диапазона";
    }
    if (!isFinite(value))
        return "цена вне допустимого диапазона";

    product = Product(name, price, value, number);
    return null;
}

int main(string[] args)
{
    if (args.length != 3)
    {
        stderr.writeln("Использование: ", args[0], " <файл_товаров> <файл_результата>");
        return 1;
    }
    string inPath = args[1];
    string outPath = args[2];

    if (!exists(inPath))
    {
        stderr.writeln("Ошибка: входной файл ", inPath, " не найден.");
        return 1;
    }
    if (!isFile(inPath))
    {
        stderr.writeln("Ошибка: ", inPath, " не является обычным файлом.");
        return 1;
    }
    if (sameFile(inPath, outPath))
    {
        stderr.writeln("Ошибка: входной и выходной файлы совпадают, исходные данные не будут затёрты.");
        return 1;
    }

    string text;
    try
    {
        text = readText(inPath);
    }
    catch (UTFException)
    {
        stderr.writeln("Ошибка: файл ", inPath, " не в кодировке UTF-8.");
        return 1;
    }
    catch (Exception e)
    {
        stderr.writeln("Ошибка: не удалось прочитать ", inPath, ": ", e.msg);
        return 1;
    }
    if (text.length >= 3 && text[0 .. 3] == "\uFEFF")
        text = text[3 .. $];

    Product[] products;
    size_t number = 0;
    size_t nonBlank = 0;
    size_t invalid = 0;
    foreach (rawLine; text.split('\n'))
    {
        number++;
        auto line = rawLine.strip;
        if (line.length == 0)
            continue;
        nonBlank++;

        Product product;
        auto problem = parseProduct(line, number, product);
        if (problem.length != 0)
        {
            stderr.writefln("Ошибка в строке %d: %s: \"%s\"", number, problem, line);
            invalid++;
            continue;
        }
        products ~= product;
    }
    if (invalid > 0)
        stderr.writeln("Пропущено некорректных строк: ", invalid);

    if (nonBlank == 0)
    {
        stderr.writeln("Ошибка: файл пуст, результат не создан.");
        return 1;
    }
    if (products.length == 0)
    {
        stderr.writeln("Ошибка: нет ни одной корректной записи, результат не создан.");
        return 1;
    }

    products.sort!((a, b) => a.value < b.value || (a.value == b.value && a.line < b.line));

    string report;
    foreach (p; products)
        report ~= p.name ~ ";" ~ p.price ~ "\n";

    try
    {
        auto output = File(outPath, "w");
        output.write(report);
        output.close();
    }
    catch (Exception e)
    {
        stderr.writeln("Ошибка: не удалось записать результат в ", outPath, ": ", e.msg);
        return 1;
    }

    write(report);
    stderr.writeln("Результат сохранён в ", outPath);
    return 0;
}