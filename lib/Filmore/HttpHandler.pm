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
use File::Spec::Functions qw(abs2rel catfile rel2abs splitdir);
use Filmore::FormHandler;

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
            log_file => '',
            index_file => 'index.html',
            webfile_ptr => 'Filmore::WebFile',
	);
}

#----------------------------------------------------------------------
# Start the http server

sub run {
    my ($self, $route_table) = @_;

    $| = 1;
    $SIG{CHLD} = 'IGNORE';
    $self->{webfile_ptr}->relocate($self->{base_directory});
    $self->{routes} = $self->parse_routes($route_table);
    
    my $d = HTTP::Daemon->new(
                              Reuse => 1,
                              LocalAddr => '127.0.0.1',
                              LocalPort => $self->{port},
                             );

    $self->log("Start $0");
    while (my $connection = $d->accept) {
        next unless $self->{nofork} || ! fork();

        eval {$self->handle_connection($connection)};
        $self->log($@) if $@;

        exit unless $self->{nofork};
    }
    
    $self->log("End $0");
    return;
}

#----------------------------------------------------------------------
# Add urls and directories to request

sub add_urls {
    my ($self, $request, $url) = @_;
    $url = '/' unless defined $url;
    
    my $parsed_url = $self->{webfile_ptr}->parse_url($url);
    $request->{script_url} = $parsed_url->{path};

    my @script_path = split('/', $parsed_url->{path});
    pop(@script_path);
        
    $request->{base_url} = join('/', @script_path);
    
    return $request;
}

#----------------------------------------------------------------------
# Build date fields from time, based on Blosxom 3

sub build_date {
    my ($self) = @_;
    
    my @time =  split(/\W+/, localtime(time()));

    my $date =  sprintf("%02d:%02d:%02d %02d %s %02d",
                        $time[3], $time[4], $time[5],
                        $time[2], $time[1], $time[6] % 100);

    return $date;
}

#----------------------------------------------------------------------
# Handle a request that has come in

sub handle_connection {
    local $SIG{PIPE} = 'IGNORE';
    my ($self, $connection) = @_;

    while (my $r = $connection->get_request()) {
        my ($request, $response);
        eval {
            $request = $self->request($r);
            $response = HTTP::Response->new();
            $response = $self->response($request, $response);
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

    my $parsed_url = $self->{webfile_ptr}->parse_url($request->{script_url});
    my ($front, @path) = split(/\//, $parsed_url->{path});

    my $file = catfile($self->{base_directory}, @path, $parsed_url->{file});
    $file = catfile($file, $self->{index_file}) if -d $file;

    my $ok;
    $file = abs2rel($file);
    if ($file !~ /\.\./ && -e $file) {
        # Copy file into response

        my $fd = IO::File->new($file, 'r');
        if (defined $fd) {
            $ok = 1;
            local $/;

            binmode $fd;
            $response->content(<$fd>);
            close($fd);
        }
    }
    
    if ($ok) {
        $response->code(200);
    } else {
        $response->code(404);
    }
    
    return $response;
};

#----------------------------------------------------------------------
# Write a message to the log file

sub log {
    my ($self, $msg) = @_;
    
    my $file = $self->{log};
    my $fd = IO::File->new($self->{log}, 'a');
    my $date = $self->build_date();
    
    if ($fd) {
        print $fd "$date $msg\n";
    } else {
        print "$date $msg\n";
    }
    

    return;
}

#----------------------------------------------------------------------
# Parse information in the request

sub parse_request {
    my ($self, $params) = @_;
    
    my $request = {};
    if ($params) {
        $params =~ s/\+/ /g;
        my @params = split(/&/, $params);

        foreach my $param (@params) {
            my ($field, $value) = split(/=/, $param, 2);
            $value = 1 unless defined $value;

            $value =~ s/%([0-9a-fA-F][0-9a-fA-F])/chr(hex($1))/eg;
            $self->set_request($request, $field, $value);
        }
    }

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
        
        my $object = Filmore::FormHandler->new(%$entry);
        push(@routes, {name => $name, path =>\@path, object => $object});
    }

    return \@routes;
}

#----------------------------------------------------------------------
# Parse information in the request

sub request {
    my ($self, $r) = @_;
        
    # Parse the script parameters

    my $params;  
    my $method = uc($r->method);

    if ($method eq 'GET') {
        $params = $1; 

    } elsif ($method eq 'POST') {
        $params = $r->content;
    }

    my $request = $self->parse_request($params);

    my $url = $r->url;
    $request = $self->add_urls($request, $url);

    return $request;
}

#----------------------------------------------------------------------
# Generate the response for the request

sub response {
    my ($self, $request, $response) = @_;

    my $handler = $self->route_request($request);
    if ($handler) {
        $response = $handler->run($request, $response);
    } else {
        $response = $self->handle_file($request, $response);
    }

    return $response;    
}

#----------------------------------------------------------------------
# Determine the handler to handle the request

sub route_request {
    my ($self, $request) = @_;

    my $parsed_url = $self->{webfile_ptr}->parse_url($request->{script_url});
    my ($front, $name, @extra_path) = split(/\//, $parsed_url->{path});
    
    foreach my $route (@{$self->{routes}}) {
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
    my ($self, $request, $field, $value) = @_;

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
