#!/usr/bin/env perl
use strict;

use Test::More tests => 1;

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

require Filmore::BrowseUser;
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

my $bu = Filmore::BrowseUser->new(%params);
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
# Read object and info

do {
    my $valid;
    my $results = {};
    my $info = $bu->info_object($results);
    foreach my $field (@$info) {
        if ($field->{name} eq 'email') {
            $valid = $field->{valid};
        }
    }

    my $valid_ok = '&string|bar@test.com|foo@test.com|';
    is($valid, $valid_ok, "Read info"); # test 1
};
