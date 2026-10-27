import java.io.{BufferedReader, FileDescriptor, FileOutputStream, IOException, InputStreamReader, OutputStreamWriter, PrintStream}
import java.net.{ConnectException, InetSocketAddress, Socket, SocketTimeoutException}
import java.nio.charset.StandardCharsets

object Client {
  private val Host = "127.0.0.1"
  private val Port = 5051
  private val screen = new PrintStream(new FileOutputStream(FileDescriptor.out), true, StandardCharsets.UTF_8)

  def main(args: Array[String]): Unit = {
    val command =
      if (args.nonEmpty) args.mkString(" ")
      else {
        screen.print("Введите команду (BOOK HH:MM HH:MM или LIST): ")
        screen.flush()
        scala.io.StdIn.readLine()
      }
    if (command == null || command.trim.isEmpty) {
      screen.println("Ошибка: команда не введена.")
      sys.exit(1)
    }

    val socket = new Socket()
    try {
      socket.connect(new InetSocketAddress(Host, Port), 3000)
      socket.setSoTimeout(5000)
      val out = new OutputStreamWriter(socket.getOutputStream, StandardCharsets.UTF_8)
      out.write(command.trim + "\n")
      out.flush()
      val in = new BufferedReader(new InputStreamReader(socket.getInputStream, StandardCharsets.UTF_8))
      val reply = Iterator.continually(in.readLine()).takeWhile(_ != null).toList
      if (reply.isEmpty) {
        screen.println("Ошибка: сервер закрыл соединение без ответа.")
        sys.exit(1)
      } else {
        reply.foreach(line => screen.println(line))
      }
    } catch {
      case _: ConnectException =>
        screen.println(s"Ошибка: не удалось подключиться к серверу $Host:$Port. Запущен ли сервер?")
        sys.exit(1)
      case _: SocketTimeoutException =>
        screen.println("Ошибка: сервер не ответил вовремя.")
        sys.exit(1)
      case e: IOException =>
        screen.println(s"Ошибка соединения: ${e.getMessage}")
        sys.exit(1)
    } finally {
      socket.close()
    }
  }
}