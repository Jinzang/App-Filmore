#!/usr/bin/env perl
use strict;

use Test::More tests => 47;

use Cwd;
use IO::File;
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

require Filmore::FormHandler;
require MinMax;

my $base_dir = catdir(@path, 'test');

rmtree($base_dir);
mkdir $base_dir;
chdir $base_dir;
$base_dir = getcwd();

my $config_file = "$base_dir/config.cfg";
my $fh = Filmore::FormHandler->new(code_ptr => 'MinMax');

#----------------------------------------------------------------------
# Create object

do {
    my $item = {valid => ''};
    my $item_ok = {valid => '', datatype => 'string'};

	$fh->parse_validator($item);
	is_deeply($item, $item_ok, "Empty validator"); # Test 1
};

do {
    my $item = {valid => 'number'};
    my $item_ok = {valid => 'number', datatype => 'number'};

	$fh->parse_validator($item);
	is_deeply($item, $item_ok, "Number validator"); # Test 2

    $item->{value} = '';
	my $b = $fh->validate($item);
	is($b, undef, "Validate empty number"); # Test 3

    $item->{value} = '23';
	$b = $fh->validate($item);
	is($b, undef, "Validate naumber"); # Test 4

    $item->{value} = 'a23';
	$b = $fh->validate($item);
	is($b, 1, "Validate non-naumber"); # Test 5
};

do {
    my $item = {valid => '&number'};
    my $item_ok = {valid => '&number', datatype => 'number', required => 1};

	$fh->parse_validator($item);
	is_deeply($item, $item_ok, "Required number validator"); # Test 6

    $item->{value} = '23';
	$b = $fh->validate($item);
	is($b, undef, "Validate required naumber"); # Test 7
};

do {
    my $item = {valid => '/\$\d+\.\d\d/'};
    my $item_ok = {valid => '/\$\d+\.\d\d/', regexp => '\$\d+\.\d\d',
                   datatype => 'string'};

	$fh->parse_validator($item);
	is_deeply($item, $item_ok, "String regexp"); # Test 8

    $item->{value} = '$317.43';
	my $b = $fh->validate($item);
	is($b, '', "Validate valid regexp string"); # Test 9

    $item->{value} = '$24';
	$b = $fh->validate($item);
	is($b, 1, "Validate invalid regexp string"); # Test 10
};

do {
    my $item = {valid => '|joe|jack|jim|'};
    my $item_ok = {valid => '|joe|jack|jim|', selection => 'joe|jack|jim',
                   datatype => 'string'};

	$fh->parse_validator($item);
	is_deeply($item, $item_ok, "String selector"); # Test 11

    $item->{value} = 'jack';
	my $b = $fh->validate($item);
	is($b, undef, "Validate valid selector string"); # Test 12

    $item->{value} = 'jason';
	$b = $fh->validate($item);
	is($b, 1, "Validate invalid selector string"); # Test 13
};

do {
    my $item = {valid => 'number|10|20|30|'};
    my $item_ok = {valid => 'number|10|20|30|', datatype => 'number',
                   selection => '10|20|30'};

	$fh->parse_validator($item);
	is_deeply($item, $item_ok, "Number selector"); # Test 14

    $item->{value} = '10.0';
	my $b = $fh->validate($item);
	is($b, undef, "Validate valid number selector string"); # Test 15

    $item->{value} = '15';
	$b = $fh->validate($item);
	is($b, 1, "Validate invalid number selector string"); # Test 16
};

do {
    my $item = {valid => 'number[10,30]'};
    my $item_ok = {valid => 'number[10,30]', datatype => 'number',
                   limits => '[10,30]'};

	$fh->parse_validator($item);
	is_deeply($item, $item_ok, "Number limits"); # Test 17

    $item->{value} = '10.0';
	my $b = $fh->validate($item);
	is($b, undef, "Validate lower numeric limit string"); # Test 18

    $item->{value} = '15.0';
	$b = $fh->validate($item);
	is($b, undef, "Validate intermediate numeric limit string"); # Test 19

    $item->{value} = '20.0';
	$b = $fh->validate($item);
	is($b, undef, "Validate upper numeric limit string"); # Test 20

    $item->{value} = '5';
	$b = $fh->validate($item);
	is($b, 1, "Validate outside numeric limit string"); # Test 21
};

do {
    my $item = {valid => 'number(10,30)'};
    my $item_ok = {valid => 'number(10,30)', datatype => 'number',
                   limits => '(10,30)'};

	$fh->parse_validator($item);
	is_deeply($item, $item_ok, "Open numeric limits"); # Test 22

    $item->{value} = '10.0';
	my $b = $fh->validate($item);
	is($b, 1, "Validate lower open numeric limit string"); # Test 23

    $item->{value} = '15.0';
	$b = $fh->validate($item);
	is($b, undef, "Validate intermediate open numeric limit string"); # Test 24

    $item->{value} = '20.0';
	$b = $fh->validate($item);
	is($b, undef, "Validate upper open numeric limit string"); # Test 25

    $item->{value} = '5';
	$b = $fh->validate($item);
	is($b, 1, "Validate outside numeric limit string"); # Test 26
};

