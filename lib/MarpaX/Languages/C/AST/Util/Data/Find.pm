use strict;
use warnings FATAL => 'all';

package MarpaX::Languages::C::AST::Util::Data::Find;

use Scalar::Util qw/blessed/;
use Carp qw/croak/;

# ABSTRACT: Find data in C AST

our $VERSION = '0.13'; # TRIAL VERSION


sub new {
  my ($class, %options) = @_;

  my $self  = {
    _wanted => $options{wanted} || sub {return 1;},
    _wantedArgs => $options{wantedArgs} || [],
    _callback => $options{callback} || [ sub {} ],
    _callbackArgs => $options{callbackArgs} || []
  };

  bless $self, $class;

  return $self;
}

sub _iter {
    #
    # perl will "think" there is a deep recursion
    #
    no warnings 'recursion';
    my ($self, $level, $obj) = @_;

    ++$level;
    if ($self->{_wanted}(@{$self->{_wantedArgs}}, $obj)) {
	$self->{_callback}(@{$self->{_callbackArgs}}, $obj);
    }

    if (blessed($obj)) {
	#
	# We are always blessing an array
	#
	foreach (@{$obj}) {
	    $self->_iter($level, $_);
	}
    } elsif (ref($obj) eq 'ARRAY') {
	foreach (@{$obj}) {
	    $self->_iter($level, $_);
	}
    } elsif (ref($obj)) {
	croak "Unsupported type " . ref($obj) . "\n";
    }
}


sub process {
    my ($self, $value) = @_;

    $self->_iter(-1, $value);
}


1;

__END__

=pod

=encoding utf-8

=head1 NAME

MarpaX::Languages::C::AST::Util::Data::Find - Find data in C AST

=head1 VERSION

version 0.13

=head1 SYNOPSIS

    use strict;
    use warnings FATAL => 'all';
    use MarpaX::Languages::C::AST::Util::Data::Find;

    my $data = bless [], 'C::AST::Something';

    MarpaX::Languages::C::AST::Util::Data::Find->new(
	wanted => sub { my $o = shift;
			my $class = blessed($o) || '';
			return ($class eq 'C::AST::directDeclaratorIdentifier');
	},
	callback => sub { my ($datap, $o) = @_;
			  #
			  # This object has matched.
			  #
	},
	callbackArgs => [ $data ],
	)->process($data);

=head1 DESCRIPTION

This modules is a minimalist Data::Find designed for the parse tree values of Marpa on a C source file.

=head1 SUBROUTINES/METHODS

=head2 new()

Instance a new object. Takes as optional arguments:

=over

=item wanted

Match callback (CODE ref).

=item wantedArgs

Match callback arguments (ARRAY ref). The matched callback is called like: &$wanted(@{$wantedArgs}, $object). Any true value means that $object has matched and will be a candidate to the processing callback.

=item callback

Process callback (CODE ref).

=item callbackArgs

Process callback arguments (ARRAY ref). The process callback is called like: &$callback(@{$callbackArgs}, $object) on every object that matched.

=back

=head2 new()

Instance a new object. Takes a argument a parse tree value returned by Marpa.

=head1 SEE ALSO

 L<Data::Find>, L<Marpa::R2>

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
