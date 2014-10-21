#!perl -T
use strict;
use warnings FATAL => 'all';
use Test::More tests => 2;

BEGIN {
    push(@INC, 'inc');
    use_ok( 'MarpaX::Languages::C::AST' ) || print "Bail out!\n";
}

my $cSourceCode = do { local $/; <DATA> };
my $cAst = MarpaX::Languages::C::AST->new();
my $valuep = $cAst->parse(\$cSourceCode);
ok(defined($valuep), 'Output from parse() is ok');

__DATA__
int main() {
    __extension__ typedef int myInt;
  if(!__extension__ ({ 1; })) {
  }
  if(__extension__ ({ 1; })) {
  }
  if(__extension__ ({ __extension__ 1; })) {
  }
}
