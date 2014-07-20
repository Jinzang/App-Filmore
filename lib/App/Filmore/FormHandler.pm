use strict;
use warnings;

package App::Filmore::FormHandler;

use lib '../../../lib';
use base qw(App::Filmore::ConfiguredObject);
use IO::File;

our $VERSION = '0.01';

use CGI qw(:cgi-lib :form);
use Cwd;
use File::Spec::Functions qw(abs2rel catfile rel2abs splitdir);
use Scalar::Util qw(looks_like_number);

#----------------------------------------------------------------------
# Set the default parameter values

sub parameters {
    my ($pkg) = @_;
    
    return (
        site_template => '',
        body_tag => 'content',
        template_ptr => 'App::Filmore::SimpleTemplate',
        webfile_ptr => 'App::Filmore::WebFile',
        code_ptr => '',
    );
}

#----------------------------------------------------------------------
# Main procedure

sub run {
    my ($self, $request) = @_;

    my $response = {};
    %$response = %$request;

    $response->{items} = $self->{code_ptr}->info_data($response);
    $self->update_response_items($response, $request);

    my $redirect;
    eval{
        if (exists $response->{cmd}) {
            if (lc($response->{cmd}) eq 'cancel') {
                $redirect = 1;
            } elsif ($self->validate_items($response)) {
                $redirect = $self->perform_data($response);
            } 

        } else {
            $self->read_data($response);        
            $self->update_response_items($response);
        }
    };

    $response->{msg} = $@ if $@;
    
    # Redirect back to edited page if flag is set
    # otherwise generate the form

    if ($redirect) {
        $response->{code} = 302;
        $response->{msg} ||= 'Found';

    } else {
        $response->{code} = 200;
        $response->{msg} ||= '';
        $response->{results} = $self->build_form($response);
    }

    return $response;
}

#----------------------------------------------------------------------
# Build an html field to accept input

sub build_field {
    my ($self, $item) = @_;

    my $args = {};

    # Set default item type and style
    
    $item->{style} = '' unless exists $item->{style};
    $item->{type} = 'text' unless exists $item->{type};

    if (exists $item->{selection}) {
        $item->{type} = 'popup';
        my @selections = split(/\|/, $item->{selection});
        $args->{"-values"} = \@selections;
    }

    # Set arguments passed to subfoutine that generates form field
    
    $args->{"-value"} = $item->{value};
    $args->{"-name"} = $item->{name};

    my @pairs = split(/;/, $item->{style});
    foreach my $pair (@pairs) {
        my ($pair_name, $pair_value) = split(/=/, $pair);
        $pair_value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;

        if ($pair_name eq 'type') {
            $item->{type} = $pair_value;
        } else {
            $args->{"-$pair_name"} = $pair_value;
        }
    }

    my $field;
    if ($item->{type} eq 'text') {
        $field = textfield(%$args);
    } elsif ($item->{type} eq 'textarea') {
        $field = textarea(%$args);
    } elsif ($item->{type} eq 'password') {
        delete $args->{'-value'};
        $field = password_field(%$args);
    } elsif ($item->{type} eq 'file') {
        $field = filefield(%$args);
    } elsif ($item->{type} eq 'submit') {
        delete $args->{"-id"};
        $field = submit(%$args);
    } elsif ($item->{type} eq 'hidden') {
         $field = hidden(%$args);
    } elsif ($item->{type} eq 'popup') {
        $args->{"-default"} ||= $args->{"-value"};
        $field = popup_menu($args->{-name}, $args->{-values}, $args->{-value});
    } elsif ($item->{type} eq 'radio') {
        $args->{"-value"} = [$item->{value}];
        $field = radio_group(%$args);
    } else {
        $field = textfield(%$args);
    }

    $field =~ s/ +/ /g;
    return $field;
}

#---------------------------------------------------------------------------
# Build the form that gats tuser input

sub build_form {
    my ($self, $response) = @_;

    # Add for fields to response
    $response = $self->build_form_fields($response);

    # Figure out which templates we have

    my @templates;   
    push(@templates, $self->{site_template}) if $self->{site_template};
    push(@templates, $self->template_data($response));

    # Generate page

    my $sub = $self->{template_ptr}->compile_code(@templates);
    my $results = &$sub($response);

    return $results;
}

#---------------------------------------------------------------------------
# Add the fields on the form

sub build_form_fields {
    my ($self, $response) = @_;

    foreach my $item (@{$response->{items}}) {
        next if $item->{name} eq 'cmd';
        
        $item->{title} = $item->{title} || ucfirst($item->{name});
        $item->{field} = $self->build_field($item);
    }

    return $response;
}

