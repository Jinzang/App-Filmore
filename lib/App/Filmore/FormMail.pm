use strict;
use warnings;

package App::Filmore::FormMail;

use lib '../../../lib';
use base qw(App::Filmore::ConfiguredObject);

our $VERSION = '0.01';

use Cwd;
use File::Spec::Functions qw(abs2rel catfile rel2abs splitdir);

use constant DEFAULT_MAIL_TEMPLATE => <<'EOQ';
Edited version of $url was submitted by $email

$note
EOQ

#----------------------------------------------------------------------
# Set the default parameter values

sub parameters {
    my ($pkg) = @_;
    
    return (
        web_master => '',
        info_extension => 'info',
        template_extension => 'htm',
        body_tag => 'content',
        template_directory => 'templates',
        mail_template => DEFAULT_MAIL_TEMPLATE,
        template_ptr => 'App::Filmore::SimpleTemplate',
        webfile_ptr => 'App::Filmore::WebFile',
        mime_ptr => 'App::Filmore::MimeMail',
    );
}

#----------------------------------------------------------------------
# Build the body of the mail message

sub build_mail_fields {
    my ($self, $response) = @_;

    my %mail_fields;
    $mail_fields{to} = $self->{web_master};
    $mail_fields{from} = $response->{email};
    $mail_fields{subject} = 'Edited web page';

    return \%mail_fields;
}

#----------------------------------------------------------------------
# Build the body of the mail message

sub build_mail_message {
    my ($self, $response) = @_;

    if ($response->{note}) {
        $response->{note} = "\n" . $response->{note};
    } else {
        $response->{note} = '';
    }

    my $template = $self->{mail_template};
    my $sub = $self->{template_ptr}->construct_code($template);
    my $msg = &$sub($response);

    return $msg;
}

#----------------------------------------------------------------------
# Build the complete web page from the response body field

sub build_web_page {
    my ($self, $response) = @_;

    my $attachment_name =
        $self->{webfile_ptr}->url_to_filename($response->{url});
    my $text = $self->{webfile_ptr}->reader($attachment_name);
    
    my $section = {$self->{body_tag} => $response->{body}};
    return $self->{template_ptr}->substitute_sections($text, $section);
}

#----------------------------------------------------------------------
# Return info about form parameters

sub info_data {
    my ($self, $response) = @_;

    my $filename = $self->template_filename($self->{info_extension});
    my $text = $self->{webfile_ptr}->reader($filename);    
    my @lines = split(/\n/, $text);
    
    my @info;
    my $field;
    my %fields;
    my $item = {};

    while (defined ($_ = shift @lines)) {
        if (/^\s*#/) {
            # Comment line
            undef $field;
            
        } elsif (/^\s*\[([^\]]*)\]/) {
            push(@info, $item) if %$item;
            $item = {};
            
            # new id
            my $id = lc($1);
            $item->{name} = $id;

            die "Duplicate id in info file: $id" if $fields{$id};
            $fields{$id} = 1;
            
        } elsif (/^\w+\s*=/) {
            # new field definition
            my $value;
            ($field, $value) = split (/\s*=\s*/, $_, 2);
            $field = lc($field);
            $value =~ s/\s+$//;
            
            die "Missing value for field: $field" unless length $value;
            die "Duplicate field in info file: $field" if exists $item->{$field};
            
            $item->{$field} = $value;

        } else {
            # continuation of registry field
            die "Undefined field\n" . substr($_, 20) . "\n"
                unless defined $field;

            s/\s+$//;    
            $item->{$field} .= "\n$_";
        }
    }

    push(@info, $item) if %$item;
    return \@info;
}

#----------------------------------------------------------------------
# Read data from file into form

sub read_data {
    my ($self, $response) = @_;

    my $filename = $self->{webfile_ptr}->url_to_filename($response->{url});
    my $text = $self->{webfile_ptr}->reader($filename);
    die "Couldn't read filename: $filename" unless $text;
    
    my $section = $self->{template_ptr}->parse_sections($text);
    $response->{body} = $section->{$self->{body_tag}};
    
    return;
}

#----------------------------------------------------------------------
# Return the template used to render the result

sub template_data {
    my ($self, $response) = @_;

    my $filename = $self->template_filename($self->{template_extension});
    my $text = $self->{webfile_ptr}->reader($filename);
    die "Couldn't read template" unless length $text;
    
    return $text;
}

#----------------------------------------------------------------------
# Read a template from the templates directory

sub template_filename {
    my ($self, $ext) = @_;

    my ($dir, $script_name) = $self->{webfile_ptr}->split_filename($0);
    my ($script_base, $script_ext) = split(/\./, $script_name);

    my $template_name = catfile($self->{template_directory},
                                "$script_base.$ext");
        
    return rel2abs($template_name);
}

#----------------------------------------------------------------------
# Send mail message when request is correct

sub write_data {
    my ($self, $response) = @_;
    
    my $mail_fields = $self->build_mail_fields($response);

    my $attachment = $self->build_web_page($response);
    my $msg = $self->build_mail_message($response);

    $self->{mime_ptr}->send_mail($mail_fields, $msg, $attachment);
    return;
}

1;
