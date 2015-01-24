#!/usr/bin/env perl
use strict;

use Test::More tests => 2;

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

#----------------------------------------------------------------------
# Create configuration file

my $config = <<"EOQ";
# This is parameter one
one = 1
# This is parameter two
# It has a multi-line comment
two = 2
EOQ

my $io = IO::File->new($config_file, 'w');
print $io $config;
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
