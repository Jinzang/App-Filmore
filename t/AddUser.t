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

require Filmore::AddUser;
require Filmore::WebFile;

my $base_dir = catdir(@path, 'test');

rmtree($base_dir);
mkdir $base_dir;
chdir $base_dir;
$base_dir = getcwd();
my $nonce = 123;

my %params = (
              valid_write => [$base_dir],
              base_directory => $base_dir,
              nonce => $nonce,
              );

my $au = Filmore::AddUser->new(%params);
my $wf = Filmore::WebFile->new(%params);

#----------------------------------------------------------------------
# Write files

do {
    my $text = <<'EOQ';
script1:foo@test.com
script2:foo@test.com bar@test.com
EOQ

    my $file = catfile($base_dir, '.htgroups');
    $wf->write_wo_validation($file, $text);

    $text = <<'EOQ';
bar@test.com:1d2f3g4s
foo@test.com:8g4h6j7x
EOQ

    $file = catfile($base_dir, '.htpasswd');
    $wf->write_wo_validation($file, $text);
};

#----------------------------------------------------------------------
# Validate request

do  {
    my $email = 'blue@test.com';
    my $groups = [qw(script1 script2)];
    my $results = {email => $email, group => $groups, nonce => $nonce};

    my $msg = $au->validate_object($results);
    is($msg, undef, "Validate request"); # test 1

    my $bad_mail = 'foo@test.com';
    $results = {email => $bad_mail, group => $groups, nonce => $nonce};
    $msg = $au->validate_object($results);
    is($msg, "User already exists: $bad_mail", "Validate bad user"); # test 2

    my $bad_groups = [qw(script3)];
    $results = {email => $email, group => $bad_groups, nonce => $nonce};
    $msg = $au->validate_object($results);
    is($msg, "Group not found: $bad_groups->[0]", "Validate bad group"); # test 3
};
