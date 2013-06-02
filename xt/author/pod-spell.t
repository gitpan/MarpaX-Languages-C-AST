use strict;
use warnings;
use Test::More;

# generated by Dist::Zilla::Plugin::Test::PodSpelling 2.006000
eval "use Test::Spelling 0.12; use Pod::Wordlist::hanekomu; 1" or die $@;


add_stopwords(<DATA>);
all_pod_files_spelling_ok( qw( bin lib  ) );
__DATA__
mckeeman
multipass
typedef
earley
bnf
lhs
rhs
recognizer
recognizer's
marpa
marpa's
scanless
lexeme
Jean
Durand
jeandamiendurand
lib
MarpaX
Languages
AST
Util
Grammar
Impl
Logger
Scope
ISO_ANSI_C_2011
