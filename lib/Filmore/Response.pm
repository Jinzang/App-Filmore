use strict;
use warnings;

package Filmore::Response;

use lib '../../lib';

#----------------------------------------------------------------------
# Mock response object with same methods as HTTP::Response

sub new {
    my ($pkg) = @_;
    return bless({}, $pkg);
}

#----------------------------------------------------------------------
# Get/Set response code

sub code {
    my ($self, $code) = @_;
    $self->{code} = $code if defined $code;
    return $self->{code};
}

#----------------------------------------------------------------------
# Get/Set response content

sub content {
    my ($self, $content) = @_;
    $self->{content} = $content if defined $content;
    return $self->{content};
}

#----------------------------------------------------------------------
# Get/Set header field

sub header {
    my ($self, $field, $value) = @_;
    
    $self->{header} ||= []; 
    return $self->{header} unless defined $field;

    if (defined $value) {
        my $found;
        for (my $i = 0; $i < @{$self->{header}}; $i += 2) {
            if ($self->{header}[$i] eq $field) {
                $self->{header}[$i+1] = $value;
                $found = 1;
                last;
            }
        }

        push(@{$self->{header}}, $field, $value) unless $found;

    } else {
        for (my $i = 0; $i < @{$self->{header}}; $i += 2) {
            if ($self->{header}[$i] eq $field) {
                $value = $self->{header}[$i+1];
                last;
            }
        }
    }
    
    return $value;
}

1;
