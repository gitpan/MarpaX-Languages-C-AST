use strict;
use warnings FATAL => 'all';

package MarpaX::Languages::C::AST::Grammar::ISO_ANSI_C_2011::Scan;

# ABSTRACT: Scan C source

use MarpaX::Languages::C::AST;
use MarpaX::Languages::C::AST::Util::Data::Find;
use Config;
use Carp qw/croak/;
use IPC::Cmd qw/run/;
use File::Temp qw/tempfile/;
use IO::File;
use Scalar::Util qw/blessed reftype/;
use Regexp::Common;
use String::ShellQuote qw/shell_quote_best_effort/;  # Not for Win32, but passes everywhere, so ok to use it like that
use Log::Any qw/$log/;
use constant {
    LEXEME_POSITION_INDEX => 0,
    LEXEME_LENGTH_INDEX => 1,
    LEXEME_VALUE_INDEX => 2
};
use MarpaX::Languages::C::AST::Grammar::ISO_ANSI_C_2011::Scan::Actions;
use File::ShareDir qw/:ALL/;

our $HAVE_SYS__INFO = eval 'use Sys::Info; 1' || 0;
our $HAVE_Win32__ShellQuote = _is_windows() ? (eval 'use Win32::ShellQuote qw/quote_native/; 1' || 0) : 0;
our $RESAMELINE = qr/(?:[ \t\v\f])*/;                        # i.e. WS* without \n
our $REDEFINE = qr/^${RESAMELINE}#${RESAMELINE}define${RESAMELINE}(\w+(?>[^\n\\]*)(?>\\.[^\n\\]*)*)/ms; # dot-matches-all mode, keeping ^ meaningful
our $BALANCEDPARENS = qr/$RE{balanced}{-parens=>'()'}{-keep}/;

our $VERSION = '0.40'; # TRIAL VERSION


# ----------------------------------------------------------------------------------------

sub new {
  my ($class, %opts) = @_;

  if (exists($opts{filename}) && exists($opts{content})) {
    croak 'filename and content are mutually exclusive';
  }
  if (! exists($opts{filename}) && ! exists($opts{content})) {
    croak 'filename or content is required';
  }

  my $self = {
              _filename_filter => exists($opts{filename_filter}  ) ? $opts{filename_filter}     : undef,
              _cpprun          => exists($opts{cpprun})            ? $opts{cpprun}              : ($ENV{MARPAX_LANGUAGES_C_SCAN_CPPRUN} || $Config{cpprun}),
              _cppflags        => exists($opts{cppflags})          ? $opts{cppflags}            : ($ENV{MARPAX_LANGUAGES_C_SCAN_CPPFLAGS} || $Config{cppflags}),
             };

  #
  # For anonymous enums or structs, so that their names do not clash
  #
  $self->{_anonCount} = 0;

  if (exists($opts{content})) {
    if (! defined($opts{content})) {
      croak 'Undefined content';
    }
    $self->{_content2fh} = File::Temp->new(UNLINK => 1, SUFFIX => '.c');
    my $filename = $self->{_orig_filename} = $self->{_content2fh}->filename;
    #
    # We open twice the temporary file to make sure it is not deleted
    # physically on disk and still visible for our process
    #
    $self->{_tmpfh} = IO::File->new($filename, 'r') || croak "Cannot open $filename, $!";
    print($self->{_content2fh}, $opts{content});
    close($self->{_content2fh}) || warn "Cannot close $self->{_content2fh}, $!";
    $self->{_content} = $opts{content};
  } else {
    if (! exists($opts{filename}) || ! defined($opts{filename})) {
      croak 'Undefined filename';
    }
    my $filename = $self->{_orig_filename} = $opts{filename};
    $self->{_tmpfh} = IO::File->new($filename, 'r') || croak "Cannot open $filename, $!";
  }

  if (defined($self->{_filename_filter})) {
      my $ref = reftype($self->{_filename_filter}) || '';
      if ($ref) {
	  if ($ref ne 'REGEXP') {
	      croak 'filename_filter must be a scalar or a regular expression';
	  } else {
	      #
	      # For efficiency, instead of doing ref() or reftype() all the time, we will do exists()
	      #
	      $self->{_filename_filter_re} = $self->{_filename_filter};
	  }
      }
  }

  bless($self, $class);

  $self->_init();

  #
  # This will unlink temporary file
  #
  delete($self->{_tmpfh});
  delete($self->{_content2fh});
  #
  # And eventual reference counts
  #
  delete($self->{_content});

  return $self;
}

# ----------------------------------------------------------------------------------------


sub ast {
  my $self = shift;

  return $self->{_ast};
}

# ----------------------------------------------------------------------------------------


sub astToString {
  my $self = shift;

  return $self->ast()->toString(1);
}

# ----------------------------------------------------------------------------------------


sub get {
  my ($self, $attribute) = @_;

  if ($attribute eq 'get' ||
      $attribute eq 'new') {
    croak "$attribute attribute is not supported";
  }

  return $self->$attribute;
}

