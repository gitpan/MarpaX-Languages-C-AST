#!env perl
use strict;
use warnings FATAL => 'all';
use diagnostics;
use MarpaX::Languages::C::AST;
use Getopt::Long;
use Config;
use IPC::Run qw/run/;
use Term::ProgressBar;
use POSIX qw/EXIT_FAILURE EXIT_SUCCESS/;
use IO::Handle;
use MarpaX::Languages::C::AST::Util::Data::Find;
use File::Basename qw/basename dirname/;
use Scalar::Util qw/blessed/;
use Data::Dumper;
use Log::Log4perl qw/:easy/;
use Log::Any::Adapter;
use Log::Any qw/$log/;

autoflush STDOUT 1;

# ABSTRACT: C source analysis

our $VERSION = '0.15'; # VERSION

# PODNAME: c2ast.pl


my $help = 0;
my @cpp = ();
my $cppfile = '';
my $cppdup = '';
my @lexeme = ();
my $progress = 0;
my @check = ();
my $dump = 0;
my $dumpfile = '';
my $allowAmbiguity = 0;
my $loglevel = 'WARN';

Getopt::Long::Configure("pass_through");
GetOptions ('help!' => \$help,
            'cpp=s' => \@cpp,
            'cppfile=s' => \$cppfile,
            'cppdup=s' => \$cppdup,
            'lexeme=s' => \@lexeme,
            'progress!' => \$progress,
            'check=s' => \@check,
            'dump!' => \$dump,
            'dumpfile=s' => \$dumpfile,
            'allowAmbiguity!' => \$allowAmbiguity,
            'loglevel=s' => \$loglevel);

# ----
# Init 
# ----
my $defaultLog4perlConf = <<DEFAULT_LOG4PERL_CONF;
log4perl.rootLogger              = $loglevel, Screen
log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
log4perl.appender.Screen.stderr  = 0
log4perl.appender.Screen.layout  = PatternLayout
log4perl.appender.Screen.layout.ConversionPattern = %d %-5p %6P %m{chomp}%n
DEFAULT_LOG4PERL_CONF
Log::Log4perl::init(\$defaultLog4perlConf);
Log::Any::Adapter->set('Log4perl');

if ($help || ! @ARGV) {
  usage($help ? EXIT_SUCCESS : EXIT_FAILURE)
}

my $preprocessedOutput;
@cpp = ('cpp') if (! @cpp);
# ---------------------------------------------------------------
# Run the preprocessor: any unknown option is passed as-is to cpp
# ---------------------------------------------------------------
my @cmd = (@cpp, @ARGV);
$log->debugf('Executing preprocessor: %s', \@cmd);
run(\@cmd, \undef, \$preprocessedOutput);
if ($cppdup) {
  if (! open(CPP, '>', $cppdup)) {
    warn "Cannot open $cppdup, $!\n";
  } else {
    print CPP $preprocessedOutput;
    if (! close(CPP)) {
      warn "Cannot close $cppdup, $!\n";
    }
  }
}

# -----------------
# Callback argument
# -----------------
my %lexemeCallbackHash = (file => $cppfile,
			  lexeme => {},
			  internalLexeme => {},
			  progress => undef,
			  position2line => {},
			  next_progress => 0,
			  allfiles => {});

my %check = ();
map {++$check{$_}} @check;
if (exists($check{reservedNames})) {
    # Force IDENTIFIER internal survey
    $lexemeCallbackHash{internalLexeme}->{IDENTIFIER} = 1;
}

if ($progress) {
  #
  # Number of lines, for Text::ProgressBar
  #
  $lexemeCallbackHash{nbLines} = ($preprocessedOutput =~tr/\n/\n/ + ! $preprocessedOutput =~ /\n\z/);
  $lexemeCallbackHash{progress} = Term::ProgressBar->new({name  => $ARGV[-1],
                                                          count => $lexemeCallbackHash{nbLines},
                                                          remove => 1,
                                                          ETA => 'linear'});
  $lexemeCallbackHash{progress}->minor(0);
}

