use strict;
use warnings;

package Filmore::AddUser;

use lib '../../lib';
use base qw(Filmore::EditUser);

our $VERSION = '0.01';

#----------------------------------------------------------------------
# Set the default parameter values

sub parameters {
    my ($pkg) = @_;

    return (
        userdata_ptr => 'Filmore::UserData'
    );
}

#----------------------------------------------------------------------
# Read the data to be displayed in the form

sub read_object {
    my ($self, $results) = @_;
    return;
}

#----------------------------------------------------------------------
# Call method to use data gathered from form

sub use_object {
    my ($self, $results) = @_;

    my $redirect = 1;
    $self->{userdata_ptr}->update_groups_file($results->{email},
                                              $results->{groups});

    ## TODO add password method
    return $redirect;
}

#----------------------------------------------------------------------
# Call method to validate results if it is present

sub validate_object {
    my ($self, $results) = @_;

    my $user = $results->{email};
    my $passwords = $self->{userdata_ptr}->read_password_file();
    return "User already exists: $user" if exists $passwords->{$user};

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
