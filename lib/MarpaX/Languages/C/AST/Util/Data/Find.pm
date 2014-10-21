use strict;
use warnings FATAL => 'all';

package MarpaX::Languages::C::AST::Util::Data::Find;

use Scalar::Util qw/blessed/;
use Carp qw/croak/;

# ABSTRACT: Find data in C AST

our $VERSION = '0.26'; # VERSION


sub new {
  my ($class, %options) = @_;

  my $self  = {
    _wanted => $options{wanted} || sub {return 1;},
    _wantedArgs => $options{wantedArgs} || [],
    _callback => $options{callback} || sub {},
    _callbackArgs => $options{callbackArgs} || []
  };

  bless $self, $class;

  return $self;
}


sub process {
    my ($self, $value) = @_;

    my @worklist = ($value);
    my $rc = 0;
    do {
	my $obj = shift @worklist;
	if ($self->{_wanted}(@{$self->{_wantedArgs}}, $obj)) {
	    $rc = 1;
	    $self->{_callback}(@{$self->{_callbackArgs}}, $obj);
	}
	my $ref_type = ref $obj;
	if (blessed($obj) || $ref_type eq 'ARRAY') {
	    unshift(@worklist, @{$obj});
	} else {
	    croak "Unsupported object type $ref_type\n" if $ref_type;
	}
  } while (@worklist);

  return $rc;
}


1;

__END__

=pod

=encoding utf-8

=head1 NAME

MarpaX::Languages::C::AST::Util::Data::Find - Find data in C AST

=head1 VERSION

version 0.26

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

=head2 new($class, %options)

Instance a new object. Takes as optional argument a hash that may contain the following key/values:

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

=head2 process($self, $value)

Process search on the object $value. Returns a true value is something wanted was found.

=head1 SEE ALSO

 L<Data::Find>, L<Marpa::R2>

=head1 AUTHOR

Jean-Damien Durand <jeandamiendurand@free.fr>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Jean-Damien Durand.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
