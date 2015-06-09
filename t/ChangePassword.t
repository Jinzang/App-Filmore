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

require Filmore::ChangePassword;
require Filmore::WebFile;

my $base_dir = catdir(@path, 'test');

rmtree($base_dir);
mkdir $base_dir;
chdir $base_dir;
$base_dir = getcwd();

my %params = (
              extra => 'asdfghjk',
              valid_read => [$base_dir],
              web_master => 'poobah@test.com',
              base_directory => $base_dir,
              );

my $cp = Filmore::ChangePassword->new(%params);
my $ud = Filmore::UserData->new(%params);
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
# Validate request

do  {
    my $results = {password1 => 'big-secret', password2 => 'big-secret'};

    my $msg = $cp->validate_object($results);
    is($msg, undef, "Validate password"); # test 1

    $results->{password2} = 'no-secret';
    $msg = $cp->validate_object($results);
    is($msg, "Passwords do not match", "Validate mismatched password"); # test 2
};

#----------------------------------------------------------------------
# Find email fom id and check id

do {
    my $email_ok = 'bar@test.com';
    my $passwords = $ud->read_password_file();
    my $password_ok = $passwords->{$email_ok};
    my $id = $ud->hash_string($email_ok, $password_ok);

    my $email = $cp->find_email($id, $passwords);
    is($email, $email_ok, "Find email from id"); # test 3

    my $results= {id => $id};
    my $ok = $cp->check_id_object($results);
    is($ok, 1, "Check valid id"); # test 4

    $results->{id} .= '1a2b';
    $ok = $cp->check_id_object($results);
    is($ok, '', "Check invalid id"); # test 5
};