do {
    my $item = {valid => 'number(0,)'};
    my $item_ok = {valid => 'number(0,)', datatype => 'number',
                   limits => '(0,)'};

	$fh->parse_validator($item);
	is_deeply($item, $item_ok, "Open numeric one sided limits"); # Test 27

    $item->{value} = '0.0';
	my $b = $fh->validate($item);
	is($b, 1, "Validate lower open one sided numeric limit string"); # Test 28

    $item->{value} = '5.0';
	$b = $fh->validate($item);
	is($b, undef, "Validate intermediate open one sided numeric limit string"); # Test 29

    $item->{value} = '-10';
	$b = $fh->validate($item);
	is($b, 1, "Validate outside numeric limit string"); # Test 30
};

do {
    my $item = {valid => 'number[,9]'};
    my $item_ok = {valid => 'number[,9]', datatype => 'number',
                   limits => '[,9]'};

	$fh->parse_validator($item);
	is_deeply($item, $item_ok, "Closed numeric one sided limits"); # Test 31

    $item->{value} = '5.0';
	my $b = $fh->validate($item);
	is($b, undef, "Validate intermediate closed one sided numeric limit string"); # Test 32

    $item->{value} = '9.0';
	$b = $fh->validate($item);
	is($b, undef, "Validate upper closed one sided numeric limit string"); # Test 33

    $item->{value} = '10';
	$b = $fh->validate($item);
	is($b, 1, "Validate outside closed numeric limit string"); # Test 34
};

do {
    my $item = {valid => 'string[5,]'};
    my $item_ok = {valid => 'string[5,]', datatype => 'string',
                   limits => '[5,]'};

	$fh->parse_validator($item);
	is_deeply($item, $item_ok, "String one sided limits"); # Test 35

    $item->{value} = '12345';
	my $b = $fh->validate($item);
	is($b, undef, "Validate valid string length"); # Test 36

    $item->{value} = '1234';
	$b = $fh->validate($item);
	is($b, 1, "Validate invalid string length"); # Test 37
};

do {
    my $item = {valid => 'string[5,]', name => 'foo', value => 'bar'};

    $fh->parse_validator($item);
    my $field = $fh->build_field($item);
    is($field, '<input type="text" name="foo" value="bar" />',
       "Form text field"); # Test 38

    $item->{type} = 'textarea';
    $field = $fh->build_field($item);
    is($field, '<textarea name="foo" >bar</textarea>',
       "Form textarea"); # Test 39

    $item->{style} = 'rows=20;cols=64';
    $field = $fh->build_field($item);
    is($field,
       '<textarea name="foo" rows="20" cols="64">bar</textarea>',
       "Form textarea with style"); # Test 40

    delete $item->{type};
    delete $item->{style};
    delete $item->{limits};
    $item->{valid} = 'string|bar|biz|baz|';
    $fh->parse_validator($item);

    $field = $fh->build_field($item);
    my $r = <<EOQ;
<select name="foo" >
<option selected="selected" value="bar">bar</option>
<option value="biz">biz</option>
<option value="baz">baz</option>
</select>
EOQ
    chomp $r;
    is($field, $r, "Form selection"); # Test 41

    delete $item->{type};
    delete $item->{style};
    delete $item->{limits};
    $item->{type} = 'radio';
    $item->{valid} = 'string|bar|biz|baz|';
    $fh->parse_validator($item);

    $field = $fh->build_field($item);
    $r = <<EOQ;
<label><input type="radio" name="foo" value="bar" checked="checked" />bar</label>
<label><input type="radio" name="foo" value="biz" />biz</label>
<label><input type="radio" name="foo" value="baz" />baz</label>
EOQ
    chomp $r;
    $r =~ s/\n/ /g;
    is($field, $r, "Form radio buttons"); # Test 42

    delete $item->{type};
    delete $item->{style};
    delete $item->{limits};
    $item->{type} = 'checkbox';
    $item->{valid} = 'string|bar|biz|baz|';
    $fh->parse_validator($item);

    $field = $fh->build_field($item);
    $r = <<EOQ;
<label><input type="checkbox" name="foo" value="bar" checked="checked" />bar</label>
<label><input type="checkbox" name="foo" value="biz" />biz</label>
<label><input type="checkbox" name="foo" value="baz" />baz</label>
EOQ
    chomp $r;
    $r =~ s/\n/ /g;
    is($field, $r, "Form checkboxes"); # Test 43
};

do {
    my $request = {
                   script_url => 'http://www.example.com/test.cgi',
                   cmd => 'Check',
                   };

    $request->{value} = 7;
    my $response = $fh->run($request);
    like($response->content, qr/Value in bounds/,
         "Run valid request"); # test 44

    $request->{value} = 25;
    $response = $fh->run($request);
    like($response->content, qr/Value out of bounds/,
         "Run invalid request"); # test 45

    delete $request->{value};
    $response = $fh->run($request);
    like($response->content, qr/Required field value is missing/,
         "Run empty request"); # test 46

    delete $request->{cmd};
    $response = $fh->run($request);
    like($response->content, qr/Please enter a value/,
         "Run request with no commands"); # test 47

};
