use strict;
use warnings;

my $seed = $ARGV[0] // 0;
my $n = $ARGV[1] // 100;
my $x = ($seed * 2654435761 + 1) & 0xFFFFFFFF;
sub rnd {
    $x ^= ($x << 13) & 0xFFFFFFFF;
    $x ^= $x >> 17;
    $x ^= ($x << 5) & 0xFFFFFFFF;
    return $x;
}
my @names = ("add", "sub", "reset");
my $s = 0;
for my $i (1 .. $n) {
    my $op = rnd() % 3;
    my $a = rnd() % 100;
    $s = $op == 0 ? ($s + $a > 100 ? 100 : $s + $a) : $op == 1 ? ($s - $a < 0 ? 0 : $s - $a) : 0;
    print "$names[$op] $a $s\n";
}
