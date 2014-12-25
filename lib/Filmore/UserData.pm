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
#Write modified passwords back to disk

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

    return;
}

1;
