use strict;
use warnings;

package Filmore::UserData;

use lib '../../lib';
use base qw(Filmore::ConfiguredObject);

use File::Spec::Functions qw(catfile rel2abs abs2rel splitdir);

our $VERSION = '0.01';

#----------------------------------------------------------------------
# Set the default parameter values

sub parameters {
    my ($pkg) = @_;

    return (
        base_directory => '',
        webfile_ptr => 'Filmore::WebFile',
    );
}

#----------------------------------------------------------------------
# Encrypt password

sub encrypt {
    my ($self, $plain) = @_;;

    my $salt = join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];
    return crypt($plain, $salt);
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

    my $passwords = {};
    my $file = catfile($self->{base_directory}, '.htpasswd');
    my $text = $self->{webfile_ptr}->reader($file);

    if ($text) {
        my @lines = split("\n", $text);
        foreach (@lines) {
            my ($user, $password) = split(/\s*:\s*/, $_, 2);
            next unless $password;

            $passwords->{$user} = $password;
        }
    }

    return $passwords;
 }

#----------------------------------------------------------------------
# Write group file for password protected site

sub write_groups_file {
    my ($self, $request) = @_;

    my @lines;
    my $groups = $self->read_groups_file();

    my $user = $request->{user};
    my %request_groups = map {$_ => 1} @{$request->{groups}};

    foreach my $group (sort keys %$groups) {
        if ($request_groups{$group}) {
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
# Write password file

sub write_password_file {
    my ($self, $request, $delete)= @_;

    my $passwords = $self->read_password_file();

    if ($delete) {
        delete $passwords->{$request->{user}};
    } else {
        $passwords->{$request->{user}} = $self->encrypt($request->{pass1});
    }

    my @lines;
    foreach my $user (sort keys %$passwords) {
        my $password = $passwords->{$user};
        push(@lines, "$user:$password\n");
    }

    my $text = join('', @lines);
    my $file = catfile($self->{base_directory}, '.htpasswd');
    $self->{webfile_ptr}->writer($file, $text);

    return;
}

1;
