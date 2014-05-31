#!/usr/local/bin/perl
use strict;

use Test::More tests => 11;

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

require App::Filmore::CgiHandler;

my $base_dir = catdir(@path, 'test');
my $subdir = catfile($base_dir, 'sub');
my $template_dir = $subdir;

rmtree($base_dir);
mkdir $base_dir;

#----------------------------------------------------------------------
# Create object

my $base_url = 'http://www.test.org';

my %params = (
                min => 0,
                max => 20,
                protocol => 'text/plain',
                base_url => $base_url,
                script_url => "$base_url/script/test.cgi",
                base_dir => $base_dir,
                data_dir => "$base_dir/data",
                script_dir => "$base_dir/script",
                code_ptr => 'MinMax'
             );

my $o = App::Filmore::CgiHandler->new(%params);

isa_ok($o, "App::Filmore::CgiHandler"); # test 1
can_ok($o, qw(run)); # test 2

#----------------------------------------------------------------------
# Test url manipulation

do {
    my $parsed_url = $o->parse_url($params{script_url});
    my $parsed_url_ok = {method => 'http:', domain => 'www.test.org',
                         path => '/script', file => 'test.cgi'};

    is_deeply($parsed_url, $parsed_url_ok, 'Parse complete url'); # test 3
    
    $parsed_url = $o->parse_url('/script/test.cgi');
    $parsed_url_ok->{domain} = '';
    is_deeply($parsed_url, $parsed_url_ok, 'Parse partial url'); # test 4

    my $url = "$base_url/index.html";
    my $result = $o->terminate_url($url);
    is($result, $url, 'Terminate url with filename'); # test 5
    
    $result = $o->terminate_url($base_url);
    is($result, "$params{base_url}/", 'Terminate url with no filename'); # test 6

    $url = '/';
    $result = $o->terminate_url($url);
    is($result, $url, 'Terminate single slash url'); # test 7
    
    $result = $o->base_url($base_url);
    is($result, "$base_url/", 'Compute base url from directory'); # test 8

    $result = $o->base_url($params{script_url});
    is($result, "$base_url/script/", 'Compute base url from file'); # test 9
};

#----------------------------------------------------------------------
# Process urls

do {
    my $request = {};
    $request = $o->read_urls($request);
    my $request_ok = {base_url => "$base_url/",
                      referer_url => "$base_url/",
                      script_base_url => "$base_url/script/",
                      script_url => "$base_url/script/test.cgi",
                     };
    is_deeply($request, $request_ok, "Read urls when initialized"); # test 10

    $o->{base_url} = '';

    $request = {};
    my $bare = App::Filmore::CgiHandler->new();
    $request = $bare->read_urls($request);
    $request_ok = {base_url => '/t/',
                   referer_url => '/t/',
                   script_base_url => '/t/',
                   script_url => '/t/CgiHandler.t',
                  };
    is_deeply($request, $request_ok, "Read urls when uninitialized"); # test 11
};