# -------
# Parse C
# -------
map {++$lexemeCallbackHash{lexeme}->{$_}} @lexeme;
my $cAstObject = MarpaX::Languages::C::AST->new(lexemeCallback => [ \&lexemeCallback, \%lexemeCallbackHash ], logInfo => $log->is_info());
my $bless = $cAstObject->parse(\$preprocessedOutput);
if ($progress) {
    if ($lexemeCallbackHash{nbLines} > $lexemeCallbackHash{next_progress}) {
	$lexemeCallbackHash{progress}->update($lexemeCallbackHash{nbLines});
    }
}

# --------------
# Postprocessing
# --------------

# ----
# Dump
# ----
if ($dump || $dumpfile || %check) {
  my $value = $cAstObject->value($allowAmbiguity);
  my $bless = $allowAmbiguity ? $value->[0] : $value;

  if (%check) {
    check(\%check, \%lexemeCallbackHash, $bless);
  }

  if ($dump || $dumpfile) {
    my $dump = Dumper($value);
    if ($dump) {
      print Dumper($value);
    }
    if ($dumpfile) {
      if (! open(DUMP, '>', $dumpfile)) {
        warn "Cannot open $dumpfile, $!\n";
      } else {
        print DUMP $dump;
        if (! close(DUMP)) {
          warn "Cannot close $dumpfile, $!\n";
        }
      }
    }
  }
}

exit(EXIT_SUCCESS);

