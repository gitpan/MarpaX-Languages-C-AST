use strict;
use warnings FATAL => 'all';

package MarpaX::Languages::C::AST::Impl;

# ABSTRACT: Implementation of Marpa's interface

# use MarpaX::Languages::C::AST::Util qw/traceAndUnpack/;
use Marpa::R2 2.064000;
use Carp qw/croak/;
use MarpaX::Languages::C::AST::Impl::Logger;

our $VERSION = '0.15'; # VERSION

our $MARPA_TRACE_FILE_HANDLE;
our $MARPA_TRACE_BUFFER;

sub BEGIN {
    #
    ## We do not want Marpa to pollute STDERR
    #
    ## Autovivify a new file handle
    #
    open($MARPA_TRACE_FILE_HANDLE, '>', \$MARPA_TRACE_BUFFER);
    if (! defined($MARPA_TRACE_FILE_HANDLE)) {
      croak "Cannot create temporary file handle to tie Marpa logging, $!\n";
    } else {
      if (! tie ${$MARPA_TRACE_FILE_HANDLE}, 'MarpaX::Languages::C::AST::Impl::Logger') {
        croak "Cannot tie $MARPA_TRACE_FILE_HANDLE, $!\n";
        if (! close($MARPA_TRACE_FILE_HANDLE)) {
          croak "Cannot close temporary file handle, $!\n";
        }
        $MARPA_TRACE_FILE_HANDLE = undef;
      }
    }
}


sub new {

  my ($class, $grammarOptionsHashp, $recceOptionsHashp) = @_;

  my $self  = {
      _cacheRule => {}
  };
  $self->{grammar} = Marpa::R2::Scanless::G->new($grammarOptionsHashp);
  if (defined($recceOptionsHashp)) {
      $recceOptionsHashp->{grammar} = $self->{grammar};
  } else {
      $recceOptionsHashp = {grammar => $self->{grammar}};
  }
  $recceOptionsHashp->{trace_terminals} = $ENV{MARPA_TRACE_TERMINALS} || $ENV{MARPA_TRACE} || 0;
  $recceOptionsHashp->{trace_values} = $ENV{MARPA_TRACE_VALUES} || $ENV{MARPA_TRACE} || 0;
  $recceOptionsHashp->{trace_file_handle} = $MARPA_TRACE_FILE_HANDLE;
  $self->{recce} = Marpa::R2::Scanless::R->new($recceOptionsHashp);
  bless($self, $class);

  return $self;
}


sub value {
  my $self = shift;

  return $self->{recce}->value(@_);
}


sub read {
  my $self = shift;

  return $self->{recce}->read(@_);
}


sub resume {
  my $self = shift;

  return $self->{recce}->resume(@_);
}


sub last_completed {
  my $self = shift;

  return $self->{recce}->last_completed(@_);
}


sub last_completed_range {
  my $self = shift;

  return $self->{recce}->last_completed_range(@_);
}


sub range_to_string {
  my $self = shift;

  return $self->{recce}->range_to_string(@_);
}


sub event {
  my $self = shift;

  return $self->{recce}->event(@_);
}


sub pause_lexeme {
  my $self = shift;

  return $self->{recce}->pause_lexeme(@_);
}


sub pause_span {
  my $self = shift;

  return $self->{recce}->pause_span(@_);
}


sub literal {
  my $self = shift;

  return $self->{recce}->literal(@_);
}


sub line_column {
  my $self = shift;

  return $self->{recce}->line_column(@_);
}


sub substring {
  my $self = shift;

  return $self->{recce}->substring(@_);
}


sub lexeme_read {
  my $self = shift;

  return $self->{recce}->lexeme_read(@_);
}


sub current_g1_location {
  my $self = shift;

  return $self->{recce}->current_g1_location(@_);
}


sub g1_location_to_span {
  my $self = shift;

  return $self->{recce}->g1_location_to_span(@_);
}


sub terminals_expected {
  my $self = shift;

  return $self->{recce}->terminals_expected(@_);
}


sub show_progress {
  my $self = shift;

  return $self->{recce}->show_progress(@_);
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

MarpaX::Languages::C::AST::Impl - Implementation of Marpa's interface

=head1 VERSION

version 0.15

=head1 SYNOPSIS

    use strict;
    use warnings FATAL => 'all';
    use MarpaX::Languages::C::AST::Impl;

    my $marpaImpl = MarpaX::Languages::C::AST::Impl->new();

=head1 DESCRIPTION

This modules implements all needed Marpa calls using its Scanless interface. Please be aware that logging is done via Log::Any.

=head1 SUBROUTINES/METHODS

=head2 new($class, $grammarOptionsHashp, $recceOptionsHashp)

Instantiate a new object. Takes as parameter two references to hashes: the grammar options, the recognizer options. In the recognizer, there is a grammar internal option that will be forced to the grammar object. If the environment variable MARPA_TRACE_TERMINALS is set to a true value, then internal Marpa trace on terminals is activated. If the environment MARPA_TRACE_VALUES is set to a true value, then internal Marpa trace on values is activated. If the environment variable MARPA_TRACE is set to a true value, then both terminals and values internal Marpa traces are activated.

=head2 value($self)

Returns Marpa's recognizer's value.

=head2 read($self, $inputp)

Returns Marpa's recognizer's read. Argument is a reference to input.

=head2 resume($self)

Returns Marpa's recognizer's resume.

=head2 last_completed($self, $symbol)

Returns Marpa's recognizer's last_completed for symbol $symbol.

=head2 last_completed_range($self, $symbol)

Returns Marpa's recognizer's last_completed_range for symbol $symbol.

=head2 range_to_string($self, $start, $end)

Returns Marpa's recognizer's range_to_string for a start value of $start and an end value of $end.

=head2 event($self, $eventNumber)

Returns Marpa's recognizer's event for event number $eventNumber.

=head2 pause_lexeme($self)

Returns Marpa's recognizer's pause_lexeme.

=head2 pause_span($self)

Returns Marpa's recognizer's pause_span.

=head2 literal($self, $start, $length)

Returns Marpa's recognizer's literal.

=head2 line_column($self, $start)

Returns Marpa's recognizer's line_column at eventual $start location in the input stream. Default location is current location.

=head2 substring($self, $start, $length)

Returns Marpa's recognizer's substring corresponding to g1 span ($start, $length).

=head2 lexeme_read($self, $lexeme, $start, $length, $value)

Returns Marpa's recognizer's lexeme_read for lexeme $lexeme, at start position $start, length $length and value $value.

=head2 current_g1_location($self)

Returns Marpa's recognizer's current_g1_location.

=head2 g1_location_to_span($self, $g1)

Returns Marpa's recognizer's g1_location_to_span for a g1 location $g1.

=head2 terminals_expected($self)

Returns Marpa's recognizer's terminals_expected.

=head2 show_progress($self)

Returns Marpa's recognizer's show_progress.

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
