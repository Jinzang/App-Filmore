use strict;
use warnings;

#----------------------------------------------------------------------
# A wrapper for a class that handles a CGI request (Handler)
# Handler must have a run method

package Filmore::CgiHandler;

use lib '../../lib';
use base qw(Filmore::ConfiguredObject);
use IO::File;

use Data::Dumper;
use File::Spec::Functions qw(abs2rel rel2abs splitdir);
use Filmore::Response;

#----------------------------------------------------------------------
# Configuration

use constant DEFAULT_TEMPLATE => <<'EOS';
<head><title>Script Error</title></head>
<body>
<h1>Script Error</h1>
<p>Please report this error to the developer.</p>
<pre>$(error)</pre>
</body></html>
EOS

use constant DEFAULT_DETAIL_TEMPLATE => <<'EOS';
<html>
<head><title>Script Error</title></head>
<body>
<h1>Script Error</h1>
<p>Please report this error to the developer.</p>
<pre>$(error)</pre>
<h2>REQUEST</h2>
$(request)
</body>
</html>
EOS

use constant RESPONSE_MSG => {
    200 => 'OK',
    302 => 'Found',
    400 => 'Invalid Request',
    401 => 'Unauthorized',
    404 => 'File Not Found',
    500 => 'Script Error',
};

#----------------------------------------------------------------------
# Set default values

sub parameters {
  my ($pkg) = @_;

    return (
            base_directory => '',
            base_url => '',
            detail_errors => 1,
            protocol => 'text/html',
            form_ptr => 'Filmore::FormHandler',
            webfile_ptr => 'Filmore::WebFile',
	);
}

#----------------------------------------------------------------------
# Run the cgi script, print the result

sub run {
    my ($self, %args) = @_;

    my ($request, $response);
    eval {
        $request = $self->request(%args);
        $response = $self->response($request);
    };
    
    if ($@) {
        $response ||= Filmore::Response->new;
        $response->content($self->error($request, $@));
        $response->code(200);
    }

    $self->send_response($response) unless %args;
    return $response->content || '';
}

#----------------------------------------------------------------------
# Add urls and directories to request

sub add_urls {
    my ($self, $request) = @_;
    
    my $path = rel2abs($0);
    my ($directory, $filename) = $self->{webfile_ptr}->split_filename($path);

    $request->{script_directory} = $directory;

    $request->{base_directory} = $self->{base_directory} ||
                                 $request->{script_directory};

    if ($self->{base_url}) {
        $request->{base_url} = $self->{base_url};
        $request->{base_url} =~ s/\/$//;
    } else {
        $request->{base_url} = '';
    }
    
    $request->{script_url} ||=
        $self->{webfile_ptr}->filename_to_url($path, $request->{base_url});

    return $request;
}

#----------------------------------------------------------------------
# Create a new hash with html elements encoded

sub encode_hash {
    my ($self, $value) = @_;
    return unless defined $value;

    my $new_value;
	if (ref $value eq 'HASH') {
        $new_value = {};
        while (my ($name, $subvalue) = each %$value) {
            $new_value->{$name} = $self->encode_hash($subvalue);
        }

	} elsif (ref $value eq 'ARRAY') {
	    $new_value = [];
	    foreach my $subvalue (@$value) {
            push(@$new_value, $self->encode_hash($subvalue));
	    }

	} else {
        $new_value = $value;
	    $new_value =~ s/&/&amp;/g;
	    $new_value =~ s/</&lt;/g;
	    $new_value =~ s/>/&gt;/g;
    }

    return $new_value;
}

#----------------------------------------------------------------------
# Fallback error routine in case form_ptr's is missing or doesn't work

sub error {
    my($self, $request, @errors) = @_;

    # TODO: don't do this!
    $self->{protocol} = 'text/html';

    my $template;
    my $data = {};
    $data->{error} = join("\n", @errors);

    if ($self->{detail_errors}) {
        $data->{request} = $request;
        $template = DEFAULT_DETAIL_TEMPLATE;

    } else {
        $template = DEFAULT_TEMPLATE;
    }

    my $result = $self->render($template, $data);
    return $result;
}

#----------------------------------------------------------------------
# Redirect to a url after running request

sub redirect {
    my ($self, $request, $response) = @_;
    
    my $cgi = CGI->new();
    my $url = $response->{url} || $request->{referer_url};
    print $cgi->redirect($url);
    exit 0;
}

#----------------------------------------------------------------------
# Default renderer

sub render {
    my ($self, $template, $data) = @_;

    my $result = $template;
    $result =~ s/\$\((\w+)\)/$self->substitute($data, $1)/ge;

    return $result;
}

#----------------------------------------------------------------------
# Get arguments used in handling cgi request

sub request {
    my ($self, %args) = @_;

    # %args is an optional hash containg request parameters
    # that is used for debugging
    my %request = %args;
    if (! %request) {
        my $cgi = CGI->new();
        %request = $cgi->Vars();
    }

    # Split request parameters when they are arrays

    foreach my $field (keys %request) {
        next unless $request{$field} =~ /\000/;
        my @array = split(/\000/, $request{$field});
        $request{$field} = \@array;
    }

    my $request = \%request;
    $request = $self->add_urls($request);

    return $request;
}

#----------------------------------------------------------------------
# Call the handler to get the response to the request

sub response {
    my ($self, $request) = @_;

    my $result;
    my $response = Filmore::Response->new();

    eval {
        # Relocate to base directory, if defined

        if (length $self->{base_directory}) {
            my $dir =
                $self->{webfile_ptr}->untaint_filename($self->{base_directory});
            chdir($dir) or die "Couldn't move to $dir: $!\n";
        }

        # Run the procedure with input checking, if provided
        $response = $self->{form_ptr}->run($request, $response);
    };

    # Catch errors and report them

    if ($@) {
        my $error = $@;
        my $coded_request = $self->encode_hash($request);

        $response->code(200);
        $response->content($self->error($coded_request, $error));
    };

    return $response;
}

#----------------------------------------------------------------------
# Stringify response and print to stdout

sub send_response {
    my ($self, $response) = @_;    

    my $code = $response->code;
    my $response_msg = RESPONSE_MSG;
    my $msg = $response_msg->{$code};

    print "HTTP/1.0 $code $msg\r\n";
    print "Content-type: $self->{protocol}\r\n";
    
    $response->header('Content_Length', length($self->content)) if $self->content;
    my $header = $response->header;

    while (@$header) {
        my $field = shift @$header;
        my $value = shift @$header;
        $field = join('-', map {ucfirst $_} split('_', $field));
        print "$field: $value\r\n";
    }

    print "\r\n";
    print $response->content if $response->content;
    
    return;
}

#----------------------------------------------------------------------
# Substitute for data for macro in template

sub substitute {
    my ($self, $data, $field) = @_;

    my $value = '';
    if (exists $data->{$field}) {
        if (ref $data->{$field}) {
            my $dumper = Data::Dumper->new([$data->{$field}], [$field]);
            $value = "<pre>\n" . $dumper->Dump() . "</pre>\n";
        } else {
            $value = $data->{$field};
        }
    }

    return $value;
}

1;