# ----------------------------------------------------------------------------------------


sub includes {
  my ($self) = @_;

  return $self->{_includes};
}

# ----------------------------------------------------------------------------------------


sub defines_args {
  my ($self) = @_;

  return $self->{_defines_args};
}

# ----------------------------------------------------------------------------------------


sub defines_no_args {
  my ($self) = @_;

  return $self->{_defines_no_args};
}

# ----------------------------------------------------------------------------------------


sub strings {
  my ($self) = @_;

  return $self->{_strings};
}

# ----------------------------------------------------------------------------------------


sub macros {
  my ($self) = @_;

  return $self->{_macros};
}

# ----------------------------------------------------------------------------------------


sub fdecls {
  my ($self) = @_;

  return $self->{_fdecls};
}

# ----------------------------------------------------------------------------------------


sub inlines {
  my ($self) = @_;

  return $self->{_inlines};
}

# ----------------------------------------------------------------------------------------


sub parsed_fdecls {
  my ($self) = @_;

  return $self->{_parsed_fdecls};
}

# ----------------------------------------------------------------------------------------


sub typedef_hash {
  my ($self) = @_;

  return $self->{_typedef_hash};
}

# ----------------------------------------------------------------------------------------


sub typedef_texts {
  my ($self) = @_;

  return $self->{_typedef_texts};
}

# ----------------------------------------------------------------------------------------


sub typedefs_maybe {
  my ($self) = @_;

  return $self->{_typedefs_maybe};
}

# ----------------------------------------------------------------------------------------


sub vdecls {
  my ($self) = @_;

  return $self->{_vdecls};
}

# ----------------------------------------------------------------------------------------


sub vdecl_hash {
  my ($self) = @_;

  return $self->{_vdecl_hash};
}

# ----------------------------------------------------------------------------------------


sub typedef_structs {
  my ($self) = @_;

  return $self->{_typedef_structs};
}

# ----------------------------------------------------------------------------------------
# Brutal copy of String::ShellQuote::quote_literal

