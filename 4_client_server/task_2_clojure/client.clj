(ns client
  (:require [clojure.string :as str])
  (:import (java.io BufferedReader IOException InputStreamReader OutputStreamWriter)
           (java.net ConnectException InetSocketAddress Socket SocketTimeoutException)
           (java.nio.charset StandardCharsets)))

(def host "127.0.0.1")
(def port 5052)

(defn exchange [command]
  (with-open [^Socket socket (Socket.)]
    (.connect socket (InetSocketAddress. ^String host (int port)) 3000)
    (.setSoTimeout socket 5000)
    (let [out (OutputStreamWriter. (.getOutputStream socket) StandardCharsets/UTF_8)
          in (BufferedReader. (InputStreamReader. (.getInputStream socket) StandardCharsets/UTF_8))]
      (.write out (str command "\n"))
      (.flush out)
      (.readLine in))))

(defn -main [& args]
  (if (empty? args)
    (do
      (println "Использование: clojure -M client.clj ENC <строка> | DEC <пары>")
      (System/exit 1))
    (try
      (let [reply (exchange (str/join " " args))]
        (if (nil? reply)
          (do
            (println "Ошибка: сервер закрыл соединение без ответа.")
            (System/exit 1))
          (println reply)))
      (catch ConnectException _
        (println (str "Ошибка: не удалось подключиться к серверу " host ":" port ". Запущен ли сервер?"))
        (System/exit 1))
      (catch SocketTimeoutException _
        (println "Ошибка: сервер не ответил вовремя.")
        (System/exit 1))
      (catch IOException e
        (println "Ошибка соединения:" (.getMessage e))
        (System/exit 1)))))

(apply -main *command-line-args*)