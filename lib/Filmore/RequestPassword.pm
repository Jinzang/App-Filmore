use strict;
use warnings;

package Filmore::RequestPassword;

use lib '../../lib';
use base qw(Filmore::ConfiguredObject);

our $VERSION = '0.01';

#----------------------------------------------------------------------
# Set the default parameter values

sub parameters {
    my ($pkg) = @_;

    return (
        web_master => '',
        mime_ptr => 'Filmore::MimeMail',
        userdata_ptr => 'Filmore::UserData',
        template_ptr => 'Filmore::SimpleTemplate',
    );
}

#----------------------------------------------------------------------
# Buid the id string to send with the request

sub build_id {
    my ($self, $email) = @_;

    my $passwords = $self->{userdata_ptr}->read_password_file();
    my $id = $self->{userdata_ptr}->hash_string($email, $passwords->{$email});

    return $id;
}

#----------------------------------------------------------------------
# Construct the parts of a mail message

sub build_mail_fields {
    my ($self, $results) = @_;

    my $template = <<'EOQ';
A request was made to change the password for the account $email.
on the website $base_url. If you did not make this request, ignore
this message. If you did, go to

$script_url?id=$id

to change your password.
EOQ

    my $mail_fields = {};
    $mail_fields->{to} = $results->{email};
    $mail_fields->{from} = $self->{web_master};
    $mail_fields->{subject} = 'Password change request';

    my $sub = $self->{template_ptr}->construct_code($template);
    $mail_fields->{body} = &$sub($results);

    return $mail_fields;
}

#----------------------------------------------------------------------
# Call method to use data gathered from form

sub use_object {
    my ($self, $results) = @_;

    my $redirect = 0;
    my $email = $results->{email};

    $results->{msg} = "A password change request has been sent to $email";
    $results->{id} = $self->build_id($email);

    my $mail_fields = $self->build_mail_fields($results);
    $self->{mime_ptr}->send_mail($mail_fields);

    return $redirect;
}

#----------------------------------------------------------------------
# Call method to validate results if it is present

sub validate_object {
    my ($self, $results) = @_;

    my $msg;
    my $email = $results->{email} || '';
    my $passwords = $self->{userdata_ptr}->read_password_file();

    $msg = "Not the email of a registered user"
        unless exists $passwords->{$email};

    return $msg;
}

1;
