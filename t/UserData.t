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

    $passwords->{'baz@test.com'} = 'secret';
    my %new_passwords = %$passwords;

    $ud->write_password_file($passwords);
    $passwords = $ud->read_password_file();

    my @password_keys = sort keys %$passwords;
    my @password_keys_ok = sort keys %new_passwords;

    is_deeply(\@password_keys, \@password_keys_ok, "Add password"); # test 2

    delete $passwords->{'baz@test.com'};
    $ud->write_password_file($passwords);
    $passwords = $ud->read_password_file();

    @password_keys = sort keys %$passwords;
    @password_keys_ok = sort keys %$passwords_ok;

    is_deeply(\@password_keys, \@password_keys_ok, "Delete password"); # test 3
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

    $ud->update_groups_file('baz@test.com', [qw(script1 script2)]);

    $groups_ok->{script1}{'baz@test.com'} = 1;
    $groups_ok->{script2}{'baz@test.com'} = 1;

    $groups = $ud->read_groups_file();
    is_deeply($groups, $groups_ok, "Add groups"); # test 5

    $ud->update_groups_file('bar@test.com', []);

    delete $groups_ok->{script2}{'bar@test.com'};
    $groups = $ud->read_groups_file();

    is_deeply($groups, $groups_ok, "Delete groups"); # test 6
};
