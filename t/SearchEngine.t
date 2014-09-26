#!/usr/bin/env perl
use strict;

use Test::More tests => 8;

use IO::File;
use File::Path qw(rmtree);
use File::Spec::Functions qw(catdir catfile rel2abs splitdir);

#----------------------------------------------------------------------
# Load the package and create test directory and object

my @path = splitdir(rel2abs($0));
pop(@path);
pop(@path);

my $lib = catdir(@path, 'lib');
unshift(@INC, $lib);

require Filmore::SearchEngine;

my $test_dir = catdir(@path, 'test');

rmtree($test_dir);
mkdir $test_dir;
chdir($test_dir);

my %params = (valid_write => [$test_dir]);
my $se = Filmore::SearchEngine->new(%params);

#----------------------------------------------------------------------
# Create test data

do {
    my $template = <<'EOQ';
<html>
<head>
<title>Page %1</title>
</head>
<body>
  <!-- section content -->
  <p>This is the
  %2 page. It is not the fourth page.</p> 
  <!-- endsection content -->  
</body>
</html>
EOQ

    for my $count (qw(first second third)) {
        my $text = $template;
        my $ucount = ucfirst($count);
        $text =~ s/%1/$ucount/g;
        $text =~ s/%2/$count/g;

        my $file = "$count.html";
        my $out = IO::File->new($file, 'w');
        print $out $text;
        close $out;
    }
};

#----------------------------------------------------------------------
# Test globbify

do {
    my $pattern = ['*.html', '*.pdf'];
    my $result = $se->globbify($pattern);
    is($result, '(^.*\.html$)|(^.*\.pdf$)', 'globbify'); # test 1
};

#----------------------------------------------------------------------
# Test encode_url

do {
    my $title = 'My Title';
    my $summary = '"My Summary"';
    my $url = 'http://www.example/com/search.cgi';
    my %param = (title => $title, summary => $summary);
    
    my $result = $se->encode_url($url, %param);
    my $result_ok = "$url?summary=$summary&title=$title";
    $result_ok =~ s/ /+/g;
    $result_ok =~ s/\"/%22/g;
    
    is($result, $result_ok, 'encode_url'); # test 2
};

#----------------------------------------------------------------------
# Test get_context

do {
    my $text = 'aa bbb cc ' x 8;
    $text .= 'dd eee ff ' x 4;
    $text .= 'gg hhh ii ' x 8;
    
    my $result_ok = 'aa bbb cc ' x 4;
    $result_ok .= 'dd eee ff ' x 4;
    $result_ok =~ s/dd/<b>dd<\/b>/g;
    $result_ok =~ s/^aa //;
    $result_ok =~ s/\s+$//;
    
    my $result = $se->get_context($text, 'dd', 80);
    is($result, $result_ok, 'get_context');  #test 3 
};

#----------------------------------------------------------------------
# Test parse_htmldoc

do {
    my $text =<<'EOQ';
<html>
<head>
<!-- section header -->
<title>My Title</title>
<!-- endsection header -->
</head>
<body>
<!-- section content -->
<p>My content.</p>
<!-- endsection content -->  
</body>
</html>
EOQ

    my $template =<<'EOQ';
<html>
<head>
<meta charset="utf-8">
<!-- section header -->
<!-- endsection header -->
</head>
<body class="foo">
<!-- section content -->
<!-- endsection content -->  
</body>
</html>
EOQ

    my ($title, $body) = $se->parse_htmldoc($text);
    is($title, 'My Title', 'parse_htmldoc title'); # test 4
    is($body, "\nMy content.\n", 'parse_htmldoc body'); # test 5
};

#----------------------------------------------------------------------
# Test do_search

do {
    my $base_url = 'http://www.example.com';
    my $result = $se->do_search($base_url, 'first');

    delete $result->[0]{modtime};
    my $result_ok = [{title => 'Page First',
                      count => 1,
                      context => 'This is the <b>first</b> page. It is not the fourth page.',
                      url => "$base_url/first.html"}];

    is_deeply($result, $result_ok, 'do_search'); # test 6  
};

#----------------------------------------------------------------------
# Test restrict_pages and navlinks
do {
    my @subset;
    my @results;
    for my $i (1..100) {
        my $result = {count => 1, modtime => 1000 - $i, i => $i};
        push(@results, $result);
        push(@subset, $result) if $i <= 20;
    }

    my $query = 'foobar';
    my $url = 'search.cgi';
    my $hash = {query => $query, script_url => $url};

    my $restricted = $se->restrict_page($hash, \@results);
    
    my %restricted_ok = (%$hash, total => 100, start => 1, finish => 20);
    $restricted_ok{results} = \@subset;

    is_deeply($restricted, \%restricted_ok, 'restrict_page'); # test 7

    $restricted = $se->navlinks($restricted);
    is($restricted->{next_url}, "$url?query=$query&start=21",
       'navlinks next'); # test 8
};
