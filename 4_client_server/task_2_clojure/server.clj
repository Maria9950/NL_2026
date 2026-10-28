(ns server
  (:require [clojure.string :as str])
  (:import (java.io BufferedReader IOException InputStreamReader OutputStreamWriter)
           (java.net InetAddress ServerSocket Socket SocketTimeoutException)
           (java.nio.charset StandardCharsets)))

(def port 5052)
(def max-length 10000)
(def read-timeout-ms 5000)

(defn fail [message]
  (throw (ex-info message {})))

(defn encode [text]
  (when-not (re-matches #"[A-Z]+" text)
    (fail "ENC принимает непустую строку из заглавных латинских букв A-Z."))
  (when (> (count text) max-length)
    (fail (str "строка длиннее " max-length " символов.")))
  (apply str (map #(str (count %) (first %)) (partition-by identity text))))

(defn parse-count [digits]
  (let [trimmed (str/replace digits #"^0+" "")]
    (cond
      (empty? trimmed) 0
      (> (count trimmed) 9) (inc max-length)
      :else (Long/parseLong trimmed))))

(defn decode [text]
  (let [pairs (re-seq #"(\d+)([A-Z])" text)]
    (when-not (and (seq pairs) (= text (apply str (map first pairs))))
      (fail "DEC принимает пары <число><буква>, например 3A2B: число повторений и заглавная латинская буква."))
    (let [runs (map (fn [[_ digits letter]] [(parse-count digits) letter]) pairs)]
      (when (some #(zero? (first %)) runs)
        (fail "количество повторений должно быть положительным."))
      (when (> (reduce + (map first runs)) max-length)
        (fail (str "результат длиннее " max-length " символов.")))
      (apply str (map (fn [[n letter]] (apply str (repeat n letter))) runs)))))

(defn handle-request [line]
  (try
    (let [[command data & extra] (str/split (str/trim line) #"\s+")]
      (cond
        (not (#{"ENC" "DEC"} command))
        (fail "неизвестная команда. Доступно: ENC <строка>, DEC <пары>.")

        (nil? data)
        (fail (str "для команды " command " нужны данные: " command " <данные>."))

        (seq extra)
        (fail "слишком много аргументов, ожидается: КОМАНДА ДАННЫЕ.")

        (= command "ENC") (encode data)
        :else (decode data)))
    (catch clojure.lang.ExceptionInfo e
      (str "ERROR: " (ex-message e)))))

(defn preview [text]
  (if (> (count text) 60)
    (str (subs text 0 60) "...")
    text))

(defn serve [^Socket socket]
  (.setSoTimeout socket read-timeout-ms)
  (let [in (BufferedReader. (InputStreamReader. (.getInputStream socket) StandardCharsets/UTF_8))
        out (OutputStreamWriter. (.getOutputStream socket) StandardCharsets/UTF_8)
        request (.readLine in)]
    (if (nil? request)
      (println "Клиент отключился, не прислав команду.")
      (let [reply (handle-request request)]
        (println "Запрос:" (preview request) "->" (preview reply))
        (.write out (str reply "\n"))
        (.flush out)))))

(defn -main [& _]
  (let [^ServerSocket server
        (try
          (ServerSocket. (int port) 10 (InetAddress/getByName "127.0.0.1"))
          (catch IOException e
            (println "Ошибка: не удалось запустить сервер на порту" port ":" (.getMessage e))
            (System/exit 1)))]
    (println (str "Сервер запущен: 127.0.0.1:" port ". Остановка: Ctrl+C."))
    (loop []
      (try
        (with-open [socket (.accept server)]
          (serve socket))
        (catch SocketTimeoutException _
          (println "Клиент не прислал команду за 5 секунд, соединение закрыто."))
        (catch IOException e
          (println "Ошибка соединения:" (.getMessage e)))
        (catch Exception e
          (println "Внутренняя ошибка:" (.getMessage e))))
      (recur))))

(-main)