#!/usr/bin/env perl
use strict;

use Test::More tests => 5;

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

require Filmore::RemoveUser;
require Filmore::UserData;
require Filmore::WebFile;

my $base_dir = catdir(@path, 'test');

rmtree($base_dir);
mkdir $base_dir;
chdir $base_dir;
$base_dir = getcwd();
my $nonce = 123;

my %params = (
              web_master => 'poobah@test.com',
              valid_write => [$base_dir],
              base_directory => $base_dir,
              nonce => $nonce,
              );

my $ru = Filmore::RemoveUser->new(%params);
my $ud = Filmore::UserData->new(%params);
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
    my $email = 'foo@test.com';
    my $results = {email => $email, nonce => $nonce};

    my $msg = $ru->validate_object($results);
    is($msg, undef, "Validate request"); # test 1

    my $bad_mail = 'blue@test.com';
    $results = {email => $bad_mail, nonce => $nonce};
    $msg = $ru->validate_object($results);
    is($msg, "User not found: $bad_mail", "Validate bad user"); # test 2

    $bad_mail = $params{web_master};
    $results = {email => $bad_mail, nonce => $nonce};
    $msg = $ru->validate_object($results);
    is($msg, "Cannot remove web master", "Validate web master"); # test 3
};

#----------------------------------------------------------------------
# Remove user

do {
    my $email = 'bar@test.com';
    my $results = {email => $email};

    $ru->use_object($results);

    my $groups = $ud->read_groups_file();
    my $passwords = $ud->read_password_file();

    my $passwords_ok = {'foo@test.com' => '8g4h6j7x'};

    my $groups_ok = {script1 => {'foo@test.com' => 1},
                     script2 => {'foo@test.com' => 1},};

    is_deeply($passwords, $passwords_ok, "Remove user from passwords"); # test 4
    is_deeply($groups, $groups_ok, "Remove user from groups"); # test 5
};
