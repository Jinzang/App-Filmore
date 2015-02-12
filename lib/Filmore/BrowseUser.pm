use strict;
use warnings;

package Filmore::BrowseUser;

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
# Get the information about data fields

sub info_object {
    my ($self, $results) = @_;

    my $filename = $self->{config_ptr}->get_filename(INFO_EXT, 'browse_user');
    my @info = $self->{config_ptr}->read_file($filename);

    my $passwords = $self->{userdata_ptr}->read_password_file();
    delete $passwords->{$self->{web_master}};

    my $users = join('|', sort keys %$passwords);

    foreach my $item (@info) {
        if ($item->{name} eq 'email') {
            $item->{valid} = "\&string|$users|";
        }
    }

    return \@info;
}

#----------------------------------------------------------------------
# Call method to use data gathered from form

sub use_object {
    my ($self, $results) = @_;

    my $redirect = 0;
    return $redirect;
}

1;
