#!/usr/bin/env perl
use strict;

use Test::More tests => 3;

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

$lib = catdir(@path, 't');
unshift(@INC, $lib);

require Filmore::UpdateUser;
require Filmore::WebFile;

my $base_dir = catdir(@path, 'test');

rmtree($base_dir);
mkdir $base_dir;
chdir $base_dir;
$base_dir = getcwd();

my %params = (
              web_master => 'poobah@test.com',
              valid_write => [$base_dir],
              base_directory => $base_dir,
              );

my $uu = Filmore::UpdateUser->new(%params);
my $wf = Filmore::WebFile->new(%params);

#----------------------------------------------------------------------
# Write files

do {

    my $text = <<'EOQ';
bar@test.com:1d2f3g4s
foo@test.com:8g4h6j7x
EOQ

    my $file = catfile($base_dir, '.htpasswd');
    $wf->write_wo_validation($file, $text);
};

#----------------------------------------------------------------------
# Check command selection

do {
    my $results = {email => 'bar@test.com'};

    my $cmd = $uu->get_command($results);
    is($cmd, 'browse_ptr', "No command"); # test 1

    $results->{cmd} = 'duh';
    $cmd = $uu->get_command($results);
    is($cmd, 'browse_ptr', "Bad command"); # test 2

    $results->{cmd} = 'remove';
    $cmd = $uu->get_command($results);
    is($cmd, 'remove_ptr', "Good command"); # test 3
};
