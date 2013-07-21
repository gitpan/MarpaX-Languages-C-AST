use strict;
use warnings FATAL => 'all';

package MarpaX::Languages::C::AST::Scope;
use MarpaX::Languages::C::AST::Util qw/whoami/;

# ABSTRACT: Scope management when translating a C source to an AST

use Storable qw/dclone/;
use Log::Any qw/$log/;
use Carp qw/croak/;

our $VERSION = '0.11'; # VERSION


sub new {
  my ($class) = @_;

  my $self  = {
      _typedefPerScope => [ {} ],
      _enumAnyScope => {},
      _delay => 0,
      _enterScopeCallback => [],
      _exitScopeCallback => [],
  };
  bless($self, $class);

  return $self;
}


sub parseEnterScope {
  my ($self) = @_;

  # $self->condExitScope();

  my $scope = $self->parseScopeLevel;
  $log->debugf('[%s] Duplicating scope %d to %d', whoami(__PACKAGE__), $scope, $scope + 1);
  push(@{$self->{_typedefPerScope}}, dclone($self->{_typedefPerScope}->[$scope]));

  if (@{$self->{_enterScopeCallback}}) {
      my ($ref, @args) = @{$self->{_enterScopeCallback}};
      &$ref(@args);
  }

}


sub parseDelay {
  my $self = shift;
  if (@_) {
    my $scope = $self->parseScopeLevel;
    my $value = shift;
    $log->debugf('[%s] Setting delay flag to %d at scope %d', whoami(__PACKAGE__), $value, $scope);
    $self->{_delay} = $value;
  }
  return $self->{_delay};
}


sub parseScopeLevel {
  my ($self) = @_;

  return $#{$self->{_typedefPerScope}};
}


sub parseEnterScopeCallback {
  my ($self, $ref, @args) = @_;

  $self->{_enterScopeCallback} = [ $ref, @args ];
}


sub parseExitScopeCallback {
  my ($self, $ref, @args) = @_;

  $self->{_exitScopeCallback} = [ $ref, @args ];
}


sub parseExitScope {
  my ($self, $now) = @_;
  $now //= 0;

  if ($now) {
    $self->doExitScope();
  } else {
    $self->parseDelay(1);
  }
}


sub parseReenterScope {
  my ($self) = @_;

    my $scope = $self->parseScopeLevel;
  $log->debugf('[%s] Reenter scope at scope %d', whoami(__PACKAGE__), $scope);
  $self->parseDelay(0);

}


sub condExitScope {
  my ($self) = @_;

  if ($self->parseDelay) {
    $self->doExitScope();
  }
}


sub doExitScope {
  my ($self) = @_;

  my $scope = $self->parseScopeLevel;
  $log->debugf('[%s] Removing scope %d', whoami(__PACKAGE__), $scope);
  pop(@{$self->{_typedefPerScope}});

  if (@{$self->{_exitScopeCallback}}) {
      my ($ref, @args) = @{$self->{_exitScopeCallback}};
      &$ref(@args);
  }
  $self->parseDelay(0);
}


sub parseEnterTypedef {
  my ($self, $token) = @_;

  my $scope = $self->parseScopeLevel;
  $self->{_typedefPerScope}->[$scope]->{$token} = 1;

  $log->debugf('[%s] "%s" typedef entered at scope %d', whoami(__PACKAGE__), $token, $scope);
}


sub parseEnterEnum {
  my ($self, $token) = @_;

  $self->{_enumAnyScope}->{$token} = 1;
  my $scope = $self->parseScopeLevel;
  $log->debugf('[%s] "%s" enum entered at scope %d', whoami(__PACKAGE__), $token, $scope);
  #
  # Enum wins from now on and forever
  #
  foreach (0..$#{$self->{_typedefPerScope}}) {
      $self->parseObscureTypedef($token, $_);
  }
}


