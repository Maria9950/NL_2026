import kotlin.system.exitProcess

fun sequentialPrefixSums(data: LongArray): LongArray {
    val result = LongArray(data.size)
    var running = 0L
    for (i in data.indices) {
        running += data[i]
        result[i] = running
    }
    return result
}

fun parallelPrefixSums(data: LongArray): LongArray {
    val blocks = 4
    val n = data.size
    val result = LongArray(n)
    val bounds = IntArray(blocks + 1) { ((it.toLong() * n) / blocks).toInt() }

    val threads = List(blocks) { b ->
        Thread {
            var running = 0L
            for (i in bounds[b] until bounds[b + 1]) {
                running += data[i]
                result[i] = running
            }
        }
    }
    threads.forEach { it.start() }
    threads.forEach { it.join() }

    var offset = 0L
    for (b in 0 until blocks) {
        val start = bounds[b]
        val end = bounds[b + 1]
        if (start == end) continue
        val blockTotal = result[end - 1]
        if (offset != 0L) {
            for (i in start until end) {
                result[i] += offset
            }
        }
        offset += blockTotal
    }
    return result
}

fun readArray(): LongArray {
    println("Введите целые числа через пробел или запятую (пустая строка — пустой массив):")
    val line = readlnOrNull() ?: ""
    val tokens = line.replace(',', ' ').trim().split(Regex("\\s+")).filter { it.isNotEmpty() }
    val values = LongArray(tokens.size)
    for (i in tokens.indices) {
        val value = tokens[i].toLongOrNull()
        if (value == null) {
            println("Ошибка: \"${tokens[i]}\" не является целым 64-битным числом.")
            exitProcess(1)
        }
        values[i] = value
    }
    return values
}

fun main() {
    val data = readArray()
    val parallel = parallelPrefixSums(data)
    val sequential = sequentialPrefixSums(data)

    println("Исходный массив:               ${data.joinToString(", ", "[", "]")}")
    println("Параллельный результат:        ${parallel.joinToString(", ", "[", "]")}")
    println("Последовательный результат:    ${sequential.joinToString(", ", "[", "]")}")
    println("Результаты совпадают:          ${if (parallel.contentEquals(sequential)) "да" else "нет"}")
}