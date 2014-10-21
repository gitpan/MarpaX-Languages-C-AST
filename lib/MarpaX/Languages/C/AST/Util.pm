use strict;
use warnings FATAL => 'all';

package MarpaX::Languages::C::AST::Util;

# ABSTRACT: C Translation to AST - Class method utilities

use Exporter 'import';
use Log::Any qw/$log/;
use Data::Dumper;
use Carp qw/croak/;

our $VERSION = '0.12'; # VERSION
# CONTRIBUTORS

our @EXPORT_OK = qw/whoami whowasi traceAndUnpack logCroak showLineAndCol lineAndCol lastCompleted/;
our %EXPORT_TAGS = ('all' => [ @EXPORT_OK ]);


sub _cutbase {
    my ($rc, $base) = @_;
    if (defined($base) && "$base" && index($rc, "${base}::") == $[) {
	substr($rc, $[, length($base) + 2, '');
    }
    return $rc;
}

sub whoami {
    return _cutbase((caller(1))[3], @_);
}


sub whowasi {
    return _cutbase((caller(2))[3], @_);
}


sub traceAndUnpack {
    my $nameOfArgumentsp = shift;

    my $whowasi = whowasi();
    my @string = ();
    my $min1 = scalar(@{$nameOfArgumentsp});
    my $min2 = scalar(@_);
    my $min = ($min1 < $min2) ? $min1 : $min2;
    my $rc = {};
    foreach (0..--$min) {
	my ($key, $value) = ($nameOfArgumentsp->[$_], $_[$_]);
	my $string = Data::Dumper->new([$value], [$key])->Indent(0)->Sortkeys(1)->Quotekeys(0)->Terse(0)->Dump();
	$rc->{$key} = $value;
	#
	# Remove the ';'
	#
	substr($string, -1, 1, '');
	push(@string, $string);
    }
    #
    # Skip MarpaX::Languages::C::AST::if any
    #
    $whowasi =~ s/^MarpaX::Languages::C::AST:://;
    $log->tracef('%s(%s)', $whowasi, join(', ', @string));
    return($rc);
}


sub logCroak {
    my ($fmt, @arg) = @_;

    my $msg = sprintf($fmt, @arg);
    $log->fatalf($msg);
    croak $msg;
}


sub showLineAndCol {
    my ($line, $col, $sourcep) = @_;

    my $pointer = ($col > 0 ? '-' x ($col-1) : '') . '^';
    my $content = (split("\n", ${$sourcep}))[$line-1];
    $content =~ s/\t/ /g;
    return "$content\n$pointer";
}


sub lineAndCol {
    my ($impl, $g1) = @_;

    $g1 //= $impl->current_g1_location();
    my ($start, $length) = $impl->g1_location_to_span($g1);
    my ($line, $column) = $impl->line_column($start);
    return [ $line, $column ];
}


sub lastCompleted {
    my ($impl, $symbol) = @_;
    return $impl->substring($impl->last_completed($symbol));
}


1;

__END__

=pod

=encoding utf-8

=head1 NAME

MarpaX::Languages::C::AST::Util - C Translation to AST - Class method utilities

=head1 VERSION

version 0.12

=head1 SYNOPSIS

    use MarpaX::Languages::C::AST::Util qw/:all/;

    my $whoami = whoami();
    my $whowasi = whowasi();
    callIt(0, '1', [2], {3 => 4});

    sub callIt {
        my $hash = traceAndUnpack(['var1', 'var2', 'array1p', 'hash1p'], @_);
    }

=head1 DESCRIPTION

This modules implements some function utilities.

=head1 EXPORTS

The methods whoami(), whowasi() and traceAndUnpack() are exported on demand.

=head1 SUBROUTINES/METHODS

=head2 whoami()

Returns the name of the calling routine.

=head2 whowasi()

Returns the name of the parent's calling routine.

=head2 traceAndUnpack($nameOfArgumentsp, @arguments)

Returns a hash mapping @{$nameOfArgumentsp} to @arguments and trace it. The tracing is done using a method quite similar to Log::Any. Tracing and hash mapping stops at the end of @nameOfArguments or @arguments.

=head2 logCroak($fmt, @arg)

Formats a string using Log::Any, issue a $log->fatal with it, and croak with it.

=head2 showLineAndCol($line, $col, $sourcep)

Returns a string showing the request line, followed by another string that shows what is the column of interest, in the form "------^".

=head2 lineAndCol($impl, $g1)

Returns the output of Marpa's line_column at a given $g1 location. Default $g1 is Marpa's current_g1_location().

=head2 lastCompleted($impl, $symbol)

Returns the string corresponding the last completion of $symbol.

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
