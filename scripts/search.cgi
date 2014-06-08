#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use App::Filmore::CgiHandler;
use File::Spec::Functions qw(catfile splitdir);

my $config_file = $0;
$config_file =~ s/\.[^\.]+$/\.cfg/;

my $base_dir = get_base_dir($0);

my $search = App::Filmore::CgiHandler->new(config_file => $config_file,
                                           code_ptr => 'App::Filmore::SearchEngine',
                                           base_dir => $base_dir,
                                           script_dir => $base_dir,
                                           valid_write => [$base_dir], 
                                          );

my %args = (query => join(' ', @ARGV));
my $result = $search->run(%args);
print $result;

sub get_base_dir {
    my ($script) = @_;

    my @dirs = splitdir($script);
    pop(@dirs);

    return catfile(@dirs) || '';
}