(define-condition conversion-error (error)
  ((message :initarg :message :reader conversion-error-message)))

(defvar *console-out*
  (sb-sys:make-fd-stream 1 :output t :buffering :line :external-format :utf-8))

(defvar *console-err*
  (sb-sys:make-fd-stream 2 :output t :buffering :line :external-format :utf-8))

(defun say (stream control &rest args)
  (apply #'format stream control args)
  (terpri stream)
  (finish-output stream))

(defun fail (control &rest args)
  (error 'conversion-error :message (apply #'format nil control args)))

(defun script-arguments ()
  (let ((tail (member "--script" sb-ext:*posix-argv* :test #'string=)))
    (if tail
        (cddr tail)
        (rest sb-ext:*posix-argv*))))

(defun strip-cr (line)
  (let ((n (length line)))
    (if (and (plusp n) (char= (char line (1- n)) #\Return))
        (subseq line 0 (1- n))
        line)))

(defun strip-bom (line)
  (if (and (plusp (length line)) (char= (char line 0) (code-char #xFEFF)))
      (subseq line 1)
      line))

(defun split-tabs (line)
  (loop with start = 0
        for pos = (position #\Tab line :start start)
        collect (subseq line start pos)
        while pos
        do (setf start (1+ pos))))

(defun ascii-letter-p (c)
  (or (char<= #\a c #\z) (char<= #\A c #\Z)))

(defun ascii-digit-p (c)
  (char<= #\0 c #\9))

(defun valid-header-p (name)
  (and (plusp (length name))
       (ascii-letter-p (char name 0))
       (every (lambda (c) (or (ascii-letter-p c) (ascii-digit-p c) (char= c #\_)))
              name)))

(defun check-headers (headers)
  (let ((seen (make-hash-table :test #'equal)))
    (dolist (name headers)
      (cond ((zerop (length name))
             (fail "пустое имя столбца (заголовок: строка 1)"))
            ((not (valid-header-p name))
             (fail "недопустимое имя столбца \"~A\": допускаются латинские буквы, цифры и _, первым должна быть буква" name))
            ((gethash name seen)
             (fail "повторяющееся имя столбца \"~A\"" name)))
      (setf (gethash name seen) t))))

(defun read-lines (path name)
  (handler-case
      (with-open-file (in path :external-format :utf-8)
        (loop for line = (read-line in nil nil)
              while line
              collect line))
    (error (c)
      (fail "не удалось прочитать файл ~A: ~A" name c))))

(defun parse-tsv (raw-lines)
  (when (null raw-lines)
    (fail "файл пуст: нет строки заголовков"))
  (let ((lines (mapcar #'strip-cr raw-lines)))
    (loop for line in lines
          for number from 1
          do (when (find #\Return line)
               (fail "строка ~D: недопустимый символ возврата каретки внутри поля" number)))
    (let* ((headers (split-tabs (strip-bom (first lines))))
           (column-count (length headers)))
      (check-headers headers)
      (values headers
              (loop for line in (rest lines)
                    for number from 2
                    for fields = (split-tabs line)
                    do (unless (= (length fields) column-count)
                         (fail "строка ~D: ожидалось полей ~D, найдено ~D"
                               number column-count (length fields)))
                    collect fields)))))

(defun yaml-quote (value)
  (with-output-to-string (out)
    (write-char #\' out)
    (loop for c across value
          do (write-char c out)
             (when (char= c #\')
               (write-char #\' out)))
    (write-char #\' out)))

(defun yaml-key (name)
  (if (member (string-downcase name)
              '("y" "n" "yes" "no" "true" "false" "on" "off" "null")
              :test #'string=)
      (format nil "'~A'" name)
      name))

(defun yaml-document (headers records)
  (if (null records)
      (format nil "[]~%")
      (with-output-to-string (out)
        (dolist (fields records)
          (loop for name in headers
                for value in fields
                for first = t then nil
                do (format out "~A~A: ~A~%"
                           (if first "- " "  ")
                           (yaml-key name)
                           (yaml-quote value)))))))

(defun write-text (path name text)
  (handler-case
      (with-open-file (out path :direction :output
                                :if-exists :supersede
                                :if-does-not-exist :create
                                :external-format :utf-8)
        (write-string text out))
    (error (c)
      (fail "не удалось записать выходной файл ~A: ~A" name c))))

(defun convert (in-path out-path)
  (let ((in (sb-ext:parse-native-namestring in-path))
        (out (sb-ext:parse-native-namestring out-path)))
    (unless (probe-file in)
      (fail "входной файл ~A не найден" in-path))
    (let ((existing (probe-file out)))
      (when (and existing (equal existing (probe-file in)))
        (fail "входной и выходной файлы совпадают, исходные данные не будут затёрты")))
    (multiple-value-bind (headers records)
        (parse-tsv (read-lines in in-path))
      (write-text out out-path (yaml-document headers records))
      (length records))))

(defun run (args)
  (if (/= (length args) 2)
      (progn
        (say *console-err*
             "Использование: sbcl --script 5_convert/task_1_lisp/main.lisp <входной.tsv> <выходной.yaml>")
        1)
      (handler-case
          (let ((count (convert (first args) (second args))))
            (say *console-out* "Готово: обработано записей: ~D. Результат: ~A"
                 count (second args))
            0)
        (conversion-error (c)
          (say *console-err* "Ошибка: ~A" (conversion-error-message c))
          1)
        (error (c)
          (say *console-err* "Ошибка: ~A" c)
          1))))

(sb-ext:exit :code (run (script-arguments)))