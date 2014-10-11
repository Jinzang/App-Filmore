use strict;
use warnings;

#----------------------------------------------------------------------
# Prepare a mail message for sending with optional mime attachment

package Filmore::MimeMail;

use lib '../../lib';
use base qw(Filmore::ConfiguredObject);

our $VERSION = '0.01';

use MIME::Base64  qw(encode_base64);
use File::Spec::Functions qw(splitdir); # TODO check

#----------------------------------------------------------------------
# Set the default parameter values

sub parameters {
    my ($pkg) = @_;
    
    return (
        encoding => '8bit',
        attachment_type => 'text/html',
        sendmail_ptr => 'Filmore::Sendmail',
    );
}

#----------------------------------------------------------------------
# Build the mail header

sub build_header {
    my ($self, $mail_fields) = @_;

    my @headers;
    for my $field (reverse sort keys %$mail_fields) {
        next if $mail_fields->{body};
        
        my $value = $mail_fields->{$field};
        next unless $value;

        my $str = '';
        if (ref $value) {
            my @subfields;
            for my $subfield (sort keys %$value) {
                if (length $subfield) {
                    push(@subfields, "$subfield=$value->{$subfield}");
                } else {
                    push(@subfields, $value);
                }
                $str = join('; ', @subfields) . ';';
            }
            
        } else {
            $field =~ s/\b([a-z])/uc($1)/ge;
            $field =~ s/^mime-/MIME-/ig;
            $str = $value;
        }
        
        push(@headers, "$field: $str");
    }

    return join("\n", @headers) . "\n\n"; 
}

#----------------------------------------------------------------------
#  Encode as 7 bit (delete non-ascii and break long lines)

sub encode_as_7bit {
    my ($self, $str) = @_;

    $str =~ s/[\x80-\xFF]//g; 
    $str =~ s/^(.{990})/$1\n/mg;

    return $str;
}

#----------------------------------------------------------------------
# Encode as 8 bit (only break long lines)

sub encode_as_8bit {
    my ($self, $str) = @_;
    
    $str =~ s/^(.{990})/$1\n/mg;
    return $str;
}

#----------------------------------------------------------------------
# Encode text as base64

sub encode_as_base64 {
    my ($self, $str) = @_;

    return MIME::Base64::encode_base64($str);
}

#----------------------------------------------------------------------
# Encode as quoted printable

sub encode_as_qp {
    my ($self, $res) = @_;
    
    local($_);
    $res =~ s/([^ \t\n!-<>-~])/sprintf("=%02X", ord($1))/eg;  ### rule #2,#3
    $res =~ s/([ \t]+)$/
      join('', map { sprintf("=%02X", ord($_)) }
	           split('', $1)
      )/egm;                        ### rule #3 (encode whitespace at eol)

    ### rule #5 (lines shorter than 76 chars, but can't break =XX escapes:
    my $brokenlines = "";
    $brokenlines .= "$1=\n" while $res =~ s/^(.{70}([^=]{2})?)//; ### 70 was 74
    $brokenlines =~ s/=\n$// unless length $res; 

    return "$brokenlines$res";
}

#----------------------------------------------------------------------
# Extract base name from attachment name

sub get_basename {
    my ($attachment_name) = @_;
    return '' unless defined $attachment_name;
    
    my @path = splitdir($attachment_name);
    my $name = pop(@path);
    
    return $name =~ /\./ ? $name : '';
}

#----------------------------------------------------------------------
# Send a mail message with optional attachment

sub send_mail {
    my ($self, $mail_fields, $attachment, $attachment_name) = @_;

    $self->{sendmail_ptr}->open_mail;

    if (defined $attachment) {
        $self->send_mail_with_attachment($mail_fields, $attachment,
                                         $attachment_name);
    } else {
        $self->send_mail_no_attachment($mail_fields);
    }

    $self->{sendmail_ptr}->close_mail;
    return;
}

#----------------------------------------------------------------------
# Send a mail message without attachment

sub send_mail_no_attachment {
    my ($self, $mail_fields) = @_;

    $mail_fields->{mime_version} = '1.0';
    $mail_fields->{content_type} = {
                                    '' => 'text/plain',
                                    charset => 'utf-8',
                                    format => 'flowed',
                                    };
 
    $mail_fields->{content_transfer_encoding} = '8bit';

    $self->{sendmail_ptr}->print_mail($self->build_header($mail_fields));
    my $msg = $self->encode_as_8bit($mail_fields->{body});
    $self->{sendmail_ptr}->print_mail($msg);
   
    $self->{sendmail_ptr}->close_mail;
    return;

}

#----------------------------------------------------------------------
# Send a mail message with optional attachment

sub send_mail_with_attachment {
    my ($self, $mail_fields, $attachment, $attachment_name) = @_;
    
    my $boundary = "------------" . int(time) . $$;

    # Print mail header
    
    $mail_fields->{mime_version} = '1.0';
    $mail_fields->{content_type} = {'' => 'multipart/mixed',
                                    boundary => "\"$boundary\"",
                                   };
    $mail_fields->{content_transfer_encoding} = '8bit';

    $self->{sendmail_ptr}->print_mail($self->build_header($mail_fields));
    $self->{sendmail_ptr}->print_mail("This is a multi-part message in MIME format.\n");

    # Print message
    
    my $msg_header =  {};
    $msg_header->{content_type} = {
                                    '' => 'text/plain',
                                    charset => 'utf-8',
                                    format => 'flowed',
                                   };

    $msg_header->{content_transfer_encoding} = '8bit';
    
    $self->{sendmail_ptr}->print_mail("\n--$boundary\n");
    $self->{sendmail_ptr}->print_mail($self->build_headers($msg_header));

    my $msg = $self->encode_as_8bit($mail_fields->{body});
    $self->{sendmail_ptr}->print_mail($self->encode_as_8bit($msg));
    
    # Encode attachment
    
    my $encoding = $self->{encoding};
    if ($encoding eq '7bit') {
        $attachment = $self->encode_as_7bit($attachment);
    } elsif ($encoding eq '8bit') {
        $attachment = $self->encode_as_8bit($attachment);
    } elsif ($encoding eq 'base64') {
        $attachment = $self->encode_as_base64($attachment);
    } elsif ($encoding eq 'quoted-printable') {
        $attachment = $self->encode_as_qp($attachment);
    } else {
        $encoding = '8bit';
        $attachment = $self->encode_as_8bit($attachment);        
    }
 
    my $name = $self->get_basename($attachment_name);  

    # Print attachment
    
    my $attachment_header = {};
    $attachment_header->{content_type} = {
                                            '' => $self->{attachment_type},
                                            name => "\"$name\"",
                                          };

    $attachment_header->{content_transfer_encoding} = $encoding;
    $attachment_header->{content_disposition} = {'' =>'attachment',
                                                 filename => "\"$name\"",
                                                };
    
    $self->{sendmail_ptr}->print_mail("\n--$boundary\n");
    $self->{sendmail_ptr}->print_mail($self->build_headers($attachment_header));
    $self->{sendmail_ptr}->print_mail($attachment);
    $self->{sendmail_ptr}->print_mail("\n--$boundary\n");

    $self->{sendmail_ptr}->close_mail;
    return;
}
