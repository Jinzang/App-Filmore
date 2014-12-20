use strict;
use warnings;

#----------------------------------------------------------------------
# Wrapper for sendmail command

package Filmore::Sendmail;

use lib '../../lib';
use base qw(Filmore::ConfiguredObject);

our $VERSION = '0.01';
use IO::File;

our $fd;

#----------------------------------------------------------------------
# Set the default parameter values

sub parameters {
    my ($pkg) = @_;
    
    return (
        sendmail_command => '/usr/sbin/sendmail',
        sendmail_flags => '-oi -t -odq',
    );
}

#----------------------------------------------------------------------
# Close the pipe

sub close_mail {
    my ($self) = @_;

    close $fd if $fd;
    undef $fd;
    
    return;
}

#----------------------------------------------------------------------
# Open a pipe to sendmail command

sub open_mail {
    my ($self) = @_;

    close $fd if $fd;
    my $command = join(' ', $self->{sendmail_command}, 
                            $self->{sendmail_flags});
    
    $fd = IO::File->new("|$command");
    die "Couldn't find sendmail command: self->{sendmail_command}" unless $fd;

    return;
}

#----------------------------------------------------------------------
# Print a line to the pipe

sub print_mail {
    my ($self, $text) = @_;
    
    $self->open_mail unless $fd;
    print $fd $text;
    
    return;
}

1;
