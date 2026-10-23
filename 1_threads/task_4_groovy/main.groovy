println 'Введите целые числа через пробел:'
def line = System.in.newReader('UTF-8').readLine() ?: ''
def tokens = line.trim() ? line.trim().split(/\s+/).toList() : []

if (tokens.isEmpty()) {
    println 'Ошибка: массив пуст, нужен хотя бы один элемент.'
    System.exit(1)
}

def notNumbers = tokens.findAll { t -> !(t ==~ /[+-]?\d+/) }
if (notNumbers) {
    println "Ошибка: недопустимые значения: ${notNumbers.join(', ')}. Нужны целые числа."
    System.exit(1)
}

List<Long> data = []
def outOfRange = []
tokens.each { t ->
    try {
        data << Long.parseLong(t)
    } catch (NumberFormatException e) {
        outOfRange << t
    }
}
if (outOfRange) {
    println "Ошибка: значения не помещаются в 64-битное целое (Long): ${outOfRange.join(', ')}."
    System.exit(1)
}

def counts = new long[4]
def threads = [
    new Thread({ counts[0] = data.count { v -> v > 0 } } as Runnable, 'positive'),
    new Thread({ counts[1] = data.count { v -> v < 0 } } as Runnable, 'negative'),
    new Thread({ counts[2] = data.count { v -> v % 2 == 0 } } as Runnable, 'even'),
    new Thread({ counts[3] = data.count { v -> v % 2 != 0 } } as Runnable, 'odd')
]

threads*.start()
threads*.join()

long zeros = data.count { v -> v == 0 }

println "Исходный массив: ${data}"
println "Всего элементов: ${data.size()}"
println "Положительных (> 0): ${counts[0]}"
println "Отрицательных (< 0): ${counts[1]}"
println "Чётных:              ${counts[2]}"
println "Нечётных:            ${counts[3]}"
println "Нулей (чётные, но не положительные и не отрицательные): ${zeros}"

boolean parityOk = counts[2] + counts[3] == data.size()
boolean signOk = counts[0] + counts[1] + zeros == data.size()
println "Проверка (чётные + нечётные = размер): ${parityOk ? 'да' : 'нет'}"
println "Проверка (положительные + отрицательные + нули = размер): ${signOk ? 'да' : 'нет'}"

if (!(parityOk && signOk)) {
    System.exit(1)
}