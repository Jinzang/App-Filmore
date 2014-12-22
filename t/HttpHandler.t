#!/usr/local/bin/perl
use strict;

use Test::More tests => 10;

use Cwd;
use File::Path qw(rmtree);
use File::Spec::Functions qw(catdir catfile rel2abs splitdir);

#----------------------------------------------------------------------
# Load package

my @path = splitdir(rel2abs($0));
pop(@path);
pop(@path);

my $lib = catdir(@path, 'lib');
unshift(@INC, $lib);

$lib = catdir(@path, 't');
unshift(@INC, $lib);

require Filmore::HttpHandler;
require Filmore::Response;

my $base_dir = catdir(@path);
my $test_dir = catdir(@path, 'test');

my $subdir = catfile($test_dir, 'sub');
my $template_dir = $subdir;

rmtree($test_dir);
mkdir $test_dir;

#----------------------------------------------------------------------
# Create object

my $base_url = 'http://www.test.org';
my $script_url = "$base_url/minmax";

my %params = (
                min => 0,
                max => 20,
                protocol => 'text/plain',
                base_url => $base_url,
                base_directory => $base_dir,
                code_ptr => 'MinMax',
             );

chdir ($params{base_directory});
my $o = Filmore::HttpHandler->new(%params);

isa_ok($o, "Filmore::HttpHandler"); # test 1
can_ok($o, qw(run)); # test 2

#----------------------------------------------------------------------
# Process urls

do {
    my $request = {};
    $request = $o->add_urls($request, $script_url);
    my $request_ok = {
                      base_url => '',
                      script_url => '/minmax',
                      };

    is_deeply($request, $request_ok, "Add urls when initialized"); # test 3

    $o->{base_url} = '';
    $o->{script_url} = '';

    $request = {};
    my $bare = Filmore::HttpHandler->new();
    $request = $bare->add_urls($request);
    $request_ok = {
                    base_url => '',
                    script_url => '',
                   };

    is_deeply($request, $request_ok, "Add urls when uninitialized"); # test 4
};

#----------------------------------------------------------------------
# Parse request

do {
    my $params = 'first=1&second=2&third=a&third=b&third=c';
    my $request = $o->parse_request($params);
    
    my $request_ok = {first => 1,
                      second => 2,
                      third => ['a', 'b', 'c'],
                     };

    is_deeply($request, $request_ok, "Parse request"); # test 5 
};

#----------------------------------------------------------------------
# Parse routes

do {
    my $route_table = [
                       {route => '/minmax', code_ptr => 'MinMax'},
                       {route => '/phony/baloney', code_ptr => 'MinMax'},
                       ];

    my $routes = $o->parse_routes($route_table);
    $o->{routes} = $routes;

    foreach my $route (@$routes) {
        is(ref $route->{object}, 'Filmore::FormHandler', "Construct object"); # test 6-7
        delete $route->{object};
    }
    
    my $routes_ok = [{name => 'minmax', path => []},
                     {name => 'phony', path => ['baloney']},
                    ];

    is_deeply($routes, $routes_ok, "Parse routes"); # test 8
};

#----------------------------------------------------------------------
# Generate form

do {
    my $page = <<EOQ;
<html>
<head><title>MinMax</title></head>
<body><p>Value in bounds</p>
<form action="http://www.test.org/minmax">
<div><b>Value</b></div>
<div><input type="text" name="value" value="7" /></div>
<input type="submit" name="cmd" value="Cancel">
<input type="submit" name="cmd" value="Check">
</body>
</html>
EOQ

    my $request = {
                    value => 7,
                    cmd => 'Check',
                    base_url => $base_url,
                    script_url => $script_url,
                    };

    my $route_table = [{route => '/minmax', code_ptr => 'MinMax'}];
    my $routes = $o->parse_routes($route_table);
    $o->{routes} = $routes;
    
    my $response = Filmore::Response->new;
    $response = $o->response($request, $response);

    my $response_ok = {
                        code => 200,
                        content => $page,
                       };
    
    is_deeply($response, $response_ok, "Generate form"); # test 9
};

#----------------------------------------------------------------------
# Read page

do {
    my $page = <<EOQ;
<html>
<head><title>Any Page</title></head>
<body><p>Any Content.</p>
</body>
</html>
EOQ

    my $filename = 'anypage.html';
    my $path = catfile($test_dir, $filename);
    my $page_url = "$base_url/test/$filename";
    $o->{webfile_ptr}->write_wo_validation($path, $page);

    my $request = {
                    base_url => $base_url,
                    script_url => $page_url,
                    };

    my $route_table = [{route => '/minmax', code_ptr => 'MinMax'}];
    my $routes = $o->parse_routes($route_table);
    $o->{routes} = $routes;
    
    my $response = Filmore::Response->new;
    $response = $o->response($request, $response);

    my $response_ok = {
                        code => 200,
                        content => $page,
                       };
    
    is_deeply($response, $response_ok, "Read page"); # test 10
};
