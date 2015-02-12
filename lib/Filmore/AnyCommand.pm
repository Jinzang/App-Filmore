use strict;
use warnings;

package Filmore::AnyCommand;

use lib '../../lib';
use base qw(Filmore::ConfiguredObject);

our $VERSION = '0.01';

use constant INFO_EXT => 'info';
use constant TEMPLATE_EXT => 'htm';

#----------------------------------------------------------------------
# Set the default parameter values

sub parameters {
    my ($pkg) = @_;

    return (
        config_ptr => 'Filmore::ConfigFile',
        webfile_ptr => 'Filmore::WebFile',
     );
}

#----------------------------------------------------------------------
# Convert the command pointer name to a configuration file name

sub configuration_name {
    my ($self, $cmd) = @_;

    my @config = split('::', ref($self->{$cmd}));
    my $config = pop @config;

    $config =~ s/([A-Z])/'_' . lc($1)/eg;
    $config =~ s/^_//;

    return $config;
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
        my $base = $self->configuration_name($cmd);
        my $filename = $self->{config_ptr}->get_filename(INFO_EXT, $base);
        my @info = $self->{config_ptr}->read_file($filename);
        $info = \@info;
    }

    my $nonce_info = {name => 'nonce',
                      type=> 'hidden',
                      valid => '&nonce',
                      msg => 'Time outerror, please resubmit',
                      };

    $nonce_info->{value} = $self->{webfile_ptr}->get_nonce();
    unshift(@$info, $nonce_info);

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
        my $fd;
        my $base = $self->configuration_name($cmd);
        my $filename= $self->{config_ptr}->get_filename(TEMPLATE_EXT, $base);

        $fd = IO::File->new($filename, 'r') or die "$!: $filename\n";
        $subtemplate = do {local $/; <$fd>};
        close($fd);
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