#----------------------------------------------------------------------
# Get the info about the fields to be displayed in the form

sub info_data {
    my ($self, $response) = @_;
    
    my $info;
    if ($self->{code_ptr}->can('info_data')) {
        $info = $self->{code_ptr}->info_data($response);
    } else {
        die "No info about form fields";
    }

    return $info;
}

#----------------------------------------------------------------------
# Parse the validaion expression

sub parse_validator {
    my ($self, $item) = @_;

    my $valid = $item->{valid} || '';
    $item->{required} = 1 if $valid =~ s/^\&//;
    ($item->{datatype}) = $valid =~ /^\&?(\w+)/;
    $item->{datatype} ||= 'string';
    $valid =~ s/^\w+//;

    my $parsed;
    if ($valid =~ /^[\[\(]/) {
        ($item->{limits}) = $valid =~ /^([\[\(].*[\]\)])$/;
        $parsed = 1 if defined $item->{limits};
    } elsif ($valid =~ /^\|/) {
        ($item->{selection}) = $valid =~ /^\|(.*)\|$/;
        $parsed = 1 if defined $item->{selection};
    } elsif ($valid =~ /^\//) {
        ($item->{regexp}) = $valid =~ /^\/(.*)\/$/;
        $parsed = 1 if defined $item->{regexp};
    } else {
        $parsed = 1 if length($valid) == 0;
    }

    die "Couldn't parse $item->{valid}" unless $parsed;
    return;
}

#----------------------------------------------------------------------
# Call method to perform action on data

sub perform_data {
    my ($self, $response) = @_;
    
    my $redirect;
    if ($self->{code_ptr}->can('perform_data')) {
        $redirect = $self->{code_ptr}->perform_data($response);
    }
    
    return $redirect;
}

#----------------------------------------------------------------------
# Read the file and extract the content, put into response body field

sub populate_items {
    my ($self, $response) = @_;

    my $filename = $self->{webfile_ptr}->url_to_filename($response->{url});
    my $text = $self->{webfile_ptr}->reader($filename);

    my $section = $self->{template_ptr}->parse_sections($text);

    my $body = $section->{$self->{body_tag}};
    $self->{body} = $body;
    
    foreach my $item (@{$response->{items}}) {
        if ($item->{name} eq 'body') {
            $item->{value} = $body;
            last;
        }
    }

    return;
}

#----------------------------------------------------------------------
# Read the data to be displayed in the form

sub read_data {
    my ($self, $response) = @_;
    
    if ($self->{code_ptr}->can('read_data')) {
        $self->{code_ptr}->read_data($response);
    }
    
    return;
}

#----------------------------------------------------------------------
# Get the subtemplate used to render the file

sub template_data {
    my ($self, $response) = @_;
    
    my $subtemplate;
    if ($self->{code_ptr}->can('template_data')) {
        $subtemplate = $self->{code_ptr}->template_data($response);
    } else {
        die "No template data";
    }
    
    return $subtemplate;
}

#----------------------------------------------------------------------
# Remove leading and trailing whitespace from value

sub trim_value {
    my ($self, $value) = @_;
    
    $value =~ s/^\s+//;
    $value =~ s/\s+$//;
    return $value;
}

#----------------------------------------------------------------------
# Initialize the response hash from the request

sub update_response_items {
    my ($self, $response, $request) = @_;
    $request = $response unless defined $request;
    
    foreach my $item (@{$response->{items}}) {
        my $field = $item->{name};
        if (exists $request->{$field}) {
            $item->{value} = $request->{$field};

        } else {
            $response->{$field} = '';
            $item->{value} = '';
        }
    }
   
    return;
}

#----------------------------------------------------------------------
# Validate the datatype of a field

sub valid_datatype {
    my ($self, $item) = @_;
    
    my $flag;
    my $value = $item->{value};
    my $datatype = $item->{datatype};
    
    if ($datatype eq 'email') {
        $flag = $self->valid_email($value);
    } elsif ($datatype eq 'int') {
        $flag = $self->valid_int($value);
    } elsif ($datatype eq 'number') {
        $flag = $self->valid_number($value);
    } elsif ($datatype eq 'string') {
        $flag = 1;
    } elsif ($datatype eq 'url') {
        $flag = $self->valid_url($value);
    } else {
        die "Unrecognized datatype: $datatype\n";
    }
    
    return $flag;
}

#----------------------------------------------------------------------
# Validate an email address

sub valid_email {
    my ($self, $value) = @_;
    
    return $value =~ m#^[\w\-\.\*]{1,100}\@[\w\-\.]{1,100}$#;
}

#----------------------------------------------------------------------
# Validate against integer pattern

sub valid_int {
    my ($self, $value) = @_;
    return $value =~ /^\-?\d+$/;
}

#----------------------------------------------------------------------
# Validate value against limits

sub valid_limits {
    my ($self, $limits, $value) = @_;

    my ($min, $max);
    if ($limits =~ /^\[/) {
        ($min) = $limits =~ /^\[([^,]+),/;
        return if defined $min && $value < $min;
    } elsif ($limits =~  /^\(/) {
        ($min) = $limits =~ /^\(([^,]+),/;
        return if defined $min && $value <= $min;
    }

    if ($limits =~ /\]$/) {
        ($max) = $limits =~ /,([^,]+)\]$/;
        return if defined $max && $value > $max;
    } elsif ($limits =~  /\)$/) {
        ($max) = $limits =~ /,([^,]+)\)$/;
        return if defined $max && $value >= $max;
    }

    die "Couldn't parse $limits" unless defined $min || defined $max;
    return 1;
}

#----------------------------------------------------------------------
# Validate numeric value against limits

sub valid_numeric_limits {
    my ($self, $item) = @_;

    my $limits = $item->{limits};
    my $value = $item->{value};

    return $self->valid_limits($limits, $value);
}    

#----------------------------------------------------------------------
# Validate string value against limits

sub valid_string_limits {
    my ($self, $item) = @_;

    my $value = length $item->{value};
    my $limits = $item->{limits};

    return $self->valid_limits($limits, $value);
}    

#----------------------------------------------------------------------
# Check if the value is a number

sub valid_number {
    my ($self, $value) = @_;

    return looks_like_number($value);
}

#----------------------------------------------------------------------
# Validate value against regular expression

sub valid_regexp {
    my ($self, $item) = @_;
    return $item->{value} =~ /^$item->{regexp}$/;
}

#----------------------------------------------------------------------
# Validate numeric value against list

sub valid_numeric_selection {
    my ($self, $item) = @_;

    my $value = $item->{value};
    my @selections = split(/\|/, $item->{selection});

    foreach my $selection (@selections) {
        return 1 if $selection == $value;
    }

    return;
}

#----------------------------------------------------------------------
# Validate string value against list

sub valid_string_selection {
    my ($self, $item) = @_;

    my $value = $item->{value};
    my @selections = split(/\|/, $item->{selection});

    foreach my $selection (@selections) {
        return 1 if $selection eq $value;
    }

    return;
}

#----------------------------------------------------------------------
# Validate a url

sub valid_url {
    my ($self, $value) = @_;
    
    my $filename = $self->{webfile_ptr}->url_to_filename($value);
    return defined $filename && -e $filename;
}

#----------------------------------------------------------------------
# Validate a single item

sub validate {
    my ($self, $item) = @_;

    my $bad;
    my $numeric = $item->{datatype} eq 'int' || $item->{datatype} eq 'number';

    if (length($item->{value})) {
        $bad ||= $item->{datatype} && ! $self->valid_datatype($item);

        $bad ||= $item->{limits} && $numeric
                 && ! $self->valid_numeric_limits($item);

        $bad ||= $item->{limits} && ! $numeric
                 && ! $self->valid_string_limits($item);

        $bad ||= $item->{selection} && $numeric
                 && ! $self->valid_numeric_selection($item);

        $bad ||= $item->{selection} && ! $numeric
                 && ! $self->valid_string_selection($item);

        $bad ||= $item->{regexp} && ! $self->valid_regexp($item);
    }
        
    return $bad;
}

#----------------------------------------------------------------------
# Call method to validate response if it is present

sub validate_data {
    my ($self, $response) = @_;
    
    my $msg;
    if ($self->{code_ptr}->can('validate_data')) {
        $msg = $self->{code_ptr}->validate_data($response);
    }
    
    return $msg;
}

#----------------------------------------------------------------------
# Validate the items contained on a form

sub validate_items {
    my ($self, $response) = @_;

    my @message;
    foreach my $item (@{$response->{items}}) {
        $self->parse_validator($item);

        my $msg;
        if ($item->{required} && length $item->{value} == 0) {
            $msg = "Required field $item->{name} is missing";

        } elsif ($self->validate($item)) {
            $msg = $item->{msg} || "Invalid data in $item->{name} field";
        }

        push(@message, $msg) if $msg;
    }

    my $msg = $self->validate_data($response);
    push(@message, $msg) if $msg;
    
    $response->{msg} = join("<br>\n", @message) if @message;
    return @message ? 0 : 1;
}

1;
