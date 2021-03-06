use strict;
use warnings;

package Filmore::ChangePassword;

use lib '../../lib';
use base qw(Filmore::ConfiguredObject);

our $VERSION = '0.01';

#----------------------------------------------------------------------
# Set the default parameter values

sub parameters {
    my ($pkg) = @_;

    return (
        mime_ptr => 'Filmore::MimeMail',
        userdata_ptr => 'Filmore::UserData',
        template_ptr => 'Filmore::SimpleTemplate',
    );
}

#----------------------------------------------------------------------
# Check that the email passed in the request is valid

sub check_id_object {
    my ($self, $results) = @_;

    my $passwords = $self->{userdata_ptr}->read_password_file();
    my $email = $self->find_email($results->{id}, $passwords);

    return defined $email;
}

#----------------------------------------------------------------------
# Find the email that matches the id

sub find_email {
    my ($self, $id, $passwords) = @_;

    foreach my $email (keys %$passwords) {
        my $password = $passwords->{$email};
        my $hash = $self->{userdata_ptr}->hash_string($email, $password);
        return $email if $id eq $hash;
    }

    return;
}

#----------------------------------------------------------------------
# Call method to use data gathered from form

sub use_object {
    my ($self, $results) = @_;

    my $redirect = 1;

    my $passwords = $self->{userdata_ptr}->read_password_file();
    my $email = $self->find_email($results->{id}, $passwords);
    $self->{userdata_ptr}->update_password_file($email,
                                                $results->{password1});

    return $redirect;
}

#----------------------------------------------------------------------
# Call method to validate results if it is present

sub validate_object {
    my ($self, $results) = @_;

    my $msg;
    if ($results->{password1} ne $results->{password2}) {
        $msg = 'Passwords do not match';
    }

    return $msg;
}

1;
