
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
    "bin/c2ast",
    "bin/cscan"
  ],
  "LICENSE" => "perl",
  "NAME" => "MarpaX::Languages::C::AST",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Class::Struct" => 0,
    "Data::Dumper" => 0,
    "Exporter" => 0,
    "File::Basename" => 0,
    "File::Spec" => 0,
    "File::Temp" => 0,
    "Getopt::Long" => 0,
    "IO::File" => 0,
    "IO::Handle" => 0,
    "IO::String" => 0,
    "IPC::Cmd" => 0,
    "IPC::Run" => 0,
    "Log::Any" => 0,
    "Log::Any::Adapter" => 0,
    "Log::Log4perl" => 0,
    "Marpa::R2" => "2.064000",
    "POSIX" => 0,
    "Pod::Usage" => 0,
    "Regexp::Common" => 0,
    "SUPER" => 0,
    "Scalar::Util" => 0,
    "Term::ProgressBar" => 0,
    "XML::LibXML" => 0,
    "XML::Simple" => 0,
    "constant" => 0,
    "diagnostics" => 0,
    "parent" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "File::Spec::Functions" => 0,
    "File::Temp" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "List::Util" => 0,
    "Test::Differences" => 0,
    "Test::More" => 0,
    "Test::Trap" => 0
  },
  "VERSION" => "0.32",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "Class::Struct" => 0,
  "Data::Dumper" => 0,
  "Exporter" => 0,
  "ExtUtils::MakeMaker" => 0,
  "File::Basename" => 0,
  "File::Spec" => 0,
  "File::Spec::Functions" => 0,
  "File::Temp" => 0,
  "Getopt::Long" => 0,
  "IO::File" => 0,
  "IO::Handle" => 0,
  "IO::String" => 0,
  "IPC::Cmd" => 0,
  "IPC::Open3" => 0,
  "IPC::Run" => 0,
  "List::Util" => 0,
  "Log::Any" => 0,
  "Log::Any::Adapter" => 0,
  "Log::Log4perl" => 0,
  "Marpa::R2" => "2.064000",
  "POSIX" => 0,
  "Pod::Usage" => 0,
  "Regexp::Common" => 0,
  "SUPER" => 0,
  "Scalar::Util" => 0,
  "Term::ProgressBar" => 0,
  "Test::Differences" => 0,
  "Test::More" => 0,
  "Test::Trap" => 0,
  "XML::LibXML" => 0,
  "XML::Simple" => 0,
  "constant" => 0,
  "diagnostics" => 0,
  "parent" => 0,
  "strict" => 0,
  "warnings" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



