use strict;
use warnings;

package Filmore::FormMail;

use lib '../../lib';
use base qw(Filmore::ConfiguredObject);

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
# Build the body of the mail message

sub build_mail_fields {
    my ($self, $response) = @_;

    my $text = $self->template_object($response, $self->{mail_extension});
    my $mail_fields = $self->parse_info($text);

    $mail_fields->{to} ||= $self->{web_master};
    $mail_fields->{from} ||= $response->{email};
    $mail_fields->{subject} ||= 'Message';

    my $sub = $self->{template_ptr}->construct_code($mail_fields->{template});
    $mail_fields->{body} = &$sub($response);

    delete $mail_fields->{template};
    return $mail_fields;
}

#----------------------------------------------------------------------
# Return info about form parameters

sub info_object {
    my ($self, $response) = @_;

    my $text = $self->template_object($response, $self->{info_extension});
    my $info = $self->parse_info($text, 1);
    return $info;
}

#----------------------------------------------------------------------
# Return info about form parameters

sub parse_info {
    my ($self, $text, $id_tags) = @_;

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
            die "Id is not allowed: $1" unless $id_tags;

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

    if ($id_tags) {
        push(@info, $item) if %$item;
        return \@info;
    } else {
        return $item;
    }
}

#----------------------------------------------------------------------
# Read the data to be displayed (stub)

sub read_object {
    my ($self, $results) = @_;

    return;
}

#----------------------------------------------------------------------
# Return the template used to render the mail message

sub template_object {
    my ($self, $response, $ext) = @_;

    my $filename = $self->template_filename($ext);
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

sub use_object {
    my ($self, $response) = @_;

    my $mail_fields = $self->build_mail_fields($response);
    $self->{mime_ptr}->send_mail($mail_fields);

    return 1;
}

#----------------------------------------------------------------------
# Validate mail fields (stub)

sub validate_object {
    my ($self, $response) = @_;

    return 1;
}

1;
