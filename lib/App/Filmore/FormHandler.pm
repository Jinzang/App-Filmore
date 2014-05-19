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
        base_directory => '',
        base_url => '',
        form_extension => 'form',
        field_extension => 'field',
        web_extension => 'html',
        body_tag => 'content',
        template_directory => 'templates',
        bad_message => 'One or more fields in the form are incorrect: $bad_fields',
        ok_message => 'Your edited page has been sent for review. Return to the <a href="$url">unedited page</a>.',
        template_ptr => 'App::Filmore::SimpleTemplate',
        responder_ptr => '',
    );
}

#----------------------------------------------------------------------
# Main procedure

sub run {
    my ($self, $request) = @_;

    my $response = $self->initialize_response($request);

    my $redirect;
    eval{$redirect = $self->generate_response($response)};
    $response->{message} = $@ if $@;
    
    # Redirect back to edited page if flag is set
    
    if ($redirect) {
        print "Location: $response->{url}\n\n";
        return;
    }

    my $output = $self->build_form($response);
    return $output;
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
    $args->{"-id"} = "$item->{name}-field";

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
        $field = popup_menu(%$args);
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
    
    my $text = $self->read_template($response, $self->{form_extension});
    my $section = $self->{template_ptr}->parse_sections($text);

    # Substitute any sections in the response into the template
    
    my $changed;
    foreach my $field (keys %$section) {
        next unless exists $response->{$field};
        
        $section->{$field} = $response->{$field};
        $changed = 1;
    }
    
    # Reconstruct the template if a section was changed
    
    $text = $self->{template_ptr}->substitute_sections($text, $section)
        if $changed;

    # Generate output page and print it

    my $sub = $self->{template_ptr}->construct_code($text);
    my $output = &$sub($response);

    return $output;
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
# Build the complete web page from the response body field

sub build_web_page {
    my ($self, $response) = @_;

    my $filename = $self->url_to_filename($response->{url});
    my $text = $self->slurp($filename);
    
    my $section = {$response->{body_tag} => $response->{body}};
    return $self->{template_ptr}->substitute_sections($text, $section);
}

#----------------------------------------------------------------------
# Generate the response, either a form or mail message

sub generate_response {
    my ($self, $response) = @_;
    
    if (! $self->valid_url($response->{url})) {
        $response->{url} = $response->{base_url};
        return 1;
    }
    
    if ($response->{cmd} eq 'Cancel') {
        return 1;
    }

    if ($response->{cmd} eq 'Mail') {
        if ($self->validate_items($response)) {
            $self->{responder_ptr}->run($response);
            $response->{message} = $response->{ok_message};
            return;
        }
    }
    
    $self->populate_items($response);    
    return;
}

#----------------------------------------------------------------------
# Get info about form mail application

sub get_info {
    my ($self, $response) = @_;

    my $id;
    my $field;

    my $item;
    my %prior;
    my @items;
    
    my $text = $self->read_template($response, $self->{field_extension});
    my @lines = split(/\n/, $text);
    
    while (defined($_ = shift @lines)) {
        if (/^\s*#/) {
            # Comment line
            undef $field;
            
        } elsif (/^\s*\[([^\]]*)\]/) {
            if (defined $id) {
                push(@items, $item);
            } else {
                die "No field defined for info";
            }
            $item = {};
            
            # new id
            $id = lc($1);
            if (exists $prior{$id}) {                
                die "Duplicate ids: $id\n" 
            } else {
                $prior{$id} = 1;
                $item->{name} = $id;
            }

        } elsif (/^[A-Z_]+\s*=/) {
            # new field definition
            my $value;
            ($field, $value) = split (/\s*=\s*/, $_, 2);
            $field = lc($field);
            $value =~ s/\s+$//;
            
            if (exists $item->{$field}) {
                if (ref $item->{$field}) {
                    push(@{$item->{$field}}, $value);
                } else {
                    $item->{$field} = [$item->{$field}, $value];
                }

            } else {
                $item->{$field} = $value;
            }

        } else {
            # continuation of info field
            die "Undefined field\n" . substr($_, 20) . "\n"
                unless defined $field;

            s/\s+$//;    
            $item->{$field} .= "\n$_";
        }
    }

    push(@items, $item) if %$item;    
    return \@items;
}

#----------------------------------------------------------------------
# Initialize the response hash from the request

sub initialize_response {
    my ($self, $request) = @_;
    
    my @response_items;
    my %response = %$request;
    $response{items} = $self->get_info(\%response);

    foreach my $item (@{$response{items}}) {
        my $field = $item->{name};
        $response{$field} = exists $request->{$field}
                              ? $request->{$field} : '';

        $item->{value} = $request->{$field};
        push(@response_items, $item);
    }

    $response{base_url} =~ s!/[^/]*$!!;

    my $base_directory = $self->{base_directory} || cwd();
    $response{script_file} = join('/', $response{base_url},
                               splitdir(abs2rel($0, $base_directory)));
    
    return \%response;
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
# Read the file and extract the content, put into response body field

sub populate_items {
    my ($self, $response) = @_;

    my $filename = $self->url_to_filename($response->{url});
    my $text = $self->slurp($filename);

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
# Read a template from the templates directory

sub read_template {
    my ($self, $response, $ext) = @_;

    my ($dir, $script_name) = $self->split_filename($0);
    my ($script_base, $script_ext) = split(/\./, $script_name);

    my $template_name = catfile($self->{template_directory},
                                "$script_base.$ext");
    
    my $template = $self->slurp($template_name);
    die "Couldn't read template: $template_name" unless length $template;
    
    return $template;
}

#----------------------------------------------------------------------
# Read a file into a string

sub slurp {
    my ($self, $input) = @_;

    my $in;
    local $/;

    if (ref $input) {
        $in = $input;
    } else {
        $in = IO::File->new ($input);
        return '' unless defined $in;
    }

    my $text = <$in>;
    $in->close;

    return $text;
}

#----------------------------------------------------------------------
# Split off basename from rest of filename

sub split_filename {
    my ($self, $filename) = @_;

    my @dirs = splitdir($filename);
    my $basename = pop(@dirs);

    my $dir = catfile(@dirs) || '';
    return ($dir, $basename);
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
# Convert url to filename, return undef if can't

sub url_to_filename {
    my ($self, $url) = @_;

    my $base_url = $self->{base_url};
    my $web_extension = $self->{web_extension};
    
    my ($file) = $url =~ /^$base_url([\w\-\/]+\.$web_extension)$/;
    return unless $file;

    $file = rel2abs($file, $self->{base_directory});
    return $file;
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
# Validate an email address

sub valid_url {
    my ($self, $value) = @_;
    
    my $filename = $self->url_to_filename($value);
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

    } else {
        $bad = $item->{required};
    }
        
    return $bad;
}

#----------------------------------------------------------------------
# Validate the items contained on a form

sub validate_items {
    my ($self, $response) = @_;

    my @bad_fields;
    foreach my $item (@{$response->{items}}) {
        my $bad = $self->validate($item);
        push(@bad_fields, $item->{name}) if $bad;
    }

    if (@bad_fields) {
        $response->{bad_fields} = join(',', @bad_fields);
        $response->{message} = $self->{bad_message};
    }

    return @bad_fields ? 0 : 1;
}

1;
