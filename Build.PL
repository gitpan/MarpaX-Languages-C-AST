
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  "build_requires" => {
    "Module::Build" => "0.3601"
  },
  "configure_requires" => {
    "Module::Build" => "0.3601"
  },
  "dist_abstract" => "Translate a C source to an AST",
  "dist_author" => [
    "Jean-Damien Durand <jeandamiendurand\@free.fr>"
  ],
  "dist_name" => "MarpaX-Languages-C-AST",
  "dist_version" => "0.04",
  "license" => "perl",
  "module_name" => "MarpaX::Languages::C::AST",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
    "Carp" => 0,
    "Class::Runtime" => 0,
    "Data::Dumper" => 0,
    "Exporter" => 0,
    "Log::Any" => 0,
    "Marpa::R2" => "2.056000",
    "Storable" => 0,
    "constant" => 0,
    "diagnostics" => 0,
    "perl" => "5.010",
    "strict" => 0,
    "warnings" => 0
  },
  "script_files" => [],
  "test_requires" => {
    "File::Find" => 0,
    "File::Temp" => 0,
    "Test::More" => 0,
    "tainting" => 0
  }
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  my $tr = delete $module_build_args{test_requires};
  my $br = $module_build_args{build_requires};
  for my $mod ( keys %$tr ) {
    if ( exists $br->{$mod} ) {
      $br->{$mod} = $tr->{$mod} if $tr->{$mod} > $br->{$mod};
    }
    else {
      $br->{$mod} = $tr->{$mod};
    }
  }
}

my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
