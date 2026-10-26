use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));
use Encode qw(decode FB_CROAK LEAVE_SRC);

sub fail {
    print STDERR "Ошибка: $_[0]\n";
    exit 1;
}

sub valid_date {
    my ($y, $m, $d) = @_;
    return 0 if $y < 1 || $m < 1 || $m > 12 || $d < 1;
    my @days = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
    $days[1] = 29 if $y % 4 == 0 && ($y % 100 != 0 || $y % 400 == 0);
    return $d <= $days[$m - 1];
}

sub sort_key {
    my $key = lc $_[0];
    $key =~ s/ё/е\x{E000}/g;
    return $key;
}

@ARGV = map { decode('UTF-8', $_) } @ARGV;
if (@ARGV != 2) {
    print STDERR "Использование: perl $0 <файл_журнала> <файл_отчёта>\n";
    exit 1;
}
my ($in_path, $out_path) = @ARGV;

fail("входной файл \"$in_path\" не найден.") unless -e $in_path;
fail("\"$in_path\" не является обычным файлом.") unless -f $in_path;
fail("нет доступа на чтение файла \"$in_path\".") unless -r $in_path;

if (-e $out_path) {
    my @in_id  = stat $in_path;
    my @out_id = stat $out_path;
    fail("файл отчёта совпадает с файлом журнала, отчёт не будет записан.")
        if $in_id[0] == $out_id[0] && $in_id[1] == $out_id[1];
}

open(my $in, '<:raw', $in_path)
    or fail("не удалось открыть \"$in_path\": $!");

my (%stats, $valid, $invalid, $nonblank);
$valid = $invalid = $nonblank = 0;

while (my $raw = <$in>) {
    my $n = $.;
    my $line = eval { decode('UTF-8', $raw, FB_CROAK | LEAVE_SRC) };
    if (!defined $line) {
        warn "Предупреждение: строка $n пропущена: строка не в кодировке UTF-8\n";
        $invalid++;
        $nonblank++;
        next;
    }
    $line =~ s/\r?\n\z//;
    $line =~ s/\A\x{FEFF}// if $n == 1;
    next if $line =~ /\A\s*\z/;
    $nonblank++;

    my @f = split /;/, $line, -1;
    my $problem;
    if (@f != 3) {
        $problem = "ожидалось 3 поля, найдено " . scalar(@f);
    } else {
        s/\A\s+|\s+\z//g for @f;
        $f[0] =~ s/\s+/ /g;
        if ($f[0] eq '') {
            $problem = 'пустое имя студента';
        } elsif ($f[1] !~ /\A([0-9]{4})-([0-9]{2})-([0-9]{2})\z/
                 || !valid_date($1, $2, $3)) {
            $problem = 'неверная дата (нужна существующая дата YYYY-MM-DD)';
        } elsif ($f[2] !~ /\A[01]\z/) {
            $problem = 'отметка должна быть 0 или 1';
        }
    }

    if (defined $problem) {
        warn "Предупреждение: строка $n пропущена: $problem: \"$line\"\n";
        $invalid++;
        next;
    }

    $stats{$f[0]}{$f[2] ? 'present' : 'absent'}++;
    $valid++;
}
close($in);

fail("журнал \"$in_path\" пуст, отчёт не создан.") unless $nonblank;
fail("в журнале нет ни одной корректной записи, отчёт не создан.") unless $valid;

my @names = sort { sort_key($a) cmp sort_key($b) or $a cmp $b } keys %stats;
my $width = length('Студент');
for my $name (@names) {
    $width = length($name) if length($name) > $width;
}

my $format = "%-*s  %9s  %9s  %5s  %8s\n";
my $rule = '-' x ($width + 39) . "\n";
my $report = "Отчёт о посещаемости студентов\n" . $rule
    . sprintf($format, $width, 'Студент', 'Посещений', 'Пропусков', 'Всего', 'Процент')
    . $rule;

for my $name (@names) {
    my $present = $stats{$name}{present} || 0;
    my $absent  = $stats{$name}{absent}  || 0;
    my $total   = $present + $absent;
    my $percent = sprintf('%.2f%%', 100 * $present / $total);
    $report .= sprintf($format, $width, $name, $present, $absent, $total, $percent);
}

$report .= $rule
    . "Учтено записей: $valid; пропущено некорректных строк: $invalid\n";

open(my $out, '>:encoding(UTF-8)', $out_path)
    or fail("не удалось создать отчёт \"$out_path\": $!");
print {$out} $report;
close($out)
    or fail("ошибка записи отчёта \"$out_path\": $!");

print $report;
print STDERR "Отчёт записан в \"$out_path\".\n";