use strict;
use warnings FATAL => 'all';

package MarpaX::Languages::C::AST::Callback;
use MarpaX::Languages::C::AST::Util qw/whoami/;
use MarpaX::Languages::C::AST::Callback::Method;
use Storable qw/dclone/;

use Class::Struct
  #
  # External attributes
  #
  log_prefix              => '$',   # Prepended to every log
  hscratchpad             => '%',   # User working area
  ascratchpad             => '@',   # User working area
  sscratchpad             => '$',   # User working area
  #
  # Internal attributes
  #
  cb                      => '@', # List of methods.
  cb_unregistered         => '@', # List of unregistered methods, post-processed if done during fire()
  topic_fired             => '%', # Remember what are the eligible cb's topics.
  topic_fired_data        => '%', # Remember what are the eligible cb's topics data.
  topic_fired_persistence => '%', # Remember what are the eligible cb's topics persistence.
  topic_level             => '@', # Topic levels
  ncb                     => '$', # Number of methods.
  prioritized_cb          => '@', # Prioritized list of methods, for efficiency.
  prioritized_cb_tofire   => '@', # Remember what cb are eligible.
  prioritized_cb_fired    => '@', # Remember what cb were fired
  arguments               => '@', # List of arguments to the exec method.
  firing                  => '$'
  ;

# ABSTRACT: Simple but powerful callback generic framework that depend on nothing else but core modules.

use Carp qw/croak/;

our $VERSION = '0.13'; # TRIAL VERSION


sub _sort_by_option_priority_desc {
  return $b->option->priority <=> $a->option->priority;
}

sub _sort_by_numeric_desc {
  return $b <=> $a;
}

sub register {
  my ($self, $cb) = @_;

  if (ref($cb) ne 'MarpaX::Languages::C::AST::Callback::Method') {
    croak 'argument bust be a reference to a MarpaX::Languages::C::AST::Callback::Method object';
  }
  #
  # Sanitize self
  #
  if (! defined($self->log_prefix)) {
      $self->log_prefix('');
  }

  #
  # Sanitize cb
  #
  if (defined($cb->method) && ref($cb->method) ne 'ARRAY') {
    croak 'method must be an ARRAY ref';
  }
  if (defined($cb->method)) {
    if (! @{$cb->method}) {
      croak 'method is a reference to an empty array';
    }
    if (ref(($cb->method)->[0]) ne 'CODE' && (! ref($cb->method) && $cb->method eq 'auto')) {
      croak 'method must be an ARRAY ref starting with a CODE reference, or the string \'auto\'';
    }
  }
  if (! defined($cb->method_mode)) {
    $cb->method_mode('push');
  }
  if ($cb->method_mode ne 'push' && $cb->method_mode ne 'replace') {
    croak 'method_mode must be \'push\' or \'replace\'';
  }
  #
  # Sanitize $cb->option
  #
  if (! defined($cb->option)) {
    $cb->option(MarpaX::Languages::C::AST::Callback::Option->new());
  }
  my $option = $cb->option;
  foreach (@{$option->condition}) {
    if (! defined($_) || (! (ref($_) eq 'ARRAY')) || (! (ref($_->[0]) eq 'CODE' || (! ref($_->[0]) && $_->[0] eq 'auto')))) {
	croak 'A condition is not an ARRAY reference, that must start with a CODE reference or the "auto" keyword"';
    }
  }

  if (! defined($option->conditionMode)) {
    $option->conditionMode('and');
  }
  if (! grep {$option->conditionMode eq $_} qw/and or/) {
    croak 'condition mode must be "and" or "or"';
  }

  if (! defined($option->subscriptionMode)) {
    $option->subscriptionMode('required');
  }
  if (! grep {$option->subscriptionMode eq $_} qw/required optional/) {
    croak 'condition mode must be "and" or "or"';
  }

  if (! defined($option->topic_persistence)) {
    $option->topic_persistence('none');
  }
  if (! grep {$option->topic_persistence eq $_} qw/none any level/) {
    croak 'topic persistence mode must be "none", "any" or "level"';
  }

  if (! defined($option->priority)) {
    $option->priority(0);
  }
  my $priority = $option->priority;
  if (! ("$priority" =~ /^[+-]?\d+$/)) {
    croak 'priority must be a number';
  }

  $self->ncb(0) if (! defined($self->ncb));
  $self->cb($self->ncb, $cb);
  $self->ncb($self->ncb + 1);
  $self->prioritized_cb([sort _sort_by_option_priority_desc  @{$self->cb}]);

  #
  # We return the indice within Callback
  #
  return $self->ncb - 1;
}

sub _unregister {
    my $self = shift;

    foreach (sort _sort_by_numeric_desc @_) {

	my $cb = $self->cb($_);
	croak "Unknown callback indice $_" if (! defined($cb));

	splice(@{$self->cb}, $_, 1);
	$self->ncb($self->ncb - 1);
	$self->prioritized_cb([sort _sort_by_option_priority_desc @{$self->cb}]);

    }

}

sub unregister {
  my $self = shift;

  my $firing = $self->firing() || 0;
  if (! $firing) {
      return $self->_unregister(@_);
  } else {
      push(@{$self->cb_unregistered}, @_);
  }
}

sub exec {
  my $self = shift;
  #
  # Remember our arguments, if the callback need it
  #
  $self->arguments([@_]);
  #
  # Do an inventory of eligible callbacks and topics
  #
  $self->_inventory_fire();
  #
  # Fire everything that is eligible
  #
  $self->_fire();
  #
  # And post-process eventual unregistrations
  #
  $self->_unregister(@{$self->cb_unregistered});
  $self->cb_unregistered([]);
}

sub _inventory_condition_tofire {
  my $self = shift;
  my $nbConditionOK = 0;
  my $nbNewTopics = 0;
  my $ncb = $self->ncb;
  foreach (my $i = 0; $i < $ncb; $i++) {
    my $cb = $self->prioritized_cb($i);
    my $option = $cb->option;
    my $conditionMode = $option->conditionMode;

    my @condition = ();
    foreach my $condition (@{$option->condition}) {
	my ($coderef, @arguments) = @{$condition};
	if (ref($coderef) eq 'CODE') {
	    push(@condition, &$coderef($cb, $self, $self->arguments(), @arguments) ? 1 :0);
	} elsif (defined($cb->description)) {
	    push(@condition, (grep {$_ eq $cb->description} @{$self->arguments()}) ? 1 :0);
	}
    }
    #
    ## Apply conditionMethod. If none, then the callback will never be
    ## executed. Only the subscription methods can make it eligible.
    #
    my $condition = 0;
    if (@condition) {
      $condition = shift(@condition);
      if ($conditionMode eq 'and') {
        foreach (@condition) {
          $condition &&= $_;
        }
      } elsif ($conditionMode eq 'or') {
        foreach (@condition) {
          $condition ||= $_;
        }
      }
    }
    if ($condition) {
      $self->prioritized_cb_tofire($i, 1);
      #
      # Initialize the associated topics if needed
      #
      foreach my $topic (keys %{$option->topic}) {
        next if (! defined($option->topic($topic)));
        next if (! $option->topic($topic));
        if (! defined($self->topic_fired($topic))) {
          $self->topic_fired($topic, 1);
          $self->topic_fired_persistence($topic, $option->topic_persistence);
          if (! defined($self->topic_fired_data($topic))) {
            $self->topic_fired_data($topic, []);
	    ++$nbNewTopics;
          }
        }
      }
      ++$nbConditionOK;
    } else {
      if (@condition) {
        $self->prioritized_cb_tofire($i, -1);
      }
    }
  }

  return $nbNewTopics;
}

