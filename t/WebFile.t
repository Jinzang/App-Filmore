#!/usr/bin/env perl
use strict;

use lib 't';
use lib 'lib';
use Test::More tests => 14;

use IO::File;
use Cwd qw(abs_path getcwd);
use File::Path qw(rmtree);
use File::Spec::Functions qw(catdir catfile rel2abs splitdir);

#----------------------------------------------------------------------
# Load the package and create test directory and object

my @path = splitdir(rel2abs($0));
pop(@path);
pop(@path);

my $lib = catdir(@path, 'lib');
unshift(@INC, $lib);

require App::Filmore::WebFile;

my $data_dir = catdir(@path, 'test');

rmtree($data_dir);
mkdir $data_dir;
chdir($data_dir);

my $script_dir = catfile($data_dir, 'script');
mkdir($script_dir);

#----------------------------------------------------------------------
# Create object

BEGIN {use_ok("App::Filmore::WebFile");} # test 1

my $base_url = 'http://www.example.com/';

my $params = {
              base_directory => $data_dir,
              base_url => $base_url,
              data_dir => $data_dir,
              valid_write => [$data_dir, $script_dir,],
             };

my $wf = App::Filmore::WebFile->new(%$params);

isa_ok($wf, "App::Filmore::WebFile"); # test 2
can_ok($wf, qw(relocate reader writer validate_filename)); # test 3

#----------------------------------------------------------------------
# relocate

$wf->relocate($data_dir);
my $dir = getcwd();
is($dir, $data_dir, "relocate"); # test 4

#----------------------------------------------------------------------
# validate_filename

my $filename = 'page001.html';
my $required_filename = "$data_dir/$filename";
$filename = $wf->validate_filename($filename, 'w');
is($filename, $required_filename, "validate_filname in data dir"); # test 5

$filename = 'script/template.htm';
$required_filename = "$data_dir/$filename";
$filename = $wf->validate_filename($filename, 'r');
is($filename, $required_filename, "validate_filname in script dir"); # test 6

$filename = '../forbidden.html';
eval {
    $filename = $wf->validate_filename($filename, 'r');
};

is($@, "Invalid filename: $filename\n",
   "validate_filename outside dir"); # test 7

$filename = '../forbidden.html';
eval {
    $filename = $wf->validate_filename($filename, 'r');
};

is($@, "Invalid filename: $filename\n",
   "validate_filename with hidden filename"); # test 8

#----------------------------------------------------------------------
# Filename maniputlations

$filename = catfile($data_dir, 'index.html');
($dir, $filename) = $wf->split_filename($filename);
is($dir, $data_dir, "Split filename: dir"); # test 9
is($filename, 'index.html', "Split filename: basename"); # test 10

#----------------------------------------------------------------------
# Build filename from url

do {
    my $file = 'foobar.html';
    my $url = $base_url . $file;
    my $filename_ok = catfile($data_dir, $file);
    
    my $response = {base_url => $base_url, url => $url};
    my $filename = $wf->url_to_filename($response);
    is($filename, $filename_ok, 'Url to filename'); # test 11
};

#----------------------------------------------------------------------
# Create test files

my $pagename = catfile($data_dir, 'page001.html');
my $templatename = catfile($script_dir, 'page.htm');

my $page = <<'EOQ';
<html>
<head>
<!-- section header -->
<title>A title</title>
<!-- endsection header -->
</head>
<body bgcolor=\"#ffffff\">
<div id = "container">
<div  id="content">
<h1>Index template file</h1>
<!-- section content -->
<h1>The Content</h2>
<!-- endsection content -->
</div>
<div id="sidebar">
<!-- section sidebar -->
<p>A sidebar</p>
<!-- endsection sidebar -->
</div>
</div>
</body>
</html>
EOQ

my $template =<<'EOQ';
<html>
<head>
<!-- section header -->
<title>$title</title>
<!-- endsection header -->
</head>
<body bgcolor=\"#ffffff\">
<div id = "container">
<div  id="content">
<h1>Index template file</h1>
<!-- section content -->
<h1>$title</h1>

<p>$body</p>

<div>$author</div>
<!-- endsection content -->
</div>
<div id="sidebar">
<!-- section sidebar -->
<ul>
<!-- for @others -->
<li><a href="$url">$title</a></li>
<!-- endfor -->
</ul>
<!-- endsection sidebar -->
</div>
</div>
</body>
</html>
EOQ

# Write files

$wf->writer($pagename, $page);
$wf->writer($templatename, $template);

my $src = $wf->reader($pagename);

is($src, $page, "Read/Write"); #test 12

my $nestedname = catfile('data', 'dir002', 'dir001', 'dir001', 'page001.html');
$wf->writer($nestedname, $page);

$src = $wf->reader($nestedname);
is($src, $page, "Write nested directories"); # test 13

#----------------------------------------------------------------------
# Test file visitor

my $files = [];
my $visitor = $wf->visitor($data_dir);
while (my $file = &$visitor()) {
    push(@$files, $file);
}

my $visit_result = [
                    catfile($data_dir, 'page001.html'),
                    catfile($data_dir, 'data', 'dir002', 'dir001',
                            'dir001', 'page001.html'),
                    catfile($data_dir, 'script', 'page.htm'),
                    ];
is_deeply($files, $visit_result, "File visitor"); # test 14