# --------------------------------------------------------------------------------------
sub check {
    my ($checkp, $lexemeCallbackHashp, $bless) = @_;

    if (exists($checkp->{reservedNames})) {
	checkreservedNames($lexemeCallbackHashp, $bless);
    }

}
# --------------------------------------------------------------------------------------
sub checkreservedNames {
    my ($lexemeCallbackHashp, $bless) = @_;

    #
    ## Apply GNU rules on every directDeclaratorIdentifier with a position
    ## that matches that ones in the cpp filename
    #

    my %check = (
	qr/^E[\dA-Z]/             => 'Names beginning with a capital \'E\' followed by a digit or uppercase letter may be used for additional error code names',
	qr/^(?:is|to)[a-z]/       => 'Names that begin with either \'is\' or \'to\' followed by a lowercase letter may be used for additional character testing and conversion functions.',
	qr/^LC_[A-Z]/             => 'Names that begin with \'LC_\' followed by an uppercase letter may be used for additional macros specifying locale attributes',
	qr/^(?:sin|cos|tan|sincos|csin|ccos|ctan|asin|acos||atan|atan2|casin|cacos|catan|exp|exp2|exp10|log|log10|log2|logb|ilogb|pow|sqrt|cbrt|hypot|expm1|log1p|cexp|clog|clog10|csqrt|cpow|sinh|cosh|tanh|csinh|ccosh|ctanh|asinh|acosh|atanh|casinh|cacosh|catanh|erf|erfc|lgamma|gamma|tgamma|j0|j1|jn|y0|y1|yn|)[fl]$/                => 'Names of all existing mathematics functions suffixed with \'f\' or \'l\' are reserved for corresponding functions that operate on float and long double arguments, respectively',
	qr/^SIG[A-Z]/             => 'Names that begin with \'SIG\' followed by an uppercase letter are reserved for additional signal names',
	qr/^SIG_[A-Z]/            => 'Names that begin with \'SIG_\' followed by an uppercase letter are reserved for additional signal actions',
	qr/^(?:str|mem|wcs)[a-z]/ => 'Names beginning with \'str\', \'mem\', or \'wcs\' followed by a lowercase letter are reserved for additional string and array functions',
	qr/_t$/                   => 'Names that end with \'_t\' are reserved for additional type names'
    );

    if (grep {basename($_) eq 'dirent.h'} keys %{$lexemeCallbackHashp->{allfiles}}) {
	$check{qr/^d_/}      =  'The header file dirent.h reserves names prefixed with \'d_\'';
    }
    if (grep {basename($_) eq 'fcntl.h'} keys %{$lexemeCallbackHashp->{allfiles}}) {
	$check{qr/^[lFOS]_/} =  'The header file fcntl.h reserves names prefixed with \'l_\', \'F_\', \'O_\', and \'S_\'';
    }
    if (grep {basename($_) eq 'grp.h'} keys %{$lexemeCallbackHashp->{allfiles}}) {
	$check{qr/^gr_/}     =  'The header file grp.h reserves names prefixed with \'gr_\'';
    }
    if (grep {basename($_) eq 'limits.h'} keys %{$lexemeCallbackHashp->{allfiles}}) {
	$check{qr/_MAX$/}    =  'The header file limits.h reserves names suffixed with \'_MAX\'';
    }
    if (grep {basename($_) eq 'pwd.h'} keys %{$lexemeCallbackHashp->{allfiles}}) {
	$check{qr/^pw_/}      =  'The header file pwd.h reserves names prefixed with \'pw_\'';
    }
    if (grep {basename($_) eq 'signal.h'} keys %{$lexemeCallbackHashp->{allfiles}}) {
	$check{qr/^(?:ssa|SA)_/}  =  'The header file signal.h reserves names prefixed with \'sa_\' and \'SA_\'';
    }
    if (grep {basename(dirname($_)) eq 'sys' && basename($_) eq 'stat.h'} keys %{$lexemeCallbackHashp->{allfiles}}) {
	$check{qr/^(?:st|S)_/}      =  'The header file sys/stat.h reserves names prefixed with \'st_\' and \'S_\'';
    }
    if (grep {basename(dirname($_)) eq 'sys' && basename($_) eq 'times.h'} keys %{$lexemeCallbackHashp->{allfiles}}) {
	$check{qr/^tms_/}      =  'The header file sys/times.h reserves names prefixed with \'tms_\'';
    }
    if (grep {basename($_) eq 'termios.h'} keys %{$lexemeCallbackHashp->{allfiles}}) {
	$check{qr/^(?:c_|V|I|O|TC|B\d)/}      =  'The header file termios.h reserves names prefixed with \'c_\', \'V\', \'I\', \'O\', and \'TC\'; and names prefixed with \'B\' followed by a digit';
    }

    MarpaX::Languages::C::AST::Util::Data::Find->new(
	wanted => sub { my $o = shift;
			my $class = blessed($o) || '';
			return ($class eq 'C::AST::directDeclaratorIdentifier');
	},
	callback => sub { my ($lexemeCallbackHashp, $o) = @_;
			  #
			  # By definition, the "value" of directDeclaratorIdentifier is
			  # the IDENTIFIER lexeme value: [start,length,values]
			  #
			  my $position = $o->[0]->[0];
			  if (exists($lexemeCallbackHashp->{position2line}->{$position})) {
			      my $name = $o->[0]->[2];
			      my $line = $lexemeCallbackHashp->{position2line}->{$position};

			      my $tryToAlign = sprintf('%s(%d)', $lexemeCallbackHashp->{curfile}, $line);

			      while (my ($re, $string) = each %check) {
				  if ($name =~ $re) {
				      printf STDERR "%-*s %s: %s\n", $lexemeCallbackHashp->{tryToAlignMax}, $tryToAlign, $name, $string;
				  }
			      }
			  }
	},
	callbackArgs => [ $lexemeCallbackHashp ],
	)->process(${$bless});
}
# --------------------------------------------------------------------------------------
sub lexemeCallback {
    my ($lexemeCallbackHashp, $lexemeHashp) = @_;

    if (defined($lexemeCallbackHashp->{progress}) && defined($lexemeHashp->{line})) {
      if ($lexemeHashp->{line} >= $lexemeCallbackHashp->{next_progress}) {
        $lexemeCallbackHashp->{next_progress} = $lexemeCallbackHashp->{progress}->update($lexemeHashp->{line});
      }
    }

    #
    # We wait until the first #line information: this will give the name of current file
    #
    if ($lexemeHashp->{name} eq 'PREPROCESSOR_LINE_DIRECTIVE') {
	if ($lexemeHashp->{value} =~ /([\d]+)\s*\"([^\"]+)\"/) {
	    $lexemeCallbackHashp->{curline} = substr($lexemeHashp->{value}, $-[1], $+[1] - $-[1]);
	    $lexemeCallbackHashp->{curline_real} = $lexemeHashp->{line};
	    $lexemeCallbackHashp->{curfile} = substr($lexemeHashp->{value}, $-[2], $+[2] - $-[2]);
	    $lexemeCallbackHashp->{allfiles}->{$lexemeCallbackHashp->{curfile}}++;
	    if (! $lexemeCallbackHashp->{file}) {
		$lexemeCallbackHashp->{file} = $lexemeCallbackHashp->{curfile};
	    }
	    if (! defined($lexemeCallbackHashp->{tryToAlignMax})) {
		$lexemeCallbackHashp->{tryToAlignMax} = length(sprintf('%s(%d)', $lexemeCallbackHashp->{file}, 1000000)); # a pretty good max -;
	    }
	}
        #
        # This is an internal lexeme, no problem to change a bit the value. For instance, remove
        # \s if any.
        #
        $lexemeHashp->{value} =~ s/^\s*//g;
        $lexemeHashp->{value} =~ s/\s*$//g;
        $lexemeHashp->{value} =~ s/\n/\\n/g;
    }

    if (exists($lexemeCallbackHashp->{lexeme}->{$lexemeHashp->{name}}) ||
	exists($lexemeCallbackHashp->{internalLexeme}->{$lexemeHashp->{name}})) {

	if (defined($lexemeCallbackHashp->{file}) &&
	    defined($lexemeCallbackHashp->{curfile}) &&
	    $lexemeCallbackHashp->{file} eq $lexemeCallbackHashp->{curfile}) {
	    my $line = $lexemeCallbackHashp->{curline} + ($lexemeHashp->{line} - $lexemeCallbackHashp->{curline_real} - 1);
	    $lexemeCallbackHashp->{position2line}->{$lexemeHashp->{start}} = $line;
	    if (exists($lexemeCallbackHashp->{lexeme}->{$lexemeHashp->{name}})) {
		my $tryToAlign = sprintf('%s(%d)', $lexemeCallbackHashp->{curfile}, $line);
		printf "%-*s %-30s %s\n", $lexemeCallbackHashp->{tryToAlignMax}, $tryToAlign, $lexemeHashp->{name}, $lexemeHashp->{value};
	    }
	}
    }

}
# --------------------------------------------------------------------------------------
sub usage {
    my $rc = shift;

    print <<USAGE;
Usage: $^X $0 options

where options can be:

--help               This help

--cpp <argument>     cpp executable. Default is 'cpp'.

                     If your setup requires additional option, then you should repeat this option.
                     For example: your cpp setup is "cl -E". Then you say: --cpp cl --cpp -E

                     Take care: it has been observed that "cpp" output could be different than "compiler -E".
                     If c2ast complains and the output manifestly reports something that has not been
                     preprocessed corrected, then retry with: --cpp your_compiler --cpp your_compiler_option

                     This has been observed on Darwin for instance, where one have to say:
                     --cpp gcc --cpp -E

--cppfile <filename> The output of the preprocessor will contain a lot of lines like '#line "filename"', where
                     "filename" is guaranteed to be the constant for a given physical location in the filesystem.
                     The first occurence is always a marker of the source that c2ast sent to the preprocessor.
                     c2ast will catch it so that the --lexeme tracing phase, or the --check phase, will happen only
                     on lexemes relevant to the source file given on the command-line, and not polluted by lexemes
                     coming from any included file.

                     Nevertheless, the source given on the command-line /could/ be the result of another preprocessing phase.
                     You can use this option to tell c2ast what is the real filename to consider.

                     For example, suppose your .c file has the name: my/generated/source.c. And that the real origin is
                     my/input/source.w, where my/input/source.w has been preprocessed by you to generate
                     my/generated/source.c.

                     Then, it is very likely that my/generated/source.c will contain a line like:
                     # line xxx "my/input/source.c"

                     You will then say --cppfile "my/input/source.c".

                     Exemple: the file marpa.c in the build phase of libmarpa: this is the result of
                     a preprocessing on the file marpa.w.

--cppdup <filename>  Save the preprocessed output to this filename. Only useful for debugging c2ast.

--lexeme <lexeme>    Lexemes of interest. Look to the grammar to have the exhaustive list.
                     In practice, only IDENTIFIER, TYPEDEF_NAME and ENUMERATION_CONSTANT are useful.
                     An internal lexeme, not generated by Marpa itself also exist: PREPROCESSOR_LINE_DIRECTIVE.
                     This option must be repeated for every lexeme of interest.
                     The output will go to STDOUT.

--progress           Progress bar with ETA information. The "name" associated with the progress bar will the last
                     of the arguments unknown to c2ast. So it is quite strongly suggested to always end your
                     command-line with the file you want to analyse.

--check <checkName>  Perform some hardcoded checks on the code. Supported values for checkName are:
  reservedNames      Check IDENTIFIER lexemes v.s. Gnu recommended list of Reserved Names [1].

                     Any check that is not ok will print on STDERR.

--dump               Dump parse tree value on STDOUT.
--dumpfile <file>    Dump parse tree value to this named file.

                     Take care: dumping the parse tree value can hog your memory and CPU. This will not
                     be c2ast fault, but the module used to do the dump (currently, Data::Dumper).

--allowAmbiguity     Default is to allow a single parse tree value. Nevertheless, if the grammar in use by
                     c2ast has a hole, use this option to allow multiple parse tree values. In case of multiple
                     parse tree values, only the first one will be used in the check phase (option --check).

--loglevel <level>   A level that has to be meaningful for Log::Log4perl, typically WARN, INFO, ERROR, etc.
                     Default is WARN.

                     Note that tracing Marpa library itself is possible, but only using environment variable MARPA_TRACE /and/ saying --loglevel TRACE.

                     In case of trouble, typical debuggin of c2ast is:
                     --loglevel INFO
                     then:
                     --loglevel DEBUG
                     then:
                     --loglevel TRACE

Examples:

$0                   -D MYDEFINE1 -D MYDEFINE2 -I       /tmp/myIncludeDir            /tmp/myfile.c
$0                   -D MYDEFINE1 -D MYDEFINE2 -I       /tmp/myIncludeDir            /tmp/myfile.c --lexeme IDENTIFIER --lexeme TYPEDEF_NAME
$0 --cpp cl --cpp -E -D MYDEFINE1 -D MYDEFINE2 -I C:/Windows/myIncludeDir C:/Windows/Temp/myfile.c
$0                   -D MYDEFINE1 -D MYDEFINE2 -I       /tmp/myIncludeDir            /tmp/myfile.c --progress --check reservedNames

Less typical usage:

$0 -I libmarpa_build --cpp gcc --cpp -E --cppfile ./marpa.w  --progress --check reservedNames libmarpa_build/marpa.c

[1] http://www.gnu.org/software/libc/manual/html_node/Reserved-Names.html
USAGE

    exit($rc);
}

__END__

=pod

=encoding utf-8

=head1 NAME

c2ast.pl - C source analysis

=head1 VERSION

version 0.15

=head1 DESCRIPTION

This script will use Marpa::R2 to analyse the file given in argument.

=over

=item A first phase will always call the preprocessor, so you need to have one on your machine. Default is 'cpp', and be overwriten on the command-line.

=item Then the output of the preprocessor goes through a lexing phase, using an 2011 ISO ANSI C compliant grammar.

=item Finally, if you ask via the command-line to have a dump of the parse tree value(s), or to perform some checks on the your code, the parse tree is evaluated.

=back

Say --help on the command-line to have the full list of options, and examples.

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