sub _quote_literal {
    my ($text, $force) = @_;

    # basic argument quoting.  uses backslashes and quotes to escape
    # everything.
    if (!$force && $text ne '' && $text !~ /[ \t\n\x0b"]/) {
        # no quoting needed
    }
    else {
        $text =~ s{(\\*)(?="|\z)}{$1$1}g;
        $text =~ s{"}{\\"}g;
        $text = qq{"$text"};
    }

    return $text;
}

# ----------------------------------------------------------------------------------------

sub _is_windows {
  my $rc;

  if ($HAVE_SYS__INFO) {
    my $info = Sys::Info->new;
    my $os   = $info->os();
    $rc = $os->is_windows;
  } else {
    if ($^O =~ /win32/i) {
      $rc = 1;
    } else {
      $rc = 0;
    }
  }

  return $rc;
}

# ----------------------------------------------------------------------------------------

sub _init {
    my ($self) = @_;

    #
    # Note that, because we do not know if cpprun or cppflags contain multiple things
    # we cannot use the array version of run(). So ye have to stringify ourself.
    # It is assumed (and is the case with %Config value), that cpprun and cppflags
    # will be already properly escaped.
    # Remains the filename that we do ourself.
    # Tyo big categories: Win32, others
    #
    my $quotedFilename;
    my $cmd = "$self->{_cpprun} $self->{_cppflags} ";
    if (_is_windows()) {
      if ($HAVE_Win32__ShellQuote) {
        $quotedFilename = quote_native($self->{_orig_filename});
      } else {
        $quotedFilename = _quote_literal($self->{_orig_filename}, 1);
      }
    } else {
      $quotedFilename = shell_quote_best_effort($self->{_orig_filename});
    }
    $cmd .= $quotedFilename;

    my ($success, $error_code, undef, $stdout_bufp, $stderr_bufp) = run(command => $cmd);

    if (! $success) {
      croak join('', @{$stderr_bufp});
    }

    my $stdout_buf = join('',@{$stdout_bufp});

    $self->_initInternals();
    $self->_analyse_with_grammar($stdout_buf);
    $self->_analyse_with_heuristics($stdout_buf);
    $self->_posprocess_heuristics();
    $self->_cleanInternals();

}

# ----------------------------------------------------------------------------------------

sub _initInternals {
    my ($self) = @_;

    $self->{_preprocessorNbNewlinesInFront} = {};
    $self->{_position2File} = {};
    $self->{_position2Line} = {};
    $self->{_position2LineReal} = {};
    $self->{_sortedPosition2File} = [];

}

# ----------------------------------------------------------------------------------------

sub _cleanInternals {
    my ($self) = @_;

    delete($self->{_preprocessorNbNewlinesInFront});
    delete($self->{_position2File});
    delete($self->{_position2Line});
    delete($self->{_position2LineReal});
    delete($self->{_sortedPosition2File});

}

# ----------------------------------------------------------------------------------------

sub _getAst {
  my ($self, $stdout_buf) = @_;

  #
  # Temporary stuff
  #
  my %tmpHash = (_currentFile => undef, _includes => {});
  #
  # Get the AST, the lexeme callback will flag position2file to things of interest
  #
  $self->{_includes} = {};
  $self->{_strings} = [];
  #
  # Plus from our module: strings detection
  #
  my $value = MarpaX::Languages::C::AST->new
      (
       logInfo => ['STRING_LITERAL_UNIT'],
       lexemeCallback => [ \&_lexemeCallback,
			   {self => $self,
			    tmpHashp => \%tmpHash,
			   }
       ],
       actionObject => sprintf('%s::%s', __PACKAGE__, 'Actions'),
       nonTerminalSemantic => ':default ::= action => nonTerminalSemantic',
      )->parse(\$stdout_buf)->value;
  $self->{_ast} = ${$value};

  #
  # Includes was a hash in %tmpHash
  #
  $self->{_includes} = [ sort keys %{$tmpHash{_includes}} ];
}

# ----------------------------------------------------------------------------------------

sub _analyse_with_grammar {
  my ($self, $stdout_buf) = @_;

  #
  # We get the AST and call other methods
  #
  $self->_getAst($stdout_buf);

  # -------------------------------------------------------------------------------------------
  # Producing a C::Scan equivalent is just a matter of revisiting the XML, i.e. the AST's value
  #
  # C::Scan outputs can be:
  #
  # includes                   Handled as a callback during lexing
  # defines_args               Handled in _posprocess_heuristics()
  # defines_no_args            Handled in _posprocess_heuristics()
  # fdecls                     functions declarations. Handled here.
  # inlines                    functions definitions. Handled here.
  # parsed_fdecls              parsed functions declarations. Handled here.
  # typedef_hash               typedefs. Handled here.
  # typedef_texts              typedefs expansions. Handled here.
  # typedefs_maybe             Empty here.
  # vdecls                     List of extern variables declarations. Handled here.
  # vdecl_hash                 Parsed extern variables declarations. Handled here.
  # typedef_structs            Parsed struct declarations. Handled here.
  # -------------------------------------------------------------------------------------------

  $self->_ast2fdecls($stdout_buf);
  $self->_ast2inlines($stdout_buf);
  $self->_ast2parsed_fdecls($stdout_buf);
  $self->_ast2typedef_hash($stdout_buf);
  $self->_ast2typedef_texts($stdout_buf);
  $self->_ast2typedefs_maybe($stdout_buf);
  $self->_ast2vdecls($stdout_buf);
  $self->_ast2vdecl_hash($stdout_buf);
  $self->_ast2typedef_structs($stdout_buf);

}

# ----------------------------------------------------------------------------------------

sub _xpath {
  my ($self, $sharedFilename) = @_;

  if (! defined($self->{_xpath}->{$sharedFilename})) {
    my $filename = dist_file('MarpaX-Languages-C-AST', $sharedFilename);
    if (! open(XPATH, '<', $filename)) {
      croak "Cannot open $filename, $!";
    }
    my $xpath = do {local $/; <XPATH>};
    close(XPATH) || warn "Cannot close $filename; $!";
    #
    # Remove any blank outside of the xpath expression
    #
    $xpath =~ s/^\s*//;
    $xpath =~ s/\s*$//;
    $self->{_xpath}->{$sharedFilename} = XML::LibXML::XPathExpression->new($xpath);
  }
  return $self->{_xpath}->{$sharedFilename};
}

# ----------------------------------------------------------------------------------------

sub _pushNodeString {
  my ($self, $stdout_buf, $outputp, $node) = @_;

  #
  # Unless the node is already a lexeme, we have to search surrounding lexemes
  #
  my $text = $node->getAttribute('text');
  if (defined($text)) {
    if (ref($outputp) eq 'ARRAY') {
      push(@{$outputp}, $text);
    } else {
      ${$outputp} = $text;
    }
  } else {
    #
    ## Get first and last lexemes positions
    #
    my $firstLexemeXpath = $self->_xpath('share/xpath/firstLexeme.xpath');
    my $lastLexemeXpath = $self->_xpath('share/xpath/lastLexeme.xpath');

    my $firstLexeme = $node->findnodes($firstLexemeXpath);
    my $lastLexeme = $node->findnodes($lastLexemeXpath);

    if ($firstLexeme && $lastLexeme) {
      my $startPosition = $firstLexeme->[0]->findvalue('./@start');
      my $endPosition = $lastLexeme->[0]->findvalue('./@start') + $lastLexeme->[0]->findvalue('./@length');
      my $length = $endPosition - $startPosition;
      my $text = substr($stdout_buf, $startPosition, $length);
      if (ref($outputp) eq 'ARRAY') {
        push(@{$outputp}, $text);
      } else {
        ${$outputp} = $text;
      }
    }
  }
}

# ----------------------------------------------------------------------------------------

sub _ast2fdecls {
  my ($self, $stdout_buf) = @_;

  if (! defined($self->{_fdecls})) {
    #
    # We rely on parsed_fdecls
    #
    $self->_ast2parsed_fdecls($stdout_buf);
  }

  return $self->{_fdecls};
}

# ----------------------------------------------------------------------------------------

sub _ast2typedef_texts {
  my ($self, $stdout_buf) = @_;

  if (! defined($self->{_typedef_texts})) {
    #
    # We rely on typedef_hash
    #
    $self->_ast2typedef_hash($stdout_buf);
  }

  return $self->{_typedef_texts};
}

# ----------------------------------------------------------------------------------------

sub _ast2typedefs_maybe {
  my ($self, $stdout_buf) = @_;

  if (! defined($self->{_typedefs_maybe})) {
    #
    # We rely on typedef_hash
    #
    $self->_ast2typedef_hash($stdout_buf);
  }

  return $self->{_typedefs_maybe};
}

# ----------------------------------------------------------------------------------------

sub _ast2typedef_structs {
  my ($self, $stdout_buf) = @_;

  if (! defined($self->{_typedef_structs})) {
    #
    # We rely on typedef_hash
    #
    $self->_ast2typedef_hash($stdout_buf);
  }

  return $self->{_typedef_structs};
}

# ----------------------------------------------------------------------------------------

sub _ast2vdecls {
  my ($self, $stdout_buf) = @_;

  if (! defined($self->{_vdecls})) {
    #
    # We rely on vdecl_hash
    #
    $self->_ast2vdecl_hash($stdout_buf);
  }

  return $self->{_vdecls};
}

# ----------------------------------------------------------------------------------------

sub _removeWord {
  my ($self, $outputp, $toRemove) = @_;

  my $quotemeta = quotemeta($toRemove);
  ${$outputp} =~ s/^\s*$quotemeta\b\s*//;
  ${$outputp} =~ s/\s*\b$quotemeta\s*$//;
  ${$outputp} =~ s/\s*\b$quotemeta\b\s*/ /;
}

# ----------------------------------------------------------------------------------------

sub _ast2vdecl_hash {
  my ($self, $stdout_buf) = @_;

  if (! defined($self->{_vdecl_hash})) {
    $self->{_vdecl_hash} = {};
    $self->{_vdecls} = [];
    #
    # a vdecl is a "declaration" node
    #
    foreach my $declaration ($self->ast()->findnodes($self->_xpath('share/xpath/vdecl.xpath'))) {
      $self->_pushNodeString($stdout_buf, $self->{_vdecls}, $declaration);
      #
      # Get first declarationSpecifiers
      #
      my @declarationSpecifiers = $declaration->findnodes($self->_xpath('share/xpath/firstDeclarationSpecifiers.xpath'));
      if (! @declarationSpecifiers) {
	#
	# Could be a static assert declaration
	#
	next;
      }
      my $text;
      $self->_pushNodeString($stdout_buf, \$text, $declarationSpecifiers[0]);
      #
      # vdecl_hash does not have the extern keyword.
      #
      $self->_removeWord(\$text, 'extern');
      #
      # variable name
      #
      my @declarator = $declaration->findnodes($self->_xpath('share/xpath/declaration2Declarator.xpath'));
      my @keys = ();
      my @before = ();
      my @after = ();
      foreach (@declarator) {
	my $declarator;
	$self->_pushNodeString($stdout_buf, \$declarator, $_);

	my @IDENTIFIER = $_->findnodes($self->_xpath('share/xpath/declarator2IDENTIFIER.xpath'));
	if (@IDENTIFIER) {
	  $self->_pushNodeString($stdout_buf, \@keys, $IDENTIFIER[0]);
	} else {
	  my $anon = sprintf('ANON%d', $self->{_anonCount}++);
	  push(@keys, $anon);
	}
	$declarator =~ /(.*)$keys[-1](.*)/;
        my $before = defined($-[1]) ? substr($declarator, $-[1], $+[1]-$-[1]) : '';
        my $after = defined($-[2]) ? substr($declarator, $-[2], $+[2]-$-[2]) : '';
	push(@before, ($before =~ /[^\s]/) ? ' ' . $before : '');
	push(@after, ($after =~ /[^\s]/) ? ' ' . $after : '');
      }
      if (! @keys) {
	push(@keys, sprintf('ANON%d', $self->{_anonCount}++));
	push(@before, '');
	push(@after, '');
      }
      foreach (0..$#keys) {
	$self->{_vdecl_hash}->{$keys[$_]} = [ $text . $before[$_], $after[$_] ];
      }
    }
  }

  return $self->{_vdecl_hash};
}

# ----------------------------------------------------------------------------------------

sub _ast2typedef_hash {
  my ($self, $stdout_buf) = @_;

  if (! defined($self->{_typedef_hash})) {
    $self->{_typedef_hash} = {};
    $self->{_typedef_texts} = [];
    $self->{_typedefs_maybe} = [];
    $self->{_typedef_structs} = {};
    #
    # typedef is a "declaration" node
    #
    foreach my $declaration ($self->ast()->findnodes($self->_xpath('share/xpath/typedef.xpath'))) {
      my @declarationSpecifiers = $declaration->findnodes($self->_xpath('share/xpath/firstDeclarationSpecifiers.xpath'));
      if (! @declarationSpecifiers) {
	#
	# Could be a static assert declaration
	#
	next;
      }
      $self->_pushNodeString($stdout_buf, $self->{_typedef_texts}, $declarationSpecifiers[0]);
      #
      # typedef_texts does not have the extern keyword.
      #
      $self->_removeWord(\$self->{_typedef_texts}->[-1], 'typedef');
      #
      # typedef name
      #
      my @declarator = $declaration->findnodes($self->_xpath('share/xpath/declaration2Declarator.xpath'));
      my @keys = ();
      my @before = ();
      my @after = ();
      foreach (@declarator) {
	my $declarator;
	$self->_pushNodeString($stdout_buf, \$declarator, $_);

	my @IDENTIFIER = $_->findnodes($self->_xpath('share/xpath/declarator2IDENTIFIER.xpath'));
	$self->_pushNodeString($stdout_buf, \@keys, $IDENTIFIER[0]);
	$declarator =~ /(.*)$keys[-1](.*)/;
        my $before = defined($-[1]) ? substr($declarator, $-[1], $+[1]-$-[1]) : '';
        my $after = defined($-[2]) ? substr($declarator, $-[2], $+[2]-$-[2]) : '';
	push(@before, ($before =~ /[^\s]/) ? ' ' . $before : '');
	push(@after, ($after =~ /[^\s]/) ? ' ' . $after : '');
      }
      if (! @keys) {
	push(@keys, sprintf('ANON%d', $self->{_anonCount}++));
	push(@before, '');
	push(@after, '');
      }
      push(@{$self->{_typedefs_maybe}}, @keys);
      foreach (0..$#keys) {
	#
	# typedef before/after
	#
	$self->{_typedef_hash}->{$keys[$_]} = [ $self->{_typedef_texts}->[-1] . $before[$_], $after[$_] ];
      }
      #
      # Is a struct or union declaration ?
      #
      my @structOrUnionSpecifier = $declarationSpecifiers[0]->findnodes($self->_xpath('share/xpath/declarationSpecifiers2structOrUnionSpecifier.xpath'));
      if (@structOrUnionSpecifier) {
	my @struct = ();

        my @structDeclaration = $structOrUnionSpecifier[0]->findnodes($self->_xpath('share/xpath/structOrUnionSpecifier2structDeclaration.xpath'));
        foreach (@structDeclaration) {

          my @specifierQualifierList = $_->findnodes($self->_xpath('share/xpath/structDeclaration2specifierQualifierList.xpath'));
	  if (! @specifierQualifierList) {
	    # Gcc extension
	    next;
	  }
          my $specifierQualifierList;
          $self->_pushNodeString($stdout_buf, \$specifierQualifierList, $specifierQualifierList[0]);

          my @structDeclarator = $_->findnodes($self->_xpath('share/xpath/structDeclaration2structDeclarator.xpath'));
          my @keys = ();
          my @before = ();
          my @after = ();
          foreach (@structDeclarator) {
            my $structDeclarator;
            $self->_pushNodeString($stdout_buf, \$structDeclarator, $_);

            my @IDENTIFIER = $_->findnodes($self->_xpath('share/xpath/structDeclarator2IDENTIFIER.xpath'));
	    if (@IDENTIFIER) {
	      $self->_pushNodeString($stdout_buf, \@keys, $IDENTIFIER[0]);
	    } else {
	      # COLON constantExpression
	      push(@keys, sprintf('ANON%d', $self->{_anonCount}++));
	    }
            $structDeclarator =~ /(.*)$keys[-1](.*)/;

            my $before = defined($-[1]) ? substr($structDeclarator, $-[1], $+[1]-$-[1]) : '';
            my $after = defined($-[2]) ? substr($structDeclarator, $-[2], $+[2]-$-[2]) : '';
            push(@before, $specifierQualifierList . (($before =~ /[^\s]/) ? ' ' . $before : ''));
            push(@after, $after);
          }
          if (! @keys) {
            push(@keys, sprintf('ANON%d', $self->{_anonCount}++));
            push(@before, '');
            push(@after, '');
          }
          foreach (0..$#keys) {
            #
            # structDeclarator before/after
            #
            push(@struct, [ $before[$_], $after[$_], $keys[$_] ]);
          }
        }
	foreach (0..$#keys) {
	  #
	  # typedef before/after
	  #
	  $self->{_typedef_structs}->{$keys[$_]} = \@struct;
	}
      } else {
	foreach (0..$#keys) {
	  #
	  # typedef before/after
	  #
	  $self->{_typedef_structs}->{$keys[$_]} = undef;
	}
      }
    }
  }

  return $self->{_typedef_hash};
}

# ----------------------------------------------------------------------------------------

sub _ast2parsed_fdecls {
  my ($self, $stdout_buf) = @_;

  if (! defined($self->{_parsed_fdecls})) {
    $self->{_parsed_fdecls} = [];
    $self->{_fdecls} = [];

    foreach my $node ($self->ast()->findnodes($self->_xpath('share/xpath/fdecls.xpath'))) {
      $self->_pushNodeString($stdout_buf, $self->{_fdecls}, $node);
      my $fdecl = [];
      #
      # rt
      #
      my @declarationSpecifiers = $node->findnodes($self->_xpath('share/xpath/firstDeclarationSpecifiers.xpath'));
      if (! @declarationSpecifiers) {
	#
	# Could be a static assert declaration
	#
	next;
      }
      $self->_pushNodeString($stdout_buf, $fdecl, $declarationSpecifiers[0]);
      #
      # nm. In case of a function declaration, there can be only a single declarator
      # in the declaration
      #
      my @declarator = $node->findnodes($self->_xpath('share/xpath/declaration2Declarator.xpath'));

      my @IDENTIFIER = $declarator[0]->findnodes($self->_xpath('share/xpath/declarator2IDENTIFIER.xpath'));
      if (@IDENTIFIER) {
	$self->_pushNodeString($stdout_buf, $fdecl, $IDENTIFIER[0]);
      } else {
	my $anon = sprintf('ANON%d', $self->{_anonCount}++);
	push(@{$fdecl}, $anon);
      }
      #
      # args
      #
      my $args = [];
      my @args = $node->findnodes($self->_xpath('share/xpath/fdecl2args.xpath'));
      foreach (@args) {
	#
	# arg is a parameterDeclaration
	#
	my $arg = [];
	#
	# arg.rt
	#
	my @declarationSpecifiers = $_->findnodes($self->_xpath('share/xpath/firstDeclarationSpecifiers.xpath'));
	$self->_pushNodeString($stdout_buf, $arg, $declarationSpecifiers[0]);
	#
	# arg.nm or ANON
	#
        my $anon = undef;
	my @nm = $_->findnodes($self->_xpath('share/xpath/arg2nm.xpath'));
	if (@nm) {
	  $self->_pushNodeString($stdout_buf, $arg, $nm[0]);
	} else {
          my $anon = sprintf('ANON%d', $self->{_anonCount}++);
	  push(@{$arg}, $anon);
	}
	#
	# arg.arg is always undef
	#
	push(@{$arg}, undef);
	#
	# arg.ft
	#
	$self->_pushNodeString($stdout_buf, $arg, $_);
        if ($anon) {
          #
          # We faked an anonymous identifier
          #
          $arg->[-1] .= ' ' . $anon;
        }
	#
	# arg.mod
	#
        my @mod = $_->findnodes($self->_xpath('share/xpath/arg2mod.xpath'));
        if (@mod) {
	  #
	  # Per def $mod[0] is a directDeclarator that can be:
	  #
	  # directDeclarator LBRACKET RBRACKET
	  # directDeclarator LBRACKET STAR RBRACKET
	  # directDeclarator LBRACKET STATIC gccArrayTypeModifierList assignmentExpression RBRACKET
	  # etc...
	  #
	  # We clone the node, remove the first child. What remains will be the array modifiers.
	  #
	  my $newnode = $mod[0]->cloneNode(1);
	  my $childnode = $newnode->firstChild;
	  $newnode->removeChild($childnode );
          $self->_pushNodeString($stdout_buf, $arg, $newnode);
        } else {
          push(@{$arg}, '');
        }
	push(@{$args}, $arg);
      }
      push(@{$fdecl}, $args);
      #
      # ft, without remaining semicolon
      #
      $self->_pushNodeString($stdout_buf, $fdecl, $node);
      $fdecl->[-1] =~ s/\s*;$//;
      #
      # mod is always undef
      #
      push(@{$fdecl}, undef);

      push(@{$self->{_parsed_fdecls}}, $fdecl);
    }
  }

  return $self->{_parsed_fdecls};
}

# ----------------------------------------------------------------------------------------

sub _ast2inlines {
  my ($self, $stdout_buf) = @_;

  if (! defined($self->{_inlines})) {
    $self->{_inlines} = [];
    #
    # Simply, any path matching functionDefinition
    #
    foreach ($self->ast()->findnodes($self->_xpath('share/xpath/inlines.xpath'))) {
      $self->_pushNodeString($stdout_buf, $self->{_inlines}, $_);
    }
  }

  return $self->{_inlines};
}

# ----------------------------------------------------------------------------------------

sub _lexemeCallback {
  my ($lexemeCallbackHashp, $lexemeHashp) = @_;

  my $self = $lexemeCallbackHashp->{self};
  my $tmpHashp = $lexemeCallbackHashp->{tmpHashp};

  #
  # We wait until the first #line information: this will give the name of current file
  #
  if ($lexemeHashp->{name} eq 'PREPROCESSOR_LINE_DIRECTIVE') {
    if ($lexemeHashp->{value} =~ /([\d]+)\s*\"([^\"]+)\"/) {
	my $currentLine = substr($lexemeHashp->{value}, $-[1], $+[1] - $-[1]);
	my $currentFile = substr($lexemeHashp->{value}, $-[2], $+[2] - $-[2]);
        if (! defined($self->{_filename})) {
          #
          # The very first filename is always the original source.
          #
          $self->{_filename} = $currentFile;
        }
        if (! defined($self->{_filename_filter})) {
          #
          # Some precompilers like gcc from mingw like to double the backslashes.
          # We are independant of preprocessing style by doing it like that.
          #
          $self->{_filename_filter} = $self->{_filename};
        }

	$tmpHashp->{_currentFile} = $currentFile;
	$tmpHashp->{_currentLine} = $currentLine;
	$tmpHashp->{_currentLineReal} = $lexemeHashp->{line};

	$self->{_position2File}->{$lexemeHashp->{start}} = $tmpHashp->{_currentFile};
	$self->{_position2Line}->{$lexemeHashp->{start}} = $tmpHashp->{_currentLine};
	$self->{_position2LineReal}->{$lexemeHashp->{start}} = $tmpHashp->{_currentLineReal};
        if ($lexemeHashp->{value} =~ /^\s+/) {
          my $front = substr($lexemeHashp->{value}, $-[0], $+[0] - $-[0]);
          $self->{_preprocessorNbNewlinesInFront}->{$lexemeHashp->{start}} = ($front =~ tr/\n//);
        } else {
          $self->{_preprocessorNbNewlinesInFront}->{$lexemeHashp->{start}} = 0;
        }

	$tmpHashp->{_includes}->{$tmpHashp->{_currentFile}}++;
    }
    #
    # This is an internal lexeme, no problem to change a bit the value. For instance, remove
    # \s if any.
    #
    $lexemeHashp->{value} =~ s/^\s*//g;
    $lexemeHashp->{value} =~ s/\s*$//g;
    $lexemeHashp->{value} =~ s/\n/\\n/g;
  }

  if (defined($tmpHashp->{_currentFile})) {
      if ((exists($self->{_filename_filter_re}) && $tmpHashp->{_currentFile} =~ $self->{_filename_filter_re}) ||
	  $tmpHashp->{_currentFile} eq $self->{_filename_filter}) {
	  if ($lexemeHashp->{name} eq 'STRING_LITERAL_UNIT') {
	      #
	      # ISO C permits WS at the end of a string literal, we remove it
	      #
	      my $string = $lexemeHashp->{value};
	      $string =~ s/[ \t\v\n\f]*$//;
	      push(@{$self->{_strings}}, $string);
	  }
      }
  }
}

# ----------------------------------------------------------------------------------------

sub _analyse_with_heuristics {
  my ($self, $stdout_buf) = @_;

  if (! defined($self->{_content})) {
      #
      # Case where it was a filename given.
      # Per-def $self->{_tmpfh} is at the beginning of file at this time
      #
      $self->{_content} = do {my $fh = $self->{_tmpfh}; local $/; <$fh>;};
  }

  $self->{_macros} = [];
  pos($self->{_content}) = undef;
  while ($self->{_content} =~ m/$REDEFINE/g) {
      my $start = $-[1];
      my $end = $+[1];
      push(@{$self->{_macros}}, substr($self->{_content}, $start, $end - $start));
  }
}

# ----------------------------------------------------------------------------------------

sub _posprocess_heuristics {
    my ($self) = @_;

    #
    # We want to have defines_args and defines_no_args
    #
    $self->{_defines_args} = {};
    $self->{_defines_no_args} = {};
    foreach (@{$self->macros}) {
	if (/^(\w+)\s*$BALANCEDPARENS\s*(.*)/s) {
	    my $name  = substr($_, $-[1], $+[1] - $-[1]);
	    my $args  = substr($_, $-[2], $+[2] - $-[2]);
	    my $value = substr($_, $-[3], $+[3] - $-[3]);
	    substr($args,  0, 1, '');  # '('
	    substr($args, -1, 1, '');  # ')'
	    my @args = map {my $element = $_; $element =~ s/\s//g; $element;} split(/,/, $args);
	    $self->{_defines_args}->{$name} = [ [ @args ], $value ];
	} else {
	    /(\w+)\s*(.*)/s;
	    my $name  = substr($_, $-[1], $+[1] - $-[1]);
	    my $value = substr($_, $-[2], $+[2] - $-[2]);
	    $self->{_defines_no_args}->{$name} = $value;
	}
    }
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MarpaX::Languages::C::AST::Grammar::ISO_ANSI_C_2011::Scan - Scan C source

=head1 VERSION

version 0.40

=head1 SYNOPSIS

    use strict;
    use warnings FATAL => 'all';
    use MarpaX::Languages::C::Scan;
    use Config;
    use Data::Dumper;
    #
    # Parse C
    #
    my $filename = 'mysource.c';
    my %config = (cpprun => $Config{cpprun},
                  cppflags => $Config{cppflags});
    my $c = MarpaX::Languages::C::Scan->new(filename => $filename, %config);
    print Dumper($c->get('parsed_fdecls'));
    print Dumper($c->parsed_fdecls);

=head1 DESCRIPTION

This module scans a C source and exposes methods compatible with C::Scan module.

=head1 SUBROUTINES

=head2 new($class, %options)

Instantiate a new object. Parameters are in a hash that can contain the following keys:

=over

=item filename

File name to parse.

=item content

Content to parse.

=item filename_filter

Filter on filename from pre-processor output.

=item cpprun

Preprocessor command, default is $ENV{MARPAX_LANGUAGES_C_SCAN_CPPRUN}, or $Config{cpprun}. It is assume that cpprun is already correctly quoted for your system shell.

=item cppflags

Preprocessor flags, default is $ENV{MARPAX_LANGUAGES_C_SCAN_CPPFLAGS}, $Config{cppflags}. It is assume that cppflags is already correctly quoted for your system shell.

=back

Please refer to the Config perl documentation for the meaning of $Config{cpprun} or $Config{cppflags}.

This module will execute "$cpprun $cppflags $filename", using a temporary filename if $content was given. Thus a working precompiler is required.

$filename and $content are mutually exclusive. If $content is used a temporary file will be created using File::Temp (which may fail under taint mode -;).

The $filename_filter value limits the output to file names equal to $filename_filter (if this is a SCALAR) or matching $filename_filter (if this is a Regexp): since we use the precompiler, any #include statements is "polluting" the original source, i.e. much more files that just $filename (or $content) are used. Default value is $filename or the generated temporary filename when using $content mode.

The methods defines_args() and defines_no_args() are not subject to the filename_filter parameter: they always apply on the content or filename given /before/ the preprocessing. They are based on heuristic parsing, so their result should not be blindly trusted. A typical example of false positive is a macro inside string or a comment.

This module will croak on any error.

=back

=head1 METHODS

=head2 ast($self)

AST of the preprocessed output. This is an XML::LibXML document.

=head2 astToString($self)

Stringified AST of the preprocessed output. This is an XML::LibXML document passed through its toString(1) method.

=head2 get($self, $attribute)

C::Scan like method, that is a proxy to $self->$attribute. All methods described after can be used as attribute, for example: $self->get('strings'), or $self->get('includes').

=head2 includes($self)

Returns a reference to a list of included files, sorted alphabetically. This is available JUST because preprocessors give the file that has been preprocessed in their output using a #line directive, and there is a special procedure in MarpaX::Languages::C::AST for that, on top of the ISO C grammar.

=head2 defines_args($self)

Returns a reference to hash of macros with arguments. The values are references to an array of length 2, the first element is a reference to the list of arguments, the second one being the expansion.

=head2 defines_no_args($self)

Returns a reference to hash of macros without arguments.

=head2 strings($self)

Returns a reference to a list of strings after preprocessing, regardless of scope level.

=head2 macros($self)

Returns a reference to a list of macros before preprocessing.

=head2 fdecls($self)

C::Scan compatible reference to a list of parsed declarations of functions.

=head2 inlines($self)

C::Scan compatible reference to a list of definitions of functions.

=head2 parsed_fdecls($self)

C::Scan NOT-FULLY compatible reference to list of parsed declarations of functions: the type of arguments consist only of type specifiers as per the grammar. For instance pointers are not in argument types: strictly speaking pointers are part of a declarator.

=head2 typedef_hash($self)

Reference to a hash which contains known typedefs as keys. Values of the hash are array references of length 2, with what should be put before/after the type for a standalone typedef declaration (but without the typedef substring). Note that it is the minimal full text of the C source that is used to obtain the before/after strings, so this /can/ contain definition of other variables.

=head2 typedef_texts($self)

Returns a reference to a list which contains known expansions of typedefs. This is just the first indice from "value" part of typedef_hash.

=head2 typedefs_maybe($self)

Returns a reference to a list of typedefed names. This is just the "key" part of typedef_hash. The name "maybe" is kept for compatibility with C::Scan.

=head2 vdecls($self)

Returns a reference to a list of extern variable declarations.

=head2 vdecl_hash($self)

Reference to a hash of parsed extern variable declarations, containing the variable names as keys. Values of the hash are array references of length 2, with what should be put before/after the name for a standalone extern variable declaration (but without the extern substring). Note that it is the minimal full text of the C source that is used to obtain the before/after strings, so this /can/ contain definition of other variables.

=head2 typedef_structs($self)

Hopefully C::Scan compatible reference to a hash which contains known typedefs as keys. The values of the hash may not be compatible with C::Scan output. In our case these are array references of length 2, with at index 0 the full text used to parsed this typedef (maybe inclusing more than needed, but always what is necessary), and at index 1 an empty string.

=head1 NOTES

The default return type for functions without type specifier is fixed to 'int', as per the C standard.

=head1 SEE ALSO

L<Config>

L<MarpaX::Languages::C::AST>

L<C::Scan>

L<File:Temp>

L<C::Tokenize>

L<ModPerl::CScan>

=head1 AUTHOR

Jean-Damien Durand <jeandamiendurand@free.fr>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Jean-Damien Durand.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
