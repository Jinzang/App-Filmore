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

require Filmore::ConfiguredObject;
require Filmore::ConfigFile;
require MinMax;

my $base_dir = catdir(@path, 'test');
my $config_dir = catdir(@path, 'test', 'config');

rmtree($base_dir);
mkdir $base_dir;
mkdir $config_dir;
chdir $base_dir;
$base_dir = getcwd();

my $config_file = catfile($config_dir, 'config.cfg');

my %parameters = (
    config_dir => $config_dir,
    min => 1,
    max => 10,
);

#----------------------------------------------------------------------
# Test new

my $cf = Filmore::ConfigFile->new(%parameters);
$cf->write_file($config_file, \%parameters);

can_ok($cf, qw(new parameters)); #test 1

#----------------------------------------------------------------------
# Test create new object from config file

my $mm = MinMax->new(config_dir => $config_dir);

is($mm->{min}, $parameters{min}, "Minmax min"); #test 2
is($mm->{max}, $parameters{max}, "Minmax max"); #test 3
is($mm->{config_ptr}{config_dir}, $parameters{config_dir},
   "Config file"); # test 4
