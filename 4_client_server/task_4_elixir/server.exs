defmodule TemperatureServer do
  @port 5054
  @recv_timeout 5000
  @max_length 32
  @max_abs 1.0e15

  def main do
    :io.setopts(encoding: :unicode)
    options = [:binary, packet: :line, active: false, reuseaddr: true, ip: {127, 0, 0, 1}]

    case :gen_tcp.listen(@port, options) do
      {:ok, listen} ->
        IO.puts("Сервер запущен: 127.0.0.1:#{@port}. Остановка: Ctrl+C, затем a и Enter.")
        accept_loop(listen)

      {:error, reason} ->
        IO.puts("Ошибка: не удалось запустить сервер на порту #{@port}: #{:inet.format_error(reason)}")
        System.halt(1)
    end
  end

  defp accept_loop(listen) do
    case :gen_tcp.accept(listen) do
      {:ok, socket} ->
        try do
          serve(socket)
        rescue
          error -> IO.puts("Внутренняя ошибка: #{Exception.message(error)}")
        after
          :gen_tcp.close(socket)
        end

      {:error, reason} ->
        IO.puts("Ошибка приёма соединения: #{:inet.format_error(reason)}")
        Process.sleep(200)
    end

    accept_loop(listen)
  end

  defp serve(socket) do
    case :gen_tcp.recv(socket, 0, @recv_timeout) do
      {:ok, line} ->
        reply = answer(line)
        IO.puts("Запрос: #{inspect(preview(line))} -> #{reply}")
        send_reply(socket, reply)

      {:error, :closed} ->
        IO.puts("Клиент отключился, не прислав данные.")

      {:error, :timeout} ->
        IO.puts("Клиент не прислал данные за 5 секунд.")
        send_reply(socket, "ERROR: данные не получены за 5 секунд")

      {:error, reason} ->
        IO.puts("Ошибка чтения: #{:inet.format_error(reason)}")
    end
  end

  defp send_reply(socket, reply) do
    :gen_tcp.send(socket, reply <> "\n")
  end

  defp answer(line) do
    case parse_celsius(String.trim(line)) do
      {:ok, celsius} -> format(to_fahrenheit(celsius))
      {:error, message} -> "ERROR: " <> message
    end
  end

  defp parse_celsius("") do
    {:error, "пустая строка, ожидается число, например 36.6"}
  end

  defp parse_celsius(text) do
    cond do
      not Regex.match?(~r/\A[+-]?[0-9]+(\.[0-9]+)?\z/, text) ->
        {:error, "неверный формат числа, ожидается, например, 25, -40, +3.5"}

      byte_size(text) > @max_length ->
        {:error, "слишком длинная запись числа (не более #{@max_length} символов)"}

      true ->
        {value, ""} = text |> String.trim_leading("+") |> Float.parse()

        if abs(value) > @max_abs do
          {:error, "значение по модулю не должно превышать 1.0e15"}
        else
          {:ok, value}
        end
    end
  end

  defp to_fahrenheit(celsius), do: 1.8 * celsius + 32

  defp format(fahrenheit) do
    fahrenheit
    |> :erlang.float_to_binary(decimals: 2)
    |> String.trim_trailing("0")
    |> String.trim_trailing(".")
    |> normalize_zero()
  end

  defp normalize_zero("-0"), do: "0"
  defp normalize_zero(text), do: text

  defp preview(line), do: binary_part(line, 0, min(byte_size(line), 60))
end

TemperatureServer.main()