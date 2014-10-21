use strict;
use warnings FATAL => 'all';

package MarpaX::Languages::C::AST::Util;

# ABSTRACT: C Translation to AST - Class method utilities

use Exporter 'import';
use Log::Any qw/$log/;
use Data::Dumper;

our $VERSION = '0.08'; # VERSION
# CONTRIBUTORS

our @EXPORT_OK = qw/whoami whowasi traceAndUnpack/;


sub whoami {
    return (caller(1))[3];
}


sub whowasi {
    return (caller(2))[3];
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

1;

__END__

=pod

=encoding utf-8

=head1 NAME

MarpaX::Languages::C::AST::Util - C Translation to AST - Class method utilities

=head1 VERSION

version 0.08

=head1 SYNOPSIS

    use MarpaX::Languages::C::AST::Util qw/whoami whowasi traceAndUnpack/;

    my $whoami = whoami();
    my $whowasi = whowasi();
    callIt(0, '1', [2], {3 => 4});

    sub callIt {
        my $hash = traceAndUnpack(['var1', 'var2', 'array1p', 'hash1p'], @_);
    }

=head1 DESCRIPTION

This modules implements some function utilities. This is inspired from L<https://kb.wisc.edu/middleware/page.php?id=4309>.

=head1 EXPORTS

The methods whoami(), whowasi() and traceAndUnpack() are exported on demand.

=head1 SUBROUTINES/METHODS

=head2 whoami()

Returns the name of the calling routine.

=head2 whowasi()

Returns the name of the parent's calling routine.

=head2 traceAndUnpack($nameOfArgumentsp, @arguments)

Returns a hash mapping @{$nameOfArgumentsp} to @arguments and trace it. The tracing is done using a method quite similar to Log::Any. Tracing and hash mapping stops at the end of @nameOfArguments or @arguments.

=head1 AUTHOR

Jean-Damien Durand <jeandamiendurand@free.fr>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Jean-Damien Durand.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
