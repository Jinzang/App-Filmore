#!/usr/bin/env perl
use strict;

use Test::More tests => 7;

use IO::File;
use File::Path qw(rmtree);
use File::Spec::Functions qw(catdir catfile rel2abs splitdir);

#----------------------------------------------------------------------
# Load search.cgi

my @path = splitdir(rel2abs($0));
pop(@path);
pop(@path);

my $lib = catdir(@path, 'lib');
unshift(@INC, $lib);

require App::Filmore::SimpleTemplate;

my $test_dir = catdir(@path, 'test');

rmtree($test_dir);
mkdir $test_dir;
chdir($test_dir);

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

    my $st = App::Filmore::SimpleTemplate->new();
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
# Test parse_sections and substitute_sections, and parse_htmldoc

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

    my $st = App::Filmore::SimpleTemplate->new();
    my $section = $st->parse_sections($text);
    my $section_ok = {header => "\n<title>My Title</title>\n",
                      content => "\n<p>My content.</p>\n"};
    
    is_deeply($section, $section_ok, 'parse_sections'); # test 1
    
    my $result = $st->substitute_sections($template, $section);
    like($result, qr(charset), 'substitute_sections, template code'); # test 2
    like($result, qr(My content), 'substitute_sections, section code'); # test 3
};

#----------------------------------------------------------------------
# Test for loop

do {
    my $template = <<'EOQ';
<!-- for @list -->
$name $phone
<!-- endfor -->
EOQ
    
    my $st = App::Filmore::SimpleTemplate->new();
    my $sub = $st->compile_code($template);

    my $data = {list => [{name => 'Ann', phone => '4444'},
                         {name => 'Joe', phone => '5555'}]};
    
    my $text = $sub->($data);
    
    my $text_ok = <<'EOQ';
Ann 4444
Joe 5555
EOQ
    
    is($text, $text_ok, "compile_code for loop"); # test 4
};

#----------------------------------------------------------------------
# Test if blocks

do {
    my $template = <<'EOQ';
<!-- if $x == 1 -->
\$x is $x (one)
<!-- elsif $x  == 2 -->
\$x is $x (two)
<!-- else -->
\$x is unknown
<!-- endif -->
EOQ
    
    my $st = App::Filmore::SimpleTemplate->new();
    my $sub = $st->compile_code($template);
    
    my $data = {x => 1};
    my $text = $sub->($data);
    is($text, "\$x is 1 (one)\n", "compile_code if block"); # test 5
    
    $data = {x => 2};
    $text = $sub->($data);
    is($text, "\$x is 2 (two)\n", "compile_code elsif block"); # test 6
    
    $data = {x => 3};
    $text = $sub->($data);
    is($text, "\$x is unknown\n", "compile_code else block"); # test 7
};
