#!/usr/local/bin/perl
use strict;

use Test::More tests => 4;

use Cwd;
use File::Path qw(rmtree);
use File::Spec::Functions qw(catdir catfile rel2abs splitdir);

#----------------------------------------------------------------------
# Load package

my @path = splitdir(rel2abs($0));
pop(@path);
pop(@path);

my $lib = catdir(@path, 'lib');
unshift(@INC, $lib);

$lib = catdir(@path, 't');
unshift(@INC, $lib);

require App::Filmore::ConfiguredObject;
require App::Filmore::ConfigFile;
require MinMax;

my $base_dir = catdir(@path, 'test');

rmtree($base_dir);
mkdir $base_dir;
chdir $base_dir;
$base_dir = getcwd();

my $config_file = "$base_dir/config.cfg";

my %parameters = (
    config_file => $config_file,
    min => 1,
    max => 10,
);

#----------------------------------------------------------------------
# Test new

my $cf = App::Filmore::ConfigFile->new(%parameters);
$cf->write_file(\%parameters);

can_ok($cf, qw(new parameters)); #test 1

#----------------------------------------------------------------------
# Test create new object from config file

my $mm = MinMax->new(config_file => $config_file);

is($mm->{min}, $parameters{min}, "Minmax min"); #test 2
is($mm->{max}, $parameters{max}, "Minmax max"); #test 3
is($mm->{config_ptr}{config_file}, $parameters{config_file},
   "Config file"); # test 4

