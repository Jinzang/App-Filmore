#!/usr/local/bin/perl
use strict;

use Test::More tests => 6;

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

require Filmore::CgiHandler;

my $test_dir = catdir(@path, 'test');
my $base_dir = catdir(@path, 't');

my $subdir = catfile($test_dir, 'sub');
my $template_dir = $subdir;

rmtree($test_dir);
mkdir $test_dir;

#----------------------------------------------------------------------
# Create object

my $base_url = 'http://www.test.org';

my %params = (
                min => 0,
                max => 20,
                protocol => 'text/plain',
                base_url => $base_url,
                base_directory => $base_dir,
                code_ptr => 'MinMax'
                
             );

my $o = Filmore::CgiHandler->new(%params);

isa_ok($o, "Filmore::CgiHandler"); # test 1
can_ok($o, qw(run)); # test 2

#----------------------------------------------------------------------
# Process urls

do {
    my $request = {};
    $request = $o->add_urls($request);
    my $request_ok = {
                      base_url => $base_url,
                      script_url => "$base_url/CgiHandler.t",
                      };

    is_deeply($request, $request_ok, "Add urls when initialized"); # test 3

    $o->{base_url} = '';
    $o->{script_url} = '';

    $request = {};
    my $bare = Filmore::CgiHandler->new();
    $request = $bare->add_urls($request);
    $request_ok = {
                    base_url => '',
                    script_url => '/t/CgiHandler.t',
                   };

    is_deeply($request, $request_ok, "Add urls when uninitialized"); # test 4
};

#----------------------------------------------------------------------
# Parse request

do {
    my $array = join("\000", qw(a b c));
    my %args = (first => 1, second => 2, third => $array);
 
    $o->{base_url} = $base_url;
    my $request = $o->request(%args);
    
    my $request_ok = {first => 1,
                      second => 2,
                      third => ['a', 'b', 'c'],
                      base_url => $base_url,
                      script_url => "$base_url/CgiHandler.t",
                     };

    is_deeply($request, $request_ok, "Parse request"); # test 5 
};

#----------------------------------------------------------------------
# Handle response

do {
    my $page = <<EOQ;
<html>
<head><title>MinMax</title></head>
<body><p>Value in bounds</p>
<form action="http://www.test.org/CgiHandler.t">
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
                    script_url => "$base_url/CgiHandler.t",
                    };
    
    my $response = $o->response($request);

    my $response_ok = {
                        code => 200,
                        content => $page,
                       };
    
    is_deeply($response, $response_ok, "Generate response"); # test 6
};
