use strict;
use warnings FATAL => 'all';

package MarpaX::Languages::C::AST::Scope;
BEGIN {
  $MarpaX::Languages::C::AST::Scope::AUTHORITY = 'cpan:JDDPAUSE';
}

# ABSTRACT: Scope management when translating a C source to an AST

use Storable qw/dclone/;
use Log::Any qw/$log/;

our $VERSION = '0.06'; # VERSION


sub new {
  my ($class) = @_;

  my $self  = {
               delayedExitScope => 0,
               typedefPerScope => [ {} ],
               enumAnyScope => {}
              };
  bless($self, $class);

  return $self;
}


sub parseEnterScope {
  my ($self, $context) = @_;

  $self->_doDelayedExitScope();

  my $scope = $#{$self->{typedefPerScope}};
  push(@{$self->{typedefPerScope}}, dclone($self->{typedefPerScope}->[$scope]));

  $log->debugf('[%s] Duplicated scope %d to %d', $context, $scope, $scope + 1);
}


sub parseExitScope {
  my ($self, $context) = @_;

  my $scope = $#{$self->{typedefPerScope}};
  $self->{delayedExitScope} = 1;

  $log->debugf('[%s] Setting delay flag on scope %d', $context, $scope);
}


sub parseReenterScope {
  my ($self, $context) = @_;

  my $scope = $#{$self->{typedefPerScope}};
  $self->{delayedExitScope} = 0;

  $log->debugf('[%s] Resetting delay flag on scope %d', $context, $scope);
}


sub parseEnterTypedef {
  my ($self, $context, $token) = @_;

  $self->_doDelayedExitScope();

  my $scope = $#{$self->{typedefPerScope}};
  $self->{typedefPerScope}->[$scope]->{$token} = 1;

  $log->debugf('[%s] "%s" typedef entered at scope %d', $context, $token, $scope);
}


sub parseEnterEnum {
  my ($self, $context, $token) = @_;

  $self->_doDelayedExitScope($context);

  $self->{enumAnyScope}->{$token} = 1;

  $log->debugf('[%s] "%s" enum entered', $context, $token);
}


sub parseObscureTypedef {
  my ($self, $context, $token) = @_;

  $self->_doDelayedExitScope($context);

  my $scope = $#{$self->{typedefPerScope}};
  $self->{typedefPerScope}->[$scope]->{$token} = 0;

  $log->debugf('[%s] "%s" eventual typedef obscured at scope %d', $context, $token, $scope);
}


sub parseIsTypedef {
  my ($self, $context, $token) = @_;

  $self->_doDelayedExitScope($context);

  my $scope = $#{$self->{typedefPerScope}};
  my $rc = (exists($self->{typedefPerScope}->[$scope]->{$token}) && $self->{typedefPerScope}->[$scope]->{$token}) ? 1 : 0;

  $log->debugf('[%s] "%s" at scope %d is a typedef? %s', $context, $token, $scope, $rc ? 'yes' : 'no');

  return($rc);
}


sub parseIsEnum {
  my ($self, $context, $token) = @_;

  $self->_doDelayedExitScope($context);

  my $rc = (exists($self->{enumAnyScope}->{$token}) && $self->{enumAnyScope}->{$token}) ? 1 : 0;

  $log->debugf('[%s] "%s" is an enum? %s', $context, $token, $rc ? 'yes' : 'no');

  return($rc);
}

#
# INTERNAL METHODS
#
sub _doDelayedExitScope {
  my ($self, $context) = @_;

  if ($self->{delayedExitScope}) {
    my $scope = $#{$self->{typedefPerScope}};
    pop(@{$self->{typedefPerScope}});
    $self->{delayedExitScope} = 0;

    $log->debugf('[%s] Removed scope %d and resetted delay flag', $context, $scope);
  }
}

1;

__END__

=pod

=head1 NAME

MarpaX::Languages::C::AST::Scope - Scope management when translating a C source to an AST

=head1 VERSION

version 0.06

=head1 SYNOPSIS

    use strict;
    use warnings FATAL => 'all';
    use MarpaX::Languages::C::AST::Scope;

    my $context = 'A string';
    my $cAstScopeObject = MarpaX::Languages::C::AST::Scope->new();
    $cAstScopeObject->parseEnterScope($context);
    $cAstScopeObject->parseReenterScope($context);
    $cAstScopeObject->parseEnterTypedef($context, "myTypedef");
    $cAstScopeObject->parseEnterEnum($context, "myEnum");
    $cAstScopeObject->parseObscureTypedef($context, "myVariable");
    foreach (qw/myTypedef myEnum myVariable/) {
      if ($cAstScopeObject->parseIsTypedef($context, $_)) {
        print "\"$_\" is a typedef\n";
      } elsif ($cAstScopeObject->parseIsEnum($context, $_)) {
        print "\"$_\" is an enum\n";
      }
    }
    $cAstScopeObject->parseExitScope($context);

=head1 DESCRIPTION

This modules manages the scopes when translation a C source into an AST tree. This module is an implementation of the article:

I<Resolving Typedefs in a Multipass C Compiler> from I<Journal of C Languages Translation>, Volume 2, Number 4, writen by W.M. McKeeman. A online version may be accessed at L<http://www.cs.dartmouth.edu/~mckeeman/references/JCLT/ResolvingTypedefsInAMultipassCCompiler.pdf>. Please note that this module is logging via Log::Any.

=head1 SUBROUTINES/METHODS

=head2 new

Instance a new object. Takes no parameter.

=head2 parseEnterScope($self, $context)

Say we enter a new scope. $context is a free string used for logging.

=head2 parseExitScope($self, $context)

Say we leave current scope. $context is a free string used for logging.

=head2 parseReenterScope($self, $context)

Say we re-enter last scope. $context is a free string used for logging.

=head2 parseEnterTypedef($self, $context, $token)

Declare a new typedef with name $token, that will be visible until current scope is left. $context is a free string used for logging.

=head2 parseEnterEnum($self, $context, $token)

Declare a new enum with name $token, that will be visible at any scope from now on. $context is a free string used for logging.

=head2 parseObscureTypedef($self, $context, $token)

Obscures a typedef named $token. $context is a free string used for logging.

=head2 parseIsTypedef($self, $context, $token)

Return a true value if $token is a typedef. $context is a free string used for logging.

=head2 parseIsEnum($self, $context, $token)

Return a true value if $token is an enum. $context is a free string used for logging.

=head1 AUTHOR

Jean-Damien Durand <jeandamiendurand@free.fr>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Jean-Damien Durand.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
