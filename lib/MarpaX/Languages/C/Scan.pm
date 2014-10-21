use strict;
use warnings FATAL => 'all';

package MarpaX::Languages::C::Scan;

# ABSTRACT: C::Scan-like interface

use MarpaX::Languages::C::AST::Grammar::ISO_ANSI_C_2011::Scan;
use Carp qw/croak/;

our $VERSION = '0.36'; # TRIAL VERSION


sub new {
  my ($class, %options) = @_;

  my $grammarName = $options{grammarName} || 'ISO-ANSI-C-2011';

  if (! defined($grammarName)) {
    croak 'Usage: new($grammar_Name)';
  } elsif ($grammarName eq 'ISO-ANSI-C-2011') {
    return MarpaX::Languages::C::AST::Grammar::ISO_ANSI_C_2011::Scan->new(%options);
  } else {
    croak "Unsupported grammar name $grammarName";
  }
}


1;

__END__

=pod

=encoding utf-8

=head1 NAME

MarpaX::Languages::C::Scan - C::Scan-like interface

=head1 VERSION

version 0.36

=head1 SYNOPSIS

    use MarpaX::Languages::C::Scan;
    my $cSourceCode = <<C_SOURCE_CODE;

typedef int myInt_type;
typedef enum myEnum1_e {X11 = 0, X12} myEnumType1_t, *myEnumType1p_t;
typedef enum {X21 = 0, X22} myEnumType2_t, *myEnumType2p_t;
typedef struct myStruct1 {int x;} myStructType1_t, *myStructType1p_t;
typedef struct {int x;} myStructType2_t, *myStructType2p_t;

C_SOURCE_CODE
    my $scan = MarpaX::Languages::C::Scan->new(content => $cSourceCode);

=head1 DESCRIPTION

This modules returns a grammar dependant C::Scan-like interface. Current grammars are:

=over

=item ISO-ANSI-C-2011

The ISO grammar of ANSI C 2011, as of L<http://www.quut.com/c/ANSI-C-grammar-y-2011.html> and L<http://www.quut.com/c/ANSI-C-grammar-l.html>.

=back

=head1 SUBROUTINES/METHODS

=head2 new($class, grammarName => $grammarName, %options)

Instance a new object. Takes a hash as argument. The entire %options content is forwarded to a per-grammar C::Scan-like implement. Supported grammars are:

=over

=item ISO-ANSI-C-2011

ISO ANSI C 2011, with GNU and MSVS extensions. This is the default value.

=back

Please refer to per-grammar documentation for other options and methods.

=head1 SEE ALSO

L<MarpaX::Languages::C::AST::Grammar::ISO_ANSI_C_2011::Scan>

=head1 AUTHOR

Jean-Damien Durand <jeandamiendurand@free.fr>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Jean-Damien Durand.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
