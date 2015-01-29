#!/usr/bin/env perl
use strict;

use Test::More tests => 4;

use Cwd;
use IO::File;
use File::Path qw(rmtree);
use File::Spec::Functions qw(catdir catfile rel2abs splitdir);

#----------------------------------------------------------------------
# Load package

my @path = splitdir(rel2abs($0));
pop(@path);
pop(@path);

my $lib = catdir(@path, 'lib');
unshift(@INC, $lib);

require Filmore::ConfigFile;

my $base_dir = catdir(@path, 'test');

rmtree($base_dir);
mkdir $base_dir;
chdir $base_dir;
$base_dir = getcwd();

my $config_file = "$base_dir/config.cfg";
my $include_file = "$base_dir/config.inc";

#----------------------------------------------------------------------
# Create configuration file

my $config = <<"EOQ";
# This is parameter one
one = 1
# This is parameter two
# It has a multi-line comment
two = 2
EOQ

my $include = <<"EOQ";
# This is parameter three
three = 3
# This is parameter four
four = 4
EOQ

my $io = IO::File->new($config_file, 'w');
print $io $config;
close($io);

$io = IO::File->new($include_file, 'w');
print $io $include;
close($io);

#----------------------------------------------------------------------
# Test io

my $cf = Filmore::ConfigFile->new(config_file => $config_file);

my $configuration = $cf->read_file($config_file);

my $configuration_result = {
                            one => 1,
                            two => 2,
                            };

is_deeply($configuration, $configuration_result, "Read file"); #test 1

$cf->write_file($config_file, $configuration_result);
$configuration = $cf->read_file($config_file);

is_deeply($configuration, $configuration_result, "Write file"); # test 2

$config .= "include config.inc\n";

$io = IO::File->new($config_file, 'w');
print $io $config;
close($io);

$configuration = $cf->read_file($config_file);

my $configuration_result = {
                            one => 1,
                            two => 2,
                            three => 3,
                            four => 4,
                            };

is_deeply($configuration, $configuration_result, "Include file"); # test 3

$configuration_result = {
                         array => [1, 2, 3, 4],
                         hash => {first => 1, second => 2},
                         };

$cf->write_file($config_file, $configuration_result);
$configuration = $cf->read_file($config_file);

is_deeply($configuration, $configuration_result,
          "Read and write structures"); # test 4