sub _fire {
  my $self = shift;

  $self->firing(1);

  #
  # Make sure the raised topic data always exist.
  # It is very important that this routine is safe v.s. any on-the-fly registration
  # or unregistration. Thus all dependencies are expressed in the beginning.
  # This mean that nay on-the-flu registration/unregistration will happend at NEXT round.
  #
  my $ncb = $self->ncb;
  my @prioritized_cb_tofire = @{$self->prioritized_cb_tofire};
  my @prioritized_cb_fired = @{$self->prioritized_cb_fired};
  my @prioritized_cb = @{$self->prioritized_cb};
  foreach (my $i = 0; $i < $ncb; $i++) {
    if ($prioritized_cb_tofire[$i] <= 0) {
      # -1: Condition KO
      # -2: Condition NA and Subscription NA
      # -3: Subscription KO
      next;
    }
    my $cb = $prioritized_cb[$i];
    if ($prioritized_cb_fired[$i]) {
      # already fired
      next;
    }
    #
    # Fire the callback (if there is a method)
    #
    $self->prioritized_cb_fired($i, 1);
    if (defined($cb->method)) {
      my @rc;
      if (ref($cb->method) eq 'ARRAY') {
        my ($method, @arguments) = @{$cb->method};
	if (ref($method) eq 'CODE') {
	    @rc = &$method($cb, $self, $self->arguments(), @arguments);
	} else {
	    @rc = $self->topic_fired_data($cb->description) || [];
	}
      }
      #
      # Push result to data attached to every topic of this callback
      #
      my $option = $cb->option;
      if (! $cb->method_void) {
        foreach my $topic (keys %{$option->topic}) {
          next if (! defined($option->topic($topic)));
          next if ($option->topic($topic) != 1);
          my $topic_fired_data = $self->topic_fired_data($topic) || [];
          if (ref($cb->method) eq 'ARRAY') {
            if ($cb->method_mode eq 'push') {
              push(@{$topic_fired_data}, @rc);
            } else {
              @{$topic_fired_data} = @rc;
            }
          } else {
            if ($cb->method_mode eq 'push') {
              push(@{$topic_fired_data}, @rc);
            } else {
              @{$topic_fired_data} = @rc;
            }
          }
          $self->topic_fired_data($topic, $topic_fired_data);
        }
      }
    }
  }

  $self->firing(0);
}

sub topic_level_fired_data {
    my $self = shift;
    my $topic = shift;
    my $level = shift;

    $level //= 0;

    #
    # Level MUST be 0 for current or a negative number
    #
    $level = int($level);
    if ($level > 0) {
	croak 'int(level) must be 0 or a negative number';
    }
    if ($level == 0) {
	if (@_) {
	    $self->topic_fired_data($topic, shift);
	}
        return $self->topic_fired_data($topic);
    } else {
	my ($old_topic_fired, $old_topic_persistence, $old_topic_data) = @{$self->topic_level($level)};
	if (@_) {
	    $old_topic_data->{$topic} = shift;
	}
        return $old_topic_data->{$topic};
    }
}

sub _inventory_initialize_topic {
  my $self = shift;
  #
  # For topics, we want to keep those that have a persistence of 'level' or 'any'
  #
  my $keep_topic_fired = {};
  my $keep_topic_fired_persistence = {};
  my $keep_topic_fired_data = {};
  foreach my $topic (keys %{$self->topic_fired}) {
    my $persistence = $self->topic_fired_persistence($topic);
    if (grep {$_ eq $persistence} qw/any level/) {
      $keep_topic_fired->{$topic} = $self->topic_fired($topic);
      $keep_topic_fired_persistence->{$topic} = $self->topic_fired_persistence($topic);
      $keep_topic_fired_data->{$topic} = $self->topic_fired_data($topic);
    }
  }
  $self->topic_fired($keep_topic_fired);
  $self->topic_fired_persistence($keep_topic_fired_persistence);
  $self->topic_fired_data($keep_topic_fired_data);
}

sub _inventory_initialize_tofire {
  my $self = shift;
  foreach (my $i = 0; $i < $self->ncb; $i++) {
      $self->prioritized_cb_tofire($i, 0);
  }
}

sub _inventory_initialize_fired {
  my $self = shift;
  foreach (my $i = 0; $i < $self->ncb; $i++) {
      $self->prioritized_cb_fired($i, 0);
  }
}

sub _inventory_fire {
  my $self = shift;

  #
  # Inventory
  #
  $self->_inventory_initialize_topic();
  $self->_inventory();
}

sub _inventory {
  my $self = shift;
  my $nbTopicsCreated = 0;
  do {
      $self->_inventory_initialize_tofire();
      $self->_inventory_initialize_fired();
      $nbTopicsCreated += $self->_inventory_condition_tofire();
      $nbTopicsCreated += $self->_inventory_subscription_tofire();
      if ($nbTopicsCreated > 0) {
	  $self->_fire();
	  $nbTopicsCreated = 0;
      }
  } while ($nbTopicsCreated > 0);
}

