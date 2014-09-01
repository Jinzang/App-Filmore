use strict;
use warnings;

#----------------------------------------------------------------------
# A wrapper for a class that handles an HTTP request (Handler)
# Handler must have a run method

package Filmore::HttpHandler;

use lib '../../lib';
use base qw(Filmore::ConfiguredObject);

use IO::File;
use HTTP::Daemon;
use HTTP::Request;
use HTTP::Response;
use File::Spec::Functions qw(abs2rel rel2abs splitdir);

use constant ERROR_TEMPLATE => <<'EOS';
<head><title>Script Error</title></head>
<body>
<h1>Script Error</h1>
<p>Please report this error to the developer.</p>
<pre>%%</pre>
</body></html>
EOS

#----------------------------------------------------------------------
# Set default values

sub parameters {
  my ($pkg) = @_;

    return (
            base_directory => '',
            nofork => 0,
            port => 8080,
            index_file => 'index.html',
	);
}

#----------------------------------------------------------------------
# Start the http server

sub run {
    my ($self, $route_table) = @_;

    $| = 1;
    $SIG{CHLD} = 'IGNORE';
    chdir ($self->{base_directory});
    
    my $routes = $self->parse_routes($route_table);
    
    my $d = HTTP::Daemon->new(
                              Reuse => 1,
                              LocalAddr => '127.0.0.1',
                              LocalPort => $self->{port},
                             );

    while (my $connection = $d->accept) {
        next unless $self->{nofork} || ! fork();

        $self->handle_connection($connection, $routes);
        exit unless $self->{nofork};
    }
    
    return;
}

#----------------------------------------------------------------------
# Handle a request that has come in

sub handle_connection {
    local $SIG{PIPE} = 'IGNORE';
    my ($self, $connection, $routes) = @_;

    while (my $r = $connection->get_request()) {
        my $request = $self->parse_request($r);
        my $handler = $self->route_request($routes, $request);

        my $response = HTTP::Response->new();
        eval {
            if ($handler) {
                $response = $handler->run($request, $response);
            } else {
                $response = $self->handle_file($request, $response);
            }
        };
        
        if ($@) {
            my $error = $@;
            my $content = ERROR_TEMPLATE;
            $content =~ s/%%/$error/;
            
            $response->code(200);
            $response->content($content);
        }
        
        $self->send_response($connection, $response);
    }

    $connection->close;
}

#----------------------------------------------------------------------
# Get the file contents for the response - or not

sub handle_file {
    my ($self, $request, $response) = @_;
    
    my @path = split(/\//, $request->{url});
    my $file = catfile($self->{base_directory}, @path);
    $file = catfile($file, $self->{index_file}) if -d $file;

    my $ok;
    $file = abs2rel($file);
    if ($file !~ /^\.\./ && -e $file) {
        # Copy file into response

        my $fd = new IO::File($file. 'r');
        if (defined $fd) {
            $ok = 1;
            local $/;

            binmode $fd;
            $response->content(<$fd>);
        }

        close($fd);
    }
    
    if ($ok) {
        $response->code(200);
        $response->message('Ok');
    } else {
        $response->code(404);
        $response->message('Not found');
    }
    
    return $response;
};

#----------------------------------------------------------------------
# Parse information in the request

sub parse_request {
    my ($self, $r) = @_;
        
    # Parse the script parameters

    my $method = uc($r->method);
    my $url = $r->url;

    my $params;  
    if ($method eq 'GET') {
        $url =~ s/\?([^\?]*)$//;
        $params = $1; 

    } elsif ($method eq 'POST') {
        $params = $r->content;
    }

    my $request = {};
    if ($params) {
        $params =~ s/\+/ /g;
        my @params = split(/&/, $params);

        foreach my $param (@params) {
            my ($field, $value) = split(/=/, $param, 2);
            $value = 1 unless defined $value;

            $value =~ s/%([0-9a-fA-F][0-9a-fA-F])/chr(hex($1))/eg;
            set_request($request, $field, $value);
        }
    }

    $url =~ s/\#[^\#]*$//;
    $request->{script_url} = $url;

    return $request;
}

#----------------------------------------------------------------------
# Parse the route table into a list of objects to handle routes

sub parse_routes {
    my ($self, $route_table) = @_;
    
    my @routes;
    foreach my $entry (@$route_table) {
        die "No route for entry" unless exists $entry->{route};
        die "No code for $entry->{route}" unless exists $entry->{code_ptr};

        my $route = $entry->{route};
        $route =~ s/^\///;

        my ($name, @path) = split(/\//, $route);
        
        delete $entry->{route};        
        $entry->{config_file} = "$name.cfg";
        $entry->{base_directory} ||= $self->{base_directory};
        
        my $object = Filmore::FormHandlder->new($entry);
        push(@routes, {name => $name, path =>\@path, object => $object});
    }

    return \@routes;
}

#----------------------------------------------------------------------
# Determine the handler to handle the request

sub route_request {
    my ($self, $routes, $request) = @_;

    my ($name, @extra_path) = split(/\//, $request->{script_url});
    
    foreach my $route (@$routes) {
        next unless $route->{name} eq $name;

        foreach my $field (@{$route->{path}}) {
            set_request($request, $field, shift @extra_path);
        }
        set_request($request, 'extra_path', \@extra_path) if @extra_path;

        return $route->{object};
    }

    return;
}

#----------------------------------------------------------------------
# Send the response

sub send_response {
    my ($self, $connection, $response) = @_;

    $response->header('Content_Length', length($self->content)) if $self->content;
    $connection->send_response($response);

    return;
}

#----------------------------------------------------------------------
# Set a field in the request

sub set_request {
    my ($request, $field, $value) = @_;

    if (exists $request->{$field}) {
        if (ref $request->{$field}) {
            push(@{$request->{$field}}, $value);
        } else {
            $request->{$field} = [$request->{$field}, $value];
        }

    } else {
        $request->{$field} = $value;
    }

    return;
}
1;
