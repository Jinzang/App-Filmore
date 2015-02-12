use strict;
use warnings;

package Filmore::RemoveUser;

use lib '../../lib';
use base qw(Filmore::ConfiguredObject);

our $VERSION = '0.01';

#----------------------------------------------------------------------
# Set the default parameter values

sub parameters {
    my ($pkg) = @_;

    return (
        web_master => '',
        userdata_ptr => 'Filmore::UserData'
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
# Call method to use data gathered from form

sub use_object {
    my ($self, $results) = @_;

    my $redirect = 1;
    my $user = $results->{email};

    $self->{userdata_ptr}->update_groups_file($user, []);

    my $passwords = $self->{userdata_ptr}->read_password_file();
    delete $passwords->{$user};
    $self->{userdata_ptr}->write_password_file($passwords);

    return $redirect;
}

#----------------------------------------------------------------------
# Call method to validate results if it is present

sub validate_object {
    my ($self, $results) = @_;

    my $user = $results->{email};
    return "Cannot remove web master" if $user eq $self->{web_master};

    return;
}

1;
