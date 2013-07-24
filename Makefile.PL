
use strict;
use warnings;

use 5.010;

use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Translate a C source to an AST",
  "AUTHOR" => "Jean-Damien Durand <jeandamiendurand\@free.fr>",
  "BUILD_REQUIRES" => {},
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "MarpaX-Languages-C-AST",
  "EXE_FILES" => [
    "bin/c2ast.pl"
  ],
  "LICENSE" => "perl",
  "NAME" => "MarpaX::Languages::C::AST",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Class::Struct" => 0,
    "Config" => 0,
    "Data::Dumper" => 0,
    "Exporter" => 0,
    "File::Basename" => 0,
    "Getopt::Long" => 0,
    "IO::Handle" => 0,
    "IPC::Run" => 0,
    "Log::Any" => 0,
    "Log::Any::Adapter" => 0,
    "Log::Log4perl" => 0,
    "Marpa::R2" => "2.064000",
    "POSIX" => 0,
    "SUPER" => 0,
    "Scalar::Util" => 0,
    "Storable" => 0,
    "Term::ProgressBar" => 0,
    "constant" => 0,
    "diagnostics" => 0,
    "parent" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Find" => 0,
    "File::Spec::Functions" => 0,
    "File::Temp" => 0,
    "List::Util" => 0,
    "Test::More" => 0,
    "Test::Trap" => 0
  },
  "VERSION" => "0.16",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  my $tr = delete $WriteMakefileArgs{TEST_REQUIRES};
  my $br = $WriteMakefileArgs{BUILD_REQUIRES};
  for my $mod ( keys %$tr ) {
    if ( exists $br->{$mod} ) {
      $br->{$mod} = $tr->{$mod} if $tr->{$mod} > $br->{$mod};
    }
    else {
      $br->{$mod} = $tr->{$mod};
    }
  }
}

unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



