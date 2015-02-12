use strict;
use warnings;

package Filmore::AddUser;

use lib '../../lib';
use base qw(Filmore::ConfiguredObject);

our $VERSION = '0.01';

use constant INFO_EXT => 'info';

#----------------------------------------------------------------------
# Set the default parameter values

sub parameters {
    my ($pkg) = @_;

    return (
        mime_ptr => 'Filmore::MimeMail',
        config_ptr => 'Filmore::ConfigFile',
        userdata_ptr => 'Filmore::UserData',
        template_ptr => 'Filmore::SimpleTemplate',
    );
}

#----------------------------------------------------------------------
# Construct the parts of a mail message

sub build_mail_fields {
    my ($self, $results) = @_;

    my $template = <<'EOQ';
You have been added to the list of peope to edit
the website $base_url. Pleas go to

$script_url?id=$id

to set your password.
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
# Get the information about data fields

sub info_object {
    my ($self, $results) = @_;

    my $filename = $self->{config_ptr}->get_filename(INFO_EXT, 'add_user');
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

    $results->{nonce} = $self->{userdata_ptr}->get__nonce();
    return;
}

#----------------------------------------------------------------------
# Call method to use data gathered from form

sub use_object {
    my ($self, $results) = @_;

    my $redirect = 1;
    my $word = $self->{userdata_ptr}->random_string(12);

    $self->{userdata_ptr}->update_password_file($results->{email},
                                                $word);

    $self->{userdata_ptr}->update_groups_file($results->{email},
                                              $results->{groups});

    my $mail_fields = $self->build_mail_fields($results);
    $self->{mime_ptr}->send_mail($mail_fields);

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
