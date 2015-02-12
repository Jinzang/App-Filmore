use strict;
use warnings;

package Filmore::EditUser;

use lib '../../lib';
use base qw(Filmore::ConfiguredObject);

our $VERSION = '0.01';

use constant INFO_EXT => 'info';

#----------------------------------------------------------------------
# Set the default parameter values

sub parameters {
    my ($pkg) = @_;

    return (
        web_master => '',
        config_ptr => 'Filmore::ConfigFile',
        userdata_ptr => 'Filmore::UserData',
    );
}

#----------------------------------------------------------------------
# Check that the email passed in the request is valid

sub check_id_object {
    my ($self, $results) = @_;

    my $email = $results->{email};
    my $passwords = $self->{userdata_ptr}->read_password_file();

    return exists $passwords->{$email};
}

#----------------------------------------------------------------------
# Get the information about data fields

sub info_object {
    my ($self, $results) = @_;

    my $filename = $self->{config_ptr}->get_filename(INFO_EXT, 'edit_user');
    my @info = $self->{config_ptr}->read_file($filename);

    my $groups = $self->{userdata_ptr}->read_groups_file();
    my $choices =  join('|', sort keys %$groups);

    foreach my $item (@info) {
        if ($item->{name} eq 'group') {
            $item->{valid} = "\&string|$choices|";
        }
    }

    return \@info;
}

#----------------------------------------------------------------------
# Read the data to be displayed in the form

sub read_object {
    my ($self, $results) = @_;

    my @groups;
    my $user = $results->{email};

    if ($user) {
        my $groups = $self->{userdata_ptr}->read_groups_file();

        foreach my $group (sort keys %$groups) {
            push(@groups, $group) if $groups->{$group}{$user};
        }
    }

    $results->{group} = \@groups;
    return;
}

#----------------------------------------------------------------------
# Call method to use data gathered from form

sub use_object {
    my ($self, $results) = @_;

    my $redirect = 1;
    $self->{userdata_ptr}->update_groups_file($results->{email},
                                              $results->{groups});

    return $redirect;
}

#----------------------------------------------------------------------
# Call method to validate results if it is present

sub validate_object {
    my ($self, $results) = @_;

    my $user = $results->{email};
    return "Cannot change web master groups" if $user eq $self->{web_master};

    my $passwords = $self->{userdata_ptr}->read_password_file();
    return "User not found: $user" unless exists $passwords->{$user};

    my $groups = $self->{userdata_ptr}->read_groups_file();
    my %groups = map {$_ => 1} keys %$groups;

    my @groups;
    foreach my $group (@{$results->{group}}) {
        push(@groups, $group) unless exists $groups{$group};
    }

    return "Group not found: " . join(',', @groups) if @groups;

    return;
}

1;
