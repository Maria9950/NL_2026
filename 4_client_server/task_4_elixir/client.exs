defmodule TemperatureClient do
  @host {127, 0, 0, 1}
  @port 5054
  @connect_timeout 3000
  @reply_timeout 5000

  def main(args) do
    :io.setopts(encoding: :unicode)

    status =
      case args do
        [] ->
          IO.puts("Использование: elixir client.exs <температура в градусах Цельсия>")
          1

        _ ->
          run(Enum.join(args, " "))
      end

    System.halt(status)
  end

  defp run(text) do
    case request(String.replace(text, ["\r", "\n"], " ")) do
      {:ok, reply} ->
        IO.puts(reply)
        0

      {:error, message} ->
        IO.puts(message)
        1
    end
  end

  defp request(text) do
    case :gen_tcp.connect(@host, @port, [:binary, active: false], @connect_timeout) do
      {:ok, socket} ->
        result = exchange(socket, text)
        :gen_tcp.close(socket)
        result

      {:error, :econnrefused} ->
        {:error, "Ошибка: не удалось подключиться к серверу 127.0.0.1:#{@port}. Запущен ли сервер?"}

      {:error, :timeout} ->
        {:error, "Ошибка: превышено время ожидания подключения."}

      {:error, reason} ->
        {:error, "Ошибка подключения: #{:inet.format_error(reason)}"}
    end
  end

  defp exchange(socket, text) do
    case :gen_tcp.send(socket, text <> "\n") do
      :ok -> receive_reply(socket, "")
      {:error, reason} -> {:error, "Ошибка отправки: #{:inet.format_error(reason)}"}
    end
  end

  defp receive_reply(socket, acc) do
    case :gen_tcp.recv(socket, 0, @reply_timeout) do
      {:ok, data} ->
        receive_reply(socket, acc <> data)

      {:error, :closed} when acc != "" ->
        {:ok, String.trim_trailing(acc, "\n")}

      {:error, :closed} ->
        {:error, "Ошибка: сервер закрыл соединение без ответа."}

      {:error, :timeout} ->
        {:error, "Ошибка: сервер не ответил вовремя."}

      {:error, reason} ->
        {:error, "Ошибка соединения: #{:inet.format_error(reason)}"}
    end
  end
end

TemperatureClient.main(System.argv())