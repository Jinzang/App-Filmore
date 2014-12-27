use strict;
use warnings;

package Filmore::UpdateUser;

use lib '../../lib';
use base qw(Filmore::ConfiguredObject);

our $VERSION = '0.01';

use constant DEFAULT_CMD => 'browse';

#----------------------------------------------------------------------
# Set the default parameter values

sub parameters {
    my ($pkg) = @_;

    return (
        browse_ptr => 'Filmore::BrowseUser',
        edit_ptr => 'Filmore::EditUser',
        add_ptr => 'Filmore::AddUser',
        remove_ptr => 'Filmore::RemoveUser',
     );
}

#----------------------------------------------------------------------
# Get the command to run

sub get_command {
    my ($self, $results) = @_;

    my $cmd = $results->{cmd} || '';
    my @commands = (lc($cmd), DEFAULT_CMD);

    foreach my $command (@commands) {
        next unless $command;

        $cmd = $command . '_ptr';
        return $cmd if exists $self->{$cmd};
    }

    die "Default command not defined";
}

#----------------------------------------------------------------------
# Get the information about data fields

sub info_object {
    my ($self, $results) = @_;

    my $cmd = $self->get_command($results);
    return $self->{$cmd}->info_object($results);
}

#----------------------------------------------------------------------
# Read the data to be displayed in the form

sub read_object {
    my ($self, $results) = @_;

    my $cmd = $self->get_command($results);
    $self->{$cmd}->read_object($results);
    return;
}

#----------------------------------------------------------------------
# Get the subtemplate used to render the file

sub template_object {
    my ($self, $results) = @_;

    my $cmd = $self->get_command($results);
    return $self->{$cmd}->template_object($results);
}

#----------------------------------------------------------------------
# Call method to use data gathered from form

sub use_object {
    my ($self, $results) = @_;

    my $cmd = $self->get_command($results);
    return $self->{$cmd}->use_object($results);
}

#----------------------------------------------------------------------
# Call method to validate results if it is present

sub validate_object {
    my ($self, $results) = @_;

    my $cmd = $self->get_command($results);
    return $self->{$cmd}->validate_object($results);
}

1;
