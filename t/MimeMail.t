#!/usr/bin/env perl
use strict;

use Test::More tests => 7;

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
              web_master => 'webmaster@example.com',
              sendmail_ptr => 'MockMail',
              attachment_type => 'text/plain',
              );

my $mm = Filmore::MimeMail->new(%params);

#----------------------------------------------------------------------
# Test generating attachment basename

do {
    my $attachment_ok = 'attachment.html';
    my $filename = catfile($test_dir, $attachment_ok);
    
    my $attachment = $mm->get_basename($filename);
    is($attachment, $attachment_ok, 'Get basename'); # test 1
};

#----------------------------------------------------------------------
# Test generating attachment basename

do {
    my $field = 'content_type';
    my $field_ok = 'Content-Type';
    
    $field = $mm->get_fieldname($field);
    is($field, $field_ok, 'Get fieldname'); # test 2

    $field = 'mime_type';
    my $field_ok = 'MIME-Type';
    
    $field = $mm->get_fieldname($field);
    is($field, $field_ok, 'Get mime field'); # test 3
};

#----------------------------------------------------------------------
# Build simple mail header

do {
    my $header_fields = {
                   from => $email,
                   to => $params{web_master},
                   subject => 'Test Message',
                   body => "Test message from $email\n",
                   };

    my $header_ok = <<"EOQ";
To: $header_fields->{to}
Subject: $header_fields->{subject}
From: $header_fields->{from}

EOQ

    my $header = $mm->build_header($header_fields);
    is($header, $header_ok, 'Build simple header'); # test 4
};

#----------------------------------------------------------------------
# Build complex mail header

do {
    my $header_fields = {
                        content_transfer_encoding => '8bit',
                        content_type => {
                                         '' => 'text/plain',
                                         charset => 'utf-8',
                                         format => 'flowed',
                                         },
                   };

    my $header_ok = <<"EOQ";
Content-Type: text/plain; charset=utf-8; format=flowed;
Content-Transfer-Encoding: 8bit

EOQ

    my $header = $mm->build_header($header_fields);
    is($header, $header_ok, 'Build complex header'); # test 5
};

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

    my $mail_ok = <<"EOQ";
To: $params{web_master}
MIME-Version: 1.0
From: $email
Content-Type: text/plain; charset=utf-8; format=flowed;
Content-Transfer-Encoding: 8bit

$body
EOQ

    chomp $mail_ok;
    $mm->send_mail($mail_fields);
    my $mail = $mm->{sendmail_ptr}->get_mail();
    is($mail, $mail_ok, 'Build mail message wo attachment'); # test 6
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

    my $mail_ok = <<'EOQ';
To: webmaster@example.com
MIME-Version: 1.0
From: anyone@example.com
Content-Type: multipart/mixed; boundary="------------";
Content-Transfer-Encoding: 8bit

This is a multi-part message in MIME format.

--------------
Content-Type: text/plain; charset=utf-8; format=flowed;
Content-Transfer-Encoding: 8bit

This is a test message

--------------
Content-Type: text/plain; name="file.txt";
Content-Transfer-Encoding: 8bit
Content-Disposition: attachment; filename="file.txt";

This is an attachment
--------------
EOQ

    $mm->send_mail($mail_fields, $attachment, $attachment_name);
    my $mail = $mm->{sendmail_ptr}->get_mail();
    $mail =~ s/---\d+/---/g;
 
    is($mail, $mail_ok, 'Mail message with attachment'); # test 7
};

