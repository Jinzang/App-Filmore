#!/usr/bin/perl

use strict;
use warnings;

use lib '../lib';

use Filmore::CgiHandler;

my %args = command_line(@ARGV);
my $code = Filmore::CgiHandler->new(code_ptr => 'Filmore::UpdatePassword');
my $result = $code->run(%args);
print $result;

#----------------------------------------------------------------------
# Build an argument list from the command line, for testing

sub command_line {
    my @args = @_;

    my %args;
    foreach my $arg (@args) {
        my ($name, $value) = split(/=/, $arg, 2);
        $value = 1 unless defined $value;

        if ($name eq 'password') {
            $name = 'password1';
            $args{password2} = $value;
        }

        $args{$name} = $value;
    }

    return %args;
}
