#!/usr/bin/env perl
use strict;

use Test::More tests => 6;

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

require Filmore::UserData;
require Filmore::WebFile;

my $base_dir = catdir(@path, 'test');

rmtree($base_dir);
mkdir $base_dir;
chdir $base_dir;
$base_dir = getcwd();

my %params = (
              valid_write => [$base_dir],
              base_directory => $base_dir,
              );

my $ud = Filmore::UserData->new(%params);
my $wf = Filmore::WebFile->new(%params);

#----------------------------------------------------------------------
# Read and write password file

do {
    my $text = <<'EOQ';
foo@test.com:2c5tdfeg
bar@test.com:g7hsigkl
EOQ

    my $passwords_ok = {
                        'foo@test.com' => '2c5tdfeg',
                        'bar@test.com' => 'g7hsigkl',
                        };

    my $file = catfile($base_dir, '.htpasswd');
    $wf->write_wo_validation($file, $text);

    my $passwords = $ud->read_password_file();
    is_deeply($passwords, $passwords_ok, "Read password file"); # test 1

    my $request = {user => 'baz@test.com', pass1 => 'secret'};
    $ud->write_password_file($request);

    $passwords = $ud->read_password_file();

    my @password_keys = sort keys %$passwords;
    my $password_keys_ok = [qw(bar@test.com baz@test.com foo@test.com )];

    is_deeply(\@password_keys, $password_keys_ok, "Add password"); # test 2

    $ud->write_password_file($request, 1);
    $passwords = $ud->read_password_file();

    @password_keys = sort keys %$passwords;
    $password_keys_ok = [qw(bar@test.com foo@test.com )];

    is_deeply(\@password_keys, $password_keys_ok, "Delete password"); # test 3
};

#----------------------------------------------------------------------
# Read and write group file

do {
    my $text = <<'EOQ';
script1: foo@test.com
script2: foo@test.com bar@test.com
EOQ

    my $groups_ok = {
                    script1 => {'foo@test.com' => 1},
                    script2 => {'foo@test.com' => 1, 'bar@test.com' => 1},
                    };

    my $file = catfile($base_dir, '.htgroups');
    $wf->write_wo_validation($file, $text);

    my $groups = $ud->read_groups_file();
    is_deeply($groups, $groups_ok, "Read group file"); # test 4

    my $request = {user => 'baz@test.com', groups => [qw(script1 script2)]};
    $ud->write_groups_file($request);

    $groups_ok->{script1}{'baz@test.com'} = 1;
    $groups_ok->{script2}{'baz@test.com'} = 1;

    $groups = $ud->read_groups_file();
    is_deeply($groups, $groups_ok, "Add groups"); # test 5

    $request = {user => 'bar@test.com', groups => []};
    $ud->write_groups_file($request);

    delete $groups_ok->{script2}{'bar@test.com'};
    $groups = $ud->read_groups_file();

    is_deeply($groups, $groups_ok, "Delete groups"); # test 6
};
