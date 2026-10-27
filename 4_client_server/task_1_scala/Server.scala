import java.io.{BufferedReader, FileDescriptor, FileOutputStream, IOException, InputStreamReader, OutputStreamWriter, PrintStream}
import java.net.{InetAddress, ServerSocket, Socket, SocketTimeoutException}
import java.nio.charset.StandardCharsets

object Server {
  private val Port = 5051
  private val TimePattern = """(\d{2}):(\d{2})""".r
  private val screen = new PrintStream(new FileOutputStream(FileDescriptor.out), true, StandardCharsets.UTF_8)

  final case class Booking(start: Int, end: Int) {
    def label: String = f"${start / 60}%02d:${start % 60}%02d-${end / 60}%02d:${end % 60}%02d"
  }

  private var bookings: Vector[Booking] = Vector.empty

  private def parseTime(text: String): Option[Int] =
    text match {
      case TimePattern(h, m) =>
        val hours = h.toInt
        val minutes = m.toInt
        if (hours <= 23 && minutes <= 59) Some(hours * 60 + minutes) else None
      case _ => None
    }

  private def book(startText: String, endText: String): List[String] =
    (parseTime(startText), parseTime(endText)) match {
      case (Some(start), Some(end)) =>
        if (start == end) List("ERROR: начало и окончание совпадают, интервал пустой.")
        else if (start > end) List("ERROR: окончание раньше начала.")
        else {
          val wanted = Booking(start, end)
          bookings.find(b => start < b.end && b.start < end) match {
            case Some(existing) =>
              List(s"ERROR: интервал ${wanted.label} пересекается с бронированием ${existing.label}.")
            case None =>
              bookings = (bookings :+ wanted).sortBy(_.start)
              List(s"OK: забронировано ${wanted.label}.")
          }
        }
      case _ =>
        List("ERROR: некорректное время, нужен формат HH:MM (часы 00-23, минуты 00-59).")
    }

  private def list(): List[String] =
    if (bookings.isEmpty) List("Список бронирований пуст.")
    else s"Бронирований: ${bookings.size}" :: bookings.map(_.label).toList

  private def handle(request: String): List[String] =
    request.trim.split("\\s+").toList match {
      case "BOOK" :: start :: end :: Nil => book(start, end)
      case "BOOK" :: _ => List("ERROR: формат команды: BOOK HH:MM HH:MM.")
      case "LIST" :: Nil => list()
      case _ => List("ERROR: неизвестная команда. Доступно: BOOK HH:MM HH:MM, LIST.")
    }

  private def serve(socket: Socket): Unit = {
    socket.setSoTimeout(5000)
    val in = new BufferedReader(new InputStreamReader(socket.getInputStream, StandardCharsets.UTF_8))
    val out = new OutputStreamWriter(socket.getOutputStream, StandardCharsets.UTF_8)
    val request = in.readLine()
    if (request == null) {
      screen.println("Клиент отключился, не прислав команду.")
    } else {
      val reply = handle(request)
      screen.println(s"Запрос: $request -> ${reply.head}")
      out.write(reply.mkString("", "\n", "\n"))
      out.flush()
    }
  }

  def main(args: Array[String]): Unit = {
    val server =
      try new ServerSocket(Port, 10, InetAddress.getByName("127.0.0.1"))
      catch {
        case e: IOException =>
          screen.println(s"Ошибка: не удалось запустить сервер на порту $Port: ${e.getMessage}")
          sys.exit(1)
      }
    screen.println(s"Сервер запущен: 127.0.0.1:$Port. Остановка: Ctrl+C.")
    while (true) {
      try {
        val socket = server.accept()
        try serve(socket)
        finally socket.close()
      } catch {
        case _: SocketTimeoutException =>
          screen.println("Клиент не прислал команду за 5 секунд, соединение закрыто.")
        case e: IOException =>
          screen.println(s"Ошибка соединения: ${e.getMessage}")
      }
    }
  }
}