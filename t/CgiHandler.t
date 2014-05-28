#!/usr/local/bin/perl
use strict;

use Test::More tests => 5;

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

my %params = (
                min => 0,
                max => 20,
                protocol => 'text/plain',
                base_url => 'http://www.test.org/',
                script_url => 'test.cgi',
                base_dir => $base_dir,
                data_dir => "$base_dir/data",
                script_dir => "$base_dir/script",
                code_ptr => 'MinMax'
             );

my $o = App::Filmore::CgiHandler->new(%params);

isa_ok($o, "App::Filmore::CgiHandler"); # test 1
can_ok($o, qw(run)); # test 2

my $response = $o->run(value => 15, cmd => 'Check');
like($response, qr/Value in bounds/, "valid request"); # test 3

$response = $o->run(value => 25, cmd => 'Check');
like($response, qr/Value out of bounds/, "invalid request"); # test 4

$response = $o->run(foo => 'bar', cmd => 'Check');
like($response, qr/Required field value is missing/, "empty request"); # test 5
