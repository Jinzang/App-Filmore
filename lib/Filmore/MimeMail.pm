use strict;
use warnings;

#----------------------------------------------------------------------
# Wrapper for MIME_Mail

package Filmore::MimeMail;

use lib '../../lib';
use base qw(Filmore::ConfiguredObject);

our $VERSION = '0.01';

use Filmore::MIME_Lite;

#----------------------------------------------------------------------
# Set the default parameter values

sub parameters {
    my ($pkg) = @_;
    
    return (
        method => 'sendmail',
        attachment_type => 'text/html',
    );
}

#----------------------------------------------------------------------
# Send a mail message with optional attachment

sub send_mail {
    my ($self, $mail_fields, $msg, $attachment) = @_;

    my %mail_fields = (%$mail_fields, 'Type' => 'multipart/mixed');
    my $lite = MIME::Lite->new(%mail_fields);

    $lite->attach(Type =>'TEXT', Data => $msg);  
    $lite->attach(Type => $self->{attachment_type}, Data => $attachment);
    $lite->send($self->{method});
    
    return;
}
