#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Filmore::CgiHandler;
use File::Spec::Functions qw(catfile rel2abs splitdir);

my $config_file = '';
my $base_dir = get_base_dir($0);
my %args = command_line(@ARGV);

my $mailer = Filmore::CgiHandler->new(config_file => $config_file,
                                           code_ptr => 'Filmore::FormMail',
                                         );

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

        } elsif ($arg =~ /\@/) {
            $name = 'email';
            $value = $arg;

        } else {
            $name = 'url';
            $value = $arg;
        }

        $args{$name} = $value;
    }

    return %args;
}

#----------------------------------------------------------------------
# Get the base directory of the script

sub get_base_dir {
    my ($script) = @_;

    my @dirs = splitdir($script);
    pop(@dirs);

    my $base_dir = catfile(@dirs) || '';
    return rel2abs($base_dir);
}