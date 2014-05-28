use strict;
use warnings;

#----------------------------------------------------------------------
# A wrapper for a class that handles a CGI request (Handler)
# Handler must have a run method

package App::Filmore::CgiHandler;

use lib '../../../lib';
use base qw(App::Filmore::ConfiguredObject);
use IO::File;

use Data::Dumper;
use File::Spec::Functions qw(rel2abs);


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

#----------------------------------------------------------------------
# Set default values

sub parameters {
  my ($pkg) = @_;

    return (
            base_dir => '',
            base_url => '',
            script_url => '',
            script_dir => '',
            detail_errors => 1,
            protocol => 'text/html',
            form_ptr => 'App::Filmore::FormHandler',
	);
}

#----------------------------------------------------------------------
# Extract the base of a url

sub base_url {
    my ($self, $url) = @_;

    $url = $self->terminate_url($url);
    $url =~ s![^/]+$!!;

    return $url;
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
# Read selected environment variables into request

sub read_env {
    my ($self, $request) = @_;

	foreach my $field (qw(path_info remote_user)) {
		my $ufield = uc($field);

		if (exists $ENV{$ufield}) {
			$request->{$field} = $ENV{$ufield};
		} else {
			delete $request->{$field};
		}
	}

	return $request;
}

#----------------------------------------------------------------------
# Read urls from environment

sub read_urls {
    my ($self, $request) = @_;

    if (length $self->{script_url}) {
        $request->{script_url} = $self->{script_url};

    } else {
        my ($script_url) = split (/\?/, $ENV{SCRIPT_URI});
        die "Can't get script url"  unless length($script_url);
        $request->{script_url} = $script_url;
    }

    $request->{script_url} = $self->terminate_url($request->{script_url});
    $request->{script_base_url} = $self->base_url($request->{script_url});

    if (length $self->{base_url}) {
        $request->{base_url} = $self->{base_url};

    } else {
        my $base_url = $request->{script_url};

        my @base_path = split(m{/}, $base_url);
        pop @base_path;
        
        $base_url = join("/", @base_path);
        $request->{base_url} = $base_url;
    }

    $request->{base_url} = $self->terminate_url($request->{base_url});

    $request->{referer_url} = $ENV{HTTP_REFERER} || $request->{base_url};
    $request->{referer_url} = $self->terminate_url($request->{referer_url});

    return $request;
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
    $request = $self->read_env($request);
    $request = $self->read_urls($request);

    return $request;
}

#----------------------------------------------------------------------
# Call the handler to get the response to the request

sub response {
    my ($self, $request) = @_;

    my $response;
    my $result;

    eval {
        # Relocate to base directory, if defined

        if (length $self->{base_dir}) {
            my $dir = $self->untaint_filename($self->{base_dir});
            chdir($dir) or die "Couldn't move to $dir: $!\n";
        }

        # Run the procedure with input checking, if provided
        $response = $self->{form_ptr}->run($request);

        # Extract results

        if ($response->{code} < 300) {
            $result = $response->{results};
    	} elsif ($response->{code} < 400) {
            $self->redirect($request, $response);
        } else {
            die $response->{msg};
        }
    };

    # Catch errors and report them

    if ($@) {
        my $error = $@;
        my $coded_request = $self->encode_hash($request);
        $result = $self->error($coded_request, $error);
    };

    return $result;
}

#----------------------------------------------------------------------
# Run the cgi script, print the result

sub run {
    my ($self, %args) = @_;

    my $request = $self->request(%args);
    my $result = $self->response($request);

    if (! %args) {
        print "Content-type: $self->{protocol}\n\n";
        print $result;
    }

    return $result;
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

#----------------------------------------------------------------------
# Make sure urls are properly terminated with a slash

sub terminate_url {
    my ($self, $url) = @_;

    my ($file) = $url =~ m!([^/]*)$!;
    $url .= '/' if defined($file) && length($file) && $file !~ /\./;

    return $url;
}

#----------------------------------------------------------------------
# Make sure filename passes taint check

sub untaint_filename {
    my ($self, $filename) = @_;

    $filename = rel2abs($filename);
    ($filename) = $filename =~ m{^([\w\-\.\/\\]+)$};

    return $filename;
}

1;
