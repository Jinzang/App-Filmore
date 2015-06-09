#!/usr/bin/perl

use strict;
use warnings;

use lib '../lib';

use Filmore::CgiHandler;
use File::Spec::Functions qw(catfile rel2abs splitdir);

my %args = command_line(@ARGV);
my $mailer = Filmore::CgiHandler->new(code_ptr => 'Filmore::FormMail');
my $result = $mailer->run(%args);
print $result;

#----------------------------------------------------------------------
# Build an argument list from the command line, for testing

sub command_line {
    my @args = @_;

    my %args;
    foreach my $arg (@args) {
        my ($name, $value);
        if ($arg =~ /=/) {
            ($name, $value) = split(/=/, $arg, 2);
        }

        $args{$name} = $value;
    }

    return %args;
}
