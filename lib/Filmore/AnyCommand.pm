use strict;
use warnings;

package Filmore::AnyCommand;

use lib '../../lib';
use base qw(Filmore::ConfiguredObject);

our $VERSION = '0.01';

use constant DEFAULT_CMD => 'browse';

#----------------------------------------------------------------------
# Set the default parameter values

sub parameters {
    my ($pkg) = @_;

    return (
        default_cmd => '',
     );
}

#----------------------------------------------------------------------
# Get which command to run, the one in the request or the default

sub get_command {
    my ($self, $results) = @_;

    my $command;
    if ($results->{cmd}) {
        my $cmd = lc($results->{cmd}) . '_ptr';
        my %parameters = $self->parameters();

        if (exists $parameters{$cmd}) {
            if ($self->{$cmd}->can('check_id_object')) {
                if ($self->{$cmd}->check_id_object($results)) {
                    $command = $cmd;
                }

            } else {
                $command = $cmd;
            }
        }
    }

    $command ||= $self->{default_cmd} . '_ptr';
    return $command;
}

#----------------------------------------------------------------------
# Get the information about data fields

sub info_object {
    my ($self, $results) = @_;

    my $info;
    my $cmd = $self->get_command($results);

    if ($self->{$cmd}->can('info_object')) {
        $info = $self->{$cmd}->info_object($results);
    } else {
        die "No info about form fields";
    }

    return $info;
}

#----------------------------------------------------------------------
# Read the data to be displayed in the form

sub read_object {
    my ($self, $results) = @_;

    my $cmd = $self->get_command($results);
    if ($self->{$cmd}->can('read_object')) {
        $self->{$cmd}->read_object($results);
    }

    return;
}

#----------------------------------------------------------------------
# Get the subtemplate used to render the file

sub template_object {
    my ($self, $results) = @_;

    my $subtemplate;
    my $cmd = $self->get_command($results);

    if ($self->{$cmd}->can('template_object')) {
        $subtemplate = $self->{$cmd}->template_object($results);
    } else {
        die "No template data";
    }

    return $subtemplate;
}

#----------------------------------------------------------------------
# Call method to use data gathered from form

sub use_object {
    my ($self, $results) = @_;

    my $redirect;
    my $cmd = $self->get_command($results);

    if ($self->{$cmd}->can('use_object')) {
        $redirect = $self->{$cmd}->use_object($results);
    }

    return $redirect;
}

#----------------------------------------------------------------------
# Call method to validate results if it is present

sub validate_object {
    my ($self, $results) = @_;

    my $msg;
    my $cmd = $self->get_command($results);

    if ($self->{$cmd}->can('validate_object')) {
        $msg = $self->{$cmd}->validate_object($results);
    }

    return $msg;
}

1;
