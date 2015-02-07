#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Filmore::CgiHandler;
use File::Spec::Functions qw(catfile rel2abs splitdir);

my $config_file = get_config_file($0);
my %args = command_line(@ARGV);

my $code = Filmore::CgiHandler->new(config_file => $config_file,
                                    code_ptr => 'Filmore::UpdatePassword',
                                    );

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

#----------------------------------------------------------------------
# Get the base directory of the script

sub get_config_file {
    my ($script) = @_;

    my @dirs = splitdir($script);
    my $config_file = pop(@dirs);
    $config_file = s/\.[^\.]*$//;
    $config_file .= '.cfg';

    my $base_dir = catfile(@dirs) || '';
    $base_dir = rel2abs($base_dir);

    return catfile($base_dir, $config_file);
}
