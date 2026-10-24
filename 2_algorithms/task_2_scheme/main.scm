(use-modules (ice-9 rdelim))

(set-port-encoding! (current-input-port) "UTF-8")
(set-port-encoding! (current-output-port) "UTF-8")

(define (count-atoms x)
  (cond ((null? x) 0)
        ((pair? x) (+ (count-atoms (car x)) (count-atoms (cdr x))))
        (else 1)))

(define failed (list 'failed))

(define (safe-read port)
  (catch #t
    (lambda () (read port))
    (lambda args failed)))

(define (stop-with-error message)
  (display message)
  (newline)
  (exit 1))

(display "Введите список в синтаксисе Scheme, например (a (b c) () (d (e f))):")
(newline)

(define line (read-line))
(define in (open-input-string (if (eof-object? line) "" line)))
(define datum (safe-read in))

(cond ((eq? datum failed)
       (stop-with-error "Ошибка: некорректный синтаксис списка (проверьте скобки и кавычки)."))
      ((eof-object? datum)
       (stop-with-error "Ошибка: ввод пуст, нужен список."))
      ((not (list? datum))
       (stop-with-error "Ошибка: ввод не является списком, нужен список в скобках."))
      ((not (eof-object? (safe-read in)))
       (stop-with-error "Ошибка: после списка найдены лишние данные или закрывающая скобка."))
      (else
       (display "Исходный список: ")
       (write datum)
       (newline)
       (display "Количество атомарных элементов: ")
       (display (count-atoms datum))
       (newline)))