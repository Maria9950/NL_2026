use std::io;
use std::process;
use std::thread;

#[derive(Clone, Copy)]
struct Info {
    start: usize,
    end: usize,
    first: i64,
    last: i64,
    prefix: usize,
    suffix: usize,
    best_start: usize,
    best_len: usize,
}

fn better(a: (usize, usize), b: (usize, usize)) -> (usize, usize) {
    if b.1 > a.1 || (b.1 == a.1 && b.0 < a.0) {
        b
    } else {
        a
    }
}

fn analyze_block(block: &[i64], offset: usize) -> Info {
    let n = block.len();
    let mut best_start = 0;
    let mut best_len = 0;
    let mut run_start = 0;
    let mut prefix = 0;
    let mut suffix = 0;
    for i in 1..=n {
        if i == n || block[i] <= block[i - 1] {
            let run_len = i - run_start;
            if prefix == 0 {
                prefix = run_len;
            }
            if run_len > best_len {
                best_len = run_len;
                best_start = run_start;
            }
            suffix = run_len;
            run_start = i;
        }
    }
    Info {
        start: offset,
        end: offset + n,
        first: block[0],
        last: block[n - 1],
        prefix,
        suffix,
        best_start: offset + best_start,
        best_len,
    }
}

fn merge(a: Info, b: Info) -> Info {
    let a_len = a.end - a.start;
    let b_len = b.end - b.start;
    let connected = a.last < b.first;

    let prefix = if connected && a.prefix == a_len {
        a_len + b.prefix
    } else {
        a.prefix
    };
    let suffix = if connected && b.suffix == b_len {
        b_len + a.suffix
    } else {
        b.suffix
    };

    let mut best = better((a.best_start, a.best_len), (b.best_start, b.best_len));
    if connected {
        best = better(best, (a.end - a.suffix, a.suffix + b.prefix));
    }

    Info {
        start: a.start,
        end: b.end,
        first: a.first,
        last: b.last,
        prefix,
        suffix,
        best_start: best.0,
        best_len: best.1,
    }
}

fn parallel_longest(data: &[i64]) -> (usize, usize, usize, usize) {
    let n = data.len();
    let blocks = if n < 4 { n } else { 4 };
    let bounds: Vec<usize> = (0..=blocks).map(|k| k * n / blocks).collect();

    let infos: Vec<Info> = thread::scope(|scope| {
        let handles: Vec<_> = (0..blocks)
            .map(|k| {
                let s = bounds[k];
                let e = bounds[k + 1];
                let slice = &data[s..e];
                scope.spawn(move || analyze_block(slice, s))
            })
            .collect();
        handles.into_iter().map(|h| h.join().unwrap()).collect()
    });

    let total = infos.into_iter().reduce(merge).unwrap();
    (
        total.best_len,
        total.best_start,
        total.best_start + total.best_len - 1,
        blocks,
    )
}

fn sequential_longest(data: &[i64]) -> (usize, usize, usize) {
    let mut best_start = 0;
    let mut best_len = 1;
    let mut cur_start = 0;
    for i in 1..data.len() {
        if data[i] <= data[i - 1] {
            cur_start = i;
        } else if i - cur_start + 1 > best_len {
            best_len = i - cur_start + 1;
            best_start = cur_start;
        }
    }
    (best_len, best_start, best_start + best_len - 1)
}

fn main() {
    println!("Введите целые числа через пробел:");
    let mut line = String::new();
    if io::stdin().read_line(&mut line).is_err() {
        println!("Ошибка: не удалось прочитать ввод.");
        process::exit(1);
    }

    let tokens: Vec<&str> = line.split_whitespace().collect();
    if tokens.is_empty() {
        println!("Ошибка: массив пуст, нужен хотя бы один элемент.");
        process::exit(1);
    }

    let mut data: Vec<i64> = Vec::with_capacity(tokens.len());
    let mut invalid: Vec<&str> = Vec::new();
    for token in &tokens {
        match token.parse::<i64>() {
            Ok(value) => data.push(value),
            Err(_) => invalid.push(token),
        }
    }
    if !invalid.is_empty() {
        println!(
            "Ошибка: недопустимые значения: {}. Нужны целые числа.",
            invalid.join(", ")
        );
        process::exit(1);
    }

    let (p_len, p_start, p_end, blocks) = parallel_longest(&data);
    let (s_len, s_start, s_end) = sequential_longest(&data);

    let parts: Vec<String> = data.iter().map(|v| v.to_string()).collect();
    let segment: Vec<String> = data[p_start..=p_end].iter().map(|v| v.to_string()).collect();

    println!("Исходный массив: [{}]", parts.join(", "));
    println!("Количество блоков (потоков): {}", blocks);
    println!(
        "Параллельный результат:      длина {}, начало {}, конец {}",
        p_len, p_start, p_end
    );
    println!(
        "Последовательный результат:  длина {}, начало {}, конец {}",
        s_len, s_start, s_end
    );
    println!("Найденный участок: [{}]", segment.join(", "));

    if (p_len, p_start, p_end) == (s_len, s_start, s_end) {
        println!("Результаты совпадают: да");
    } else {
        println!("Результаты совпадают: нет");
        process::exit(1);
    }
}