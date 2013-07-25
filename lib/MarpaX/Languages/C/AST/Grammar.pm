use strict;
use warnings FATAL => 'all';

package MarpaX::Languages::C::AST::Grammar;

# ABSTRACT: C grammar written in Marpa BNF

use MarpaX::Languages::C::AST::Grammar::ISO_ANSI_C_2011;
use Carp qw/croak/;

our $VERSION = '0.17'; # VERSION


sub new {
  my $class = shift;
  my $grammarName = shift;

  my $self = {};
  if (! defined($grammarName)) {
    croak 'Usage: new($grammar_Name)';
  } elsif ($grammarName eq 'ISO-ANSI-C-2011') {
    $self->{_grammar} = MarpaX::Languages::C::AST::Grammar::ISO_ANSI_C_2011->new(@_);
  } else {
    croak "Unsupported grammar name $grammarName";
  }
  bless($self, $class);

  return $self;
}


sub content {
    my ($self) = @_;
    return $self->{_grammar}->content(@_);
}


sub grammar_option {
    my ($self) = @_;
    return $self->{_grammar}->grammar_option(@_);
}


sub recce_option {
    my ($self) = @_;
    return $self->{_grammar}->recce_option(@_);
}


1;

__END__

=pod

=encoding utf-8

=head1 NAME

MarpaX::Languages::C::AST::Grammar - C grammar written in Marpa BNF

=head1 VERSION

version 0.17

=head1 SYNOPSIS

    use MarpaX::Languages::C::AST::Grammar;

    my $grammar = MarpaX::Languages::C::AST::Grammar->new('ISO-ANSI-C-2011');
    my $grammar_content = $grammar->content();
    my $grammar_option = $grammar->grammar_option();
    my $recce_option = $grammar->recce_option();

=head1 DESCRIPTION

This modules returns C grammar(s) written in Marpa BNF.
Current grammars are:
=over
=item *
ISO-ANSI-C-2011. The ISO grammar of ANSI C 2011, as of L<http://www.quut.com/c/ANSI-C-grammar-y-2011.html> and L<http://www.quut.com/c/ANSI-C-grammar-l.html>.
=back

=head1 SUBROUTINES/METHODS

=head2 new($grammarName, ...)

Instance a new object. Takes the name of the grammar as argument. Remaining arguments are passed to the sub grammar method.

=head2 content()

Returns the content of the grammar.

=head2 grammar_option()

Returns recommended option for Marpa::R2::Scanless::G->new(), returned as a reference to a hash.

=head2 recce_option()

Returns recommended option for Marpa::R2::Scanless::R->new(), returned as a reference to a hash.

=head1 SEE ALSO

L<Marpa::R2>, L<MarpaX::Languages::C::AST::Grammar::ISO_ANSI_C_2011>

=head1 AUTHOR

Jean-Damien Durand <jeandamiendurand@free.fr>

=head1 CONTRIBUTORS

=over 4

=item *

Jeffrey Kegler <jkegl@cpan.org>

=item *

jddurand <jeandamiendurand@free.fr>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Jean-Damien Durand.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
