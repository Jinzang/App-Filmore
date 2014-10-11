#!/usr/bin/env perl
use strict;

use Test::More tests => 3;

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

require Filmore::FormMail;

my $test_dir = catdir(@path, 'test');
my $template_dir = catdir(@path, 'test', 'templates');
rmtree($test_dir);
mkdir $test_dir;
mkdir $template_dir;
chdir($test_dir);

my $base_url = 'http://www.example.com/';

my %params = (
              valid_read => [$test_dir],
              web_master => 'busy@body.com',
              );

my $fm = Filmore::FormMail->new(%params);
my $wf = Filmore::WebFile->new(%params);

#----------------------------------------------------------------------
# Create test files

my $info = <<'EOQ';
[url]
valid = &url
type = hidden
[email]
valid = &email
[note]
type = textarea
[body]
valid = &
type = textarea
EOQ

my $mail = <<'EOQ';
template = Test message from $email

subject = Test Message
EOQ

my $form = <<'EOQ';
<html>
<head>
<title>Edit Page</title>
</head>
<body>
<h2>Edit Page</h2>

<!-- section message -->
<!-- endsection message -->

<!-- section content -->
<form id="edit_form" method="post" action="$script_url">
<!-- for @items -->
<!-- if $type ne 'hidden' -->
<div class="form-title">$title</div>
<!-- endif -->
<div class="form-field">$field</div>
<!-- endfor -->
<div>
<input type="submit" name = "cmd" value="Cancel" />
<input type="submit" name = "cmd" value="Mail" />
</div>
</form>

<!-- endsection content -->
</body>
</html>
EOQ

my $page = <<'EOQ';
<html>
<head>
<!-- section meta -->
<title>Page First</title>
<!-- endsection meta -->
</head>
<body>
  <!-- section content -->
  <p>This is the
  front page of the website.</p> 
  <!-- endsection content -->  
</body>
</html>
EOQ

my $info_file = catfile($template_dir, 'FormMail.info');
$wf->write_wo_validation($info_file, $info);

my $mail_file = catfile($template_dir, 'FormMail.mail');
$wf->write_wo_validation($mail_file, $mail);

my $form_file = catfile($template_dir, 'FormMail.htm');
$wf->write_wo_validation($form_file, $form);

my $page_file = catfile($test_dir, 'index.html');
$wf->write_wo_validation($page_file, $page);

#----------------------------------------------------------------------
# Test generating template filename

do {
    my $filename_ok = catfile($template_dir, 'FormMail.foo');
    my $filename = $fm->template_filename('foo');
    is($filename, $filename_ok, 'Generate filename'); # test 1
};

#----------------------------------------------------------------------
# Test reading info file

do {
    my $info_ok = [
        {name => 'url', valid => '&url', type => 'hidden', },
        {name => 'email', valid => '&email', },
        {name => 'note', type => 'textarea', },
        {name => 'body', valid => '&', type => 'textarea', },
                   ];

    my $response = {};
    my $info = $fm->info_object($response);
    is_deeply($info, $info_ok, 'Read info file'); # test 2
};

#----------------------------------------------------------------------
# Build mail fields

do {
    my $email = 'any@body.com';

    my $response = {email => $email};

    my $mail_ok = {
                   from => $email,
                   to => $params{web_master},
                   subject => 'Test Message',
                   body => "Test message from $response->{email}\n",
                   };
    
    my $mail = $fm->build_mail_fields($response);
    is_deeply($mail, $mail_ok, 'Build mail fields'); # test 3
};

