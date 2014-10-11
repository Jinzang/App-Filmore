use strict;
use warnings;

package Filmore::MailPage;

use lib '../../lib';
use base qw(Filmore::FormMail);

our $VERSION = '0.01';

use Cwd;
use File::Spec::Functions qw(abs2rel catfile rel2abs splitdir);

#----------------------------------------------------------------------
# Set the default parameter values

sub parameters {
    my ($pkg) = @_;
    
    return (
        web_master => '',
        info_extension => 'info',
        mail_extension => 'mail',
        template_extension => 'htm',
        body_tag => 'content',
        template_directory => 'templates',
        template_ptr => 'Filmore::SimpleTemplate',
        webfile_ptr => 'Filmore::WebFile',
        mime_ptr => 'Filmore::MimeMail',
    );
}

#----------------------------------------------------------------------
# Build the complete web page from the response body field

sub build_web_page {
    my ($self, $attachment_name, $response) = @_;

    my $text = $self->{webfile_ptr}->reader($attachment_name);
    
    my $section = {$self->{body_tag} => $response->{body}};
    return $self->{template_ptr}->substitute_sections($text, $section);
}

#----------------------------------------------------------------------
# Read data from file into form

sub read_object {
    my ($self, $response) = @_;

    my $filename = $self->{webfile_ptr}->url_to_filename($response->{url});
    my $text = $self->{webfile_ptr}->reader($filename);
    die "Couldn't read filename: $filename" unless $text;
    
    my $section = $self->{template_ptr}->parse_sections($text);
    $response->{body} = $section->{$self->{body_tag}};
    
    return;
}

#----------------------------------------------------------------------
# Send mail message when request is correct

sub use_object {
    my ($self, $response) = @_;
    
    my $attachment_name =
        $self->{webfile_ptr}->url_to_filename($response->{url});
 
    my $mail_fields = $self->build_mail_fields($response);
    my $attachment = $self->build_web_page($attachment_name, $response);

    $self->{mime_ptr}->send_mail($mail_fields, $attachment, $attachment_name);
    return 1;
}

1;
