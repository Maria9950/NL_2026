CASHIERS = 3
STOP = :stop

puts "Введите суммы заказов в рублях через пробел:"
tokens = ($stdin.gets || "").split

if tokens.empty?
  puts "Ошибка: заказы не введены."
  exit 1
end

invalid = tokens.reject { |t| t.match?(/\A\d+\z/) && t.to_i.positive? }
unless invalid.empty?
  puts "Ошибка: недопустимые значения: #{invalid.join(', ')}. Нужны положительные целые числа."
  exit 1
end

orders = tokens.map(&:to_i)

queue = Queue.new
orders.each { |amount| queue << amount }
CASHIERS.times { queue << STOP }

total = 0
total_lock = Mutex.new
out_lock = Mutex.new
revenue = Array.new(CASHIERS, 0)
counts = Array.new(CASHIERS, 0)

threads = Array.new(CASHIERS) do |i|
  Thread.new do
    loop do
      order = queue.pop
      break if order == STOP
      sleep(0.02)
      revenue[i] += order
      counts[i] += 1
      total_lock.synchronize { total += order }
      out_lock.synchronize { puts "Кассир #{i + 1} обработал заказ на #{order} руб." }
    end
  end
end

threads.each(&:join)

puts
CASHIERS.times do |i|
  puts "Кассир #{i + 1}: заказов #{counts[i]}, выручка #{revenue[i]} руб."
end
puts "Общая выручка (счётчик под Mutex): #{total} руб."
puts "Сумма введённых заказов:           #{orders.sum} руб."
puts "Сумма выручек кассиров:            #{revenue.sum} руб."

ok = total == orders.sum && revenue.sum == orders.sum && counts.sum == orders.size
puts "Проверка: #{ok ? 'выручка сходится, все заказы обработаны' : 'ОШИБКА, данные не сходятся'}"
exit 1 unless ok