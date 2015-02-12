use strict;
use warnings;

package Filmore::UserData;

use lib '../../lib';
use base qw(Filmore::ConfiguredObject);

use Digest::MD5 qw(md5_hex);
use File::Spec::Functions qw(catfile rel2abs abs2rel splitdir);

our $VERSION = '0.01';
my $password_cache;

#----------------------------------------------------------------------
# Set the default parameter values

sub parameters {
    my ($pkg) = @_;

    return (
        nonce => 0,
        base_directory => '',
        webfile_ptr => 'Filmore::WebFile',
    );
}

#----------------------------------------------------------------------
# Encrypt password

sub encrypt {
    my ($self, $plain) = @_;;

    my $salt = $self->random_string(2);
    return crypt($plain, $salt);
}

#----------------------------------------------------------------------
# Hash a set of strings into another string

sub hash_string {
    my ($self, @strings) = @_;
    return md5_hex($(, @strings, $>);
}

#----------------------------------------------------------------------
# Generate a random string

sub random_string {
    my ($self, $length) = @_;

    my @string;
    push(@string, ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64])
        for 1 .. $length;

    return join('', @string);
}

#----------------------------------------------------------------------
# Read the groups file

sub read_groups_file {
    my ($self) = @_;

    my $groups = {};
    my $file = catfile($self->{base_directory}, '.htgroups');
    my $text = $self->{webfile_ptr}->reader($file);

    if ($text) {
        my @lines = split("\n", $text);
        foreach (@lines) {
            my ($group, $user_list) = split(/\s*:\s*/, $_, 2);
            next unless $group;

            my %users = map {$_ => 1} split(' ', $user_list);
            $groups->{$group} = \%users;
        }
    }

    return $groups;
}

#----------------------------------------------------------------------
# Read the current password file into a hash

sub read_password_file {
    my ($self) = @_;

    unless ($password_cache) {
        $password_cache = {};
        my $file = catfile($self->{base_directory}, '.htpasswd');
        my $text = $self->{webfile_ptr}->reader($file);

        if ($text) {
            my @lines = split("\n", $text);
            foreach (@lines) {
                my ($user, $password) = split(/\s*:\s*/, $_, 2);
                next unless $password;

                $password_cache->{$user} = $password;
            }
        }
    }

    return $password_cache;
 }

#----------------------------------------------------------------------
# Write group file for password protected site

sub update_groups_file {
    my ($self, $user, $user_groups) = @_;

    my @lines;
    my $groups = $self->read_groups_file();

    my %user_groups = map {$_ => 1} @{$user_groups};

    foreach my $group (sort keys %$groups) {
        if ($user_groups{$group}) {
            $groups->{$group}{$user} = 1;
        } else {
            delete $groups->{$group}{$user};
        }

        my $user_list = join(' ', sort keys %{$groups->{$group}});
        push(@lines, "$group:$user_list\n");
    }

    my $text = join('', @lines);
    my $file = catfile($self->{base_directory}, '.htgroups');
    $self->{webfile_ptr}->writer($file, $text);

    return;
}

#----------------------------------------------------------------------
# Generate a new random password for a user

sub update_password_file {
    my ($self, $user, $word) = @_;

    $word = $self->encrypt($word);

    my $passwords = $self->read_password_file();
    $passwords->{$user} = $word;
    $self->write_password_file($passwords);

    return;
}

#----------------------------------------------------------------------
# Write modified passwords back to disk

sub write_password_file {
    my ($self, $passwords)= @_;

    my @lines;
    foreach my $user (sort keys %$passwords) {
        my $password = $passwords->{$user};
        push(@lines, "$user:$password\n");
    }

    my $text = join('', @lines);
    my $file = catfile($self->{base_directory}, '.htpasswd');
    $self->{webfile_ptr}->writer($file, $text);

    undef $password_cache;
    return;
}

1;
