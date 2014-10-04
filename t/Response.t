#!/usr/bin/env perl
use strict;

use Test::More tests => 5;
use File::Spec::Functions qw(catdir catfile rel2abs splitdir);

#----------------------------------------------------------------------
# Load package

my @path = splitdir(rel2abs($0));
pop(@path);
pop(@path);

my $lib = catdir(@path, 'lib');
unshift(@INC, $lib);

require Filmore::Response;
my $r = Filmore::Response->new();

#----------------------------------------------------------------------
# Test code

my $code_ok = 200;
$r->code($code_ok);
my $code = $r->code;

is($code, $code_ok, 'Get/set code'); # test 1

#----------------------------------------------------------------------
# Test content

my $content_ok = "This is a test\n";
$r->content($content_ok);
my $content = $r->content;

is($content, $content_ok, 'Get/set content'); # test 2

#----------------------------------------------------------------------
# Test header

my @header_ok;
my $header_ok = {first => 1, second => 2};

foreach my $field (sort keys %$header_ok) {
    my $value_ok = $header_ok->{$field};
    push(@header_ok, $field, $value_ok);
    
    $r->header($field, $value_ok);
    my $value = $r->header($field);

    is($value, $value_ok, 'Get/set header field'); # test 3-4
}

my $header = $r->header;
is_deeply($header, \@header_ok, 'Get header'); # test 5