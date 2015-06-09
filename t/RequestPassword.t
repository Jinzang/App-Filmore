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

$lib = catdir(@path, 't');
unshift(@INC, $lib);

require Filmore::RequestPassword;
require Filmore::UserData;
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

my $id_ok;
my $rp = Filmore::RequestPassword->new(%params);
my $wf = Filmore::WebFile->new(%params);
my $ud = Filmore::UserData->new(%params);

#----------------------------------------------------------------------
# Write files

do {
    my $text = <<'EOQ';
bar@test.com:1d2f3g4s
foo@test.com:8g4h6j7x
EOQ

    my $file = catfile($base_dir, '.htpasswd');
    $wf->write_wo_validation($file, $text);

    my $email = 'bar@test.com';
    my $passwords = $ud->read_password_file();
    my $password = $passwords->{$email};
    $id_ok = $ud->hash_string($email, $password);
};

#----------------------------------------------------------------------
# Validate request

do  {
    my $email = 'foo@test.com';
    my $results = {email => $email};

    my $msg = $rp->validate_object($results);
    is($msg, undef, "Validate request"); # test 1

    my $bad_mail = 'blue@test.com';
    $results = {email => $bad_mail};
    $msg = $rp->validate_object($results);
    is($msg, "Not the email of a registered user",
       "Validate bad user"); # test 2
};

#----------------------------------------------------------------------
# Build the id string

do {
    my $email = 'bar@test.com';
    my $id = $rp->build_id($email);
    is($id, $id_ok, "Build id string"); # test 3

};

#----------------------------------------------------------------------
#  Build mail fields

do {
    my $email = 'bar@test.com';
    my $base_url = 'http://www.test.com';
    my $script_url = "$base_url/password.cgi";

    my $body_ok = <<"EOQ";
A request was made to change the password for the account bar\@test.com.
on the website http://www.test.com. If you did not make this request, ignore
this message. If you did, go to

http://www.test.com/password.cgi?id=$id_ok

to change your password.
EOQ

    my $results = {email => $email,
                   base_url => $base_url,
                   script_url => $script_url,
                   id => $id_ok};

    my $mail_fields = $rp->build_mail_fields($results);

    my $fields_ok = {to => $email,
                     body => $body_ok,
                     from => $params{web_master},
                     subject => 'Password change request'};

    is_deeply($mail_fields, $fields_ok, "Build mail fields"); # test 4
};