sub parseObscureTypedef {
  my ($self, $token, $scope) = @_;

  $scope //= $self->parseScopeLevel;
  $self->{_typedefPerScope}->[$scope]->{$token} = 0;

  $log->debugf('[%s] "%s" eventual typedef obscured at scope %d', whoami(__PACKAGE__), $token, $scope);
}


sub parseIsTypedef {
  my ($self, $token) = @_;

  my $scope = $self->parseScopeLevel;
  my $rc = (exists($self->{_typedefPerScope}->[$scope]->{$token}) && $self->{_typedefPerScope}->[$scope]->{$token}) ? 1 : 0;

  $log->debugf('[%s] "%s" at scope %d is a typedef? %s', whoami(__PACKAGE__), $token, $scope, $rc ? 'yes' : 'no');

  return($rc);
}


sub parseIsEnum {
  my ($self, $token) = @_;

  my $rc = (exists($self->{_enumAnyScope}->{$token}) && $self->{_enumAnyScope}->{$token}) ? 1 : 0;

  my $scope = $self->parseScopeLevel;
  $log->debugf('[%s] "%s" is an enum at scope %d? %s', whoami(__PACKAGE__), $token, $scope, $rc ? 'yes' : 'no');

  return($rc);
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

MarpaX::Languages::C::AST::Scope - Scope management when translating a C source to an AST

=head1 VERSION

version 0.11

=head1 SYNOPSIS

    use strict;
    use warnings FATAL => 'all';
    use MarpaX::Languages::C::AST::Scope;

    my $cAstScopeObject = MarpaX::Languages::C::AST::Scope->new();
    $cAstScopeObject->parseEnterScope();
    $cAstScopeObject->parseEnterTypedef("myTypedef");
    $cAstScopeObject->parseEnterEnum("myEnum");
    $cAstScopeObject->parseObscureTypedef("myVariable");
    foreach (qw/myTypedef myEnum myVariable/) {
      if ($cAstScopeObject->parseIsTypedef($_)) {
        print "\"$_\" is a typedef\n";
      } elsif ($cAstScopeObject->parseIsEnum($_)) {
        print "\"$_\" is an enum\n";
      }
    }
    $cAstScopeObject->parseExitScope();

=head1 DESCRIPTION

This modules manages the scopes when translation a C source into an AST tree. This module started after reading the article:

I<Resolving Typedefs in a Multipass C Compiler> from I<Journal of C Languages Translation>, Volume 2, Number 4, written by W.M. McKeeman. A online version may be accessed at L<http://www.cs.dartmouth.edu/~mckeeman/references/JCLT/ResolvingTypedefsInAMultipassCCompiler.pdf>.

Please note that this module is logging via Log::Any.

=head1 SUBROUTINES/METHODS

=head2 new

Instance a new object. Takes no parameter.

=head2 parseEnterScope($self)

Say we enter a scope.

=head2 parseDelay($self, [$value])

Returns/Set current delay flag.

=head2 parseScopeLevel($self)

Returns current scope level, starting at number 0.

=head2 parseEnterScopeCallback($self, $ref, @args)

Callback method when entering a scope.

=head2 parseExitScopeCallback($self, $ref, @args)

Callback method when leaving a scope (not the delayed operation, the real leave).

=head2 parseExitScope($self, [$now])

Say we want to leave current scope. The operation is delayed unless $now flag is true.

=head2 parseReenterScope($self)

Reenter previous scope.

=head2 condExitScope($self)

Leave current scope if delay flag is set and not yet done.

=head2 doExitScope($self)

Leave current scope.

=head2 parseEnterTypedef($self, $token)

Declare a new typedef with name $token, that will be visible until current scope is left.

=head2 parseEnterEnum($self, $token)

Declare a new enum with name $token, that will be visible at any scope from now on.

=head2 parseObscureTypedef($self, $token)

Obscures a typedef named $token.

=head2 parseIsTypedef($self, $token)

Return a true value if $token is a typedef.

=head2 parseIsEnum($self, $token)

Return a true value if $token is an enum.

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