sub _inventory_subscription_tofire {
  my $self = shift;
  #
  # This is a loop because when a new callback is eligible there might be new topics
  #
  my $nbNewTopics = 0;
  my $nbSubscriptionOK = 0;
  my $ncb = $self->ncb;
  foreach (my $i = 0; $i < $ncb; $i++) {
    my $cb = $self->prioritized_cb($i);
    my $option = $cb->option;
    #
    # Here the values can be:
    # -1: condition KO
    #  0: no condition applied
    #  1: condition OK
    next if ($self->prioritized_cb_tofire($i) < 0);

    my %subscribed = ();
    my $nbSubscription = 0;
    foreach my $subscription (keys %{$option->subscription}) {
      next if (! defined($option->subscription($subscription)));
      next if (! $option->subscription($subscription));
      ++$nbSubscription;
      if (ref($subscription) eq 'Regexp') {
        foreach (keys %{$self->topic_fired}) {
          if ($_ =~ $subscription) {
            $subscribed{$_} = 1;
          }
        }
      } else {
        foreach (keys %{$self->topic_fired}) {
          if ("$_" eq "$subscription") {
            $subscribed{$_} = 1;
          }
        }
      }
    }

    if ($self->prioritized_cb_tofire($i) == 0 && ! keys %subscribed) {
      #
      # no condition was setted and no subscription is raised
      #
      $self->prioritized_cb_tofire($i, -2);
      next;
    }

    if ($nbSubscription > 0 && $option->subscriptionMode eq 'required' && $nbSubscription != keys %subscribed) {
      #
      # There are active subscription not raised, and subscriptionMode is 'required'
      #
      $self->prioritized_cb_tofire($i, -3);
      next;
    }

    if ($self->prioritized_cb_tofire($i) == 0) {
      #
      # There must have been topic subscription being raised
      #
      $self->prioritized_cb_tofire($i, 1);
      ++$nbSubscriptionOK;
    }

    foreach my $topic (keys %{$option->topic}) {
      next if (! defined($option->topic($topic)));
      next if (! $option->topic($topic));
      if (! defined($self->topic_fired($topic))) {
        $self->topic_fired($topic, 1);
        $self->topic_fired_persistence($topic, $option->topic_persistence);
        $self->topic_fired_data($topic, []);
        ++$nbNewTopics;
      }
    }
  }

  return $nbNewTopics;
}

sub currentTopicLevel {
  my $self = shift;

  return scalar(@{$self->topic_level});
}

sub pushTopicLevel {
  my $self = shift;

  #
  # We push current topics and their persistence into the topic_level
  #
  push(@{$self->topic_level}, [ dclone($self->topic_fired), dclone($self->topic_fired_persistence), $self->topic_fired_data ]);
  #
  # We remove from current topics those that do not have the 'any' persistence
  #
  my $new_topic_fired = {};
  my $new_topic_fired_persistence = {};
  my $new_topic_fired_data = {};
  foreach my $topic (keys %{$self->topic_fired}) {
    my $persistence = $self->topic_fired_persistence($topic);
    if (grep {$_ eq $persistence} qw/any/) {
      $new_topic_fired->{$topic} = $self->topic_fired($topic);
      $new_topic_fired_persistence->{$topic} = $self->topic_fired_persistence($topic);
      $new_topic_fired_data->{$topic} = $self->topic_fired_data($topic);
    }
  }
  $self->topic_fired($new_topic_fired);
  $self->topic_fired_persistence($new_topic_fired_persistence);
  $self->topic_fired_data($new_topic_fired_data);

}

sub popTopicLevel {
  my $self = shift;

  #
  # We pop current topics and their persistence from the topic_level
  #
  my ($old_topic_fired, $old_topic_persistence, $old_topic_data) = @{$self->topic_level(-1)};
  pop(@{$self->topic_level});
  $self->topic_fired($old_topic_fired);
  $self->topic_fired_persistence($old_topic_persistence);
  $self->topic_fired_data($old_topic_data);

}

sub reset_topic_fired_data {
    my ($self, $topic, $value, $level) = @_;

    $value //= [];
    $level //= 0;

    if (ref($value) ne 'ARRAY') {
      croak 'Topic fired data must be an ARRAY reference';
    }

    #
    # Level MUST be 0 or a negative number
    # It is okay if $value is undef
    #
    $level = int($level);
    if ($level > 0) {
	croak 'int(level) must be 0 or a negative number';
    }
    if ($level == 0) {
	$self->topic_fired_data($topic, $value);
    } else {
	my ($old_topic_fired, $old_topic_persistence, $old_topic_data) = @{$self->topic_level($level)};
	$old_topic_data->{$topic} = $value;
    }

}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

MarpaX::Languages::C::AST::Callback - Simple but powerful callback generic framework that depend on nothing else but core modules.

=head1 VERSION

version 0.13

=head1 DESCRIPTION

    This modules is a simple callback framework.

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
