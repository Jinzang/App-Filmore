#!/usr/bin/env perl
use strict;

use Test::More tests => 2;

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

$lib = catdir(@path, 't');
unshift(@INC, $lib);

require Filmore::MimeMail;

my $test_dir = catdir(@path, 'test');
rmtree($test_dir);
mkdir $test_dir;
chdir($test_dir);

my $email = 'anyone@example.com';

my %params = (
              web_master => 'bernie.simon@gmail.com',
              attachment_type => 'text/plain',
              );

my $mm = Filmore::MimeMail->new(%params);

#----------------------------------------------------------------------
# Send mail message, no attachment

do {
    my $body = "This is a test message\n";
    
    my $mail_fields = {
       
                        to => $params{web_master},
                        from => $email,
                        body => $body,
                        content_transfer_encoding => '8bit',
                        content_type => {
                                         '' => 'text/plain',
                                         charset => 'utf-8',
                                         format => 'flowed',
                                         },
                   };

    $mm->send_mail($mail_fields);
};

#----------------------------------------------------------------------
# Send mail message with attachment

do {
    my $body = "This is a test message\n";
    my $attachment = "This is an attachment";
    my $attachment_name = "file.txt";
    
    my $mail_fields = {
                        to => $params{web_master},
                        from => $email,
                        body => $body,
                        content_transfer_encoding => '8bit',
                        content_type => {
                                         '' => 'text/plain',
                                         charset => 'utf-8',
                                         format => 'flowed',
                                         },
                   };

    $mm->send_mail($mail_fields, $attachment, $attachment_name);
};

