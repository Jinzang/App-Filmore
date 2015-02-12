#!/usr/bin/env perl
use strict;

use Test::More tests => 6;

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

require Filmore::UpdateUser;
require Filmore::WebFile;

my $base_dir = catdir(@path, 'test');
my $config_dir = catdir(@path, 'test', 'config');

rmtree($base_dir);
mkdir $base_dir;
mkdir $config_dir;
chdir $base_dir;
$base_dir = getcwd();

my %params = (
              nonce => 1234,
              web_master => 'poobah@test.com',
              valid_write => [$base_dir],
              base_directory => $base_dir,
              );

my $uu = Filmore::UpdateUser->new(%params);
my $wf = Filmore::WebFile->new(%params);

#----------------------------------------------------------------------
# Write files

do {

    my $users = <<'EOQ';
bar@test.com:1d2f3g4s
foo@test.com:8g4h6j7x
EOQ

    my $user_file = catfile($base_dir, '.htpasswd');
    $wf->write_wo_validation($user_file, $users);

    my $info = <<'EOQ';
name = email
title = Email Address
type = hidden
valid= &email
EOQ

    my $info_file = catfile($config_dir, 'remove_user.info');
    $wf->write_wo_validation($info_file, $info);

    my $template = <<'EOQ';
<html>
<head>
<!-- section meta -->
<title>Application Users</title>
<!-- endsection meta -->
</head>
<body>
<!-- section content -->
<h1 id="banner">Application Users</h1>
<p>$error</p>

<form method="post" action="$script_url">
<!-- for @items -->
<!-- if $type eq 'hidden' -->
<!-- if $name ne 'nonce' -->
<b>$value</b>
<!-- endif -->
<!-- else -->
<b>$title</b><br />
<!-- endif -->
$field<br />
<!-- endfor -->
Remove $email?<br/>
<input type="submit" name="cmd" value="cancel">
<input type="submit" name="cmd" value="$cmd">
</form>
<!--endsection content -->
</body>
</html>
EOQ

    my $template_file = catfile($config_dir, 'remove_user.htm');
    $wf->write_wo_validation($template_file, $template);
    print "($template_file)\n";
};

#----------------------------------------------------------------------
# Check command selection

do {
    my $results = {email => 'bar@test.com'};

    my $cmd = $uu->get_command($results);
    is($cmd, 'browse_ptr', "No command"); # test 1

    $results->{cmd} = 'duh';
    $cmd = $uu->get_command($results);
    is($cmd, 'browse_ptr', "Bad command"); # test 2

    $results->{cmd} = 'remove';
    $cmd = $uu->get_command($results);
    is($cmd, 'remove_ptr', "Good command"); # test 3
};

#----------------------------------------------------------------------
# Check configuration name

do {
    my $base = $uu->configuration_name('browse_ptr');
    is($base, 'browse_user', "Configuration name"); # test 4
};

#----------------------------------------------------------------------
# Read info  and template files

do {
    my $results = {cmd => 'remove', email => 'foo@test.com', nonce => 0};

    my $info_ok = [
                    {name => 'nonce',
                    type => 'hidden',
                    msg => 'Time outerror, please resubmit',
                    value => 1234,
                    valid => '&nonce'},
                    {name => 'email',
                    title => 'Email Address',
                    type => 'hidden',
                    valid=> '&email'},
                   ];

    my $info = $uu->info_object($results);
    is_deeply($info, $info_ok, "Info object"); # test 5

    my $template = $uu->template_object($results);
    ok(length($template) > 0, "Template object"); # test 6
};
