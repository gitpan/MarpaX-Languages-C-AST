#!perl -T
use strict;
use warnings FATAL => 'all';
use Test::More tests => 2;
use Test::Trap
;
BEGIN {
    push(@INC, 'inc');
    use_ok( 'MarpaX::Languages::C::AST' ) || print "Bail out!\n";
}
use MarpaX::Languages::C::AST::Expected;

my $cSourceCode = do { local $/; <DATA> };
my $cAst = MarpaX::Languages::C::AST->new();
my @r = trap {$cAst->parse(\$cSourceCode)};
like($trap->die || '', qr/typedef is not valid in a parameter declaration/, $cSourceCode);
__DATA__
void func(int x, typedef y) {}
