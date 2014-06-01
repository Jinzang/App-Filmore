#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use App::Filmore::CgiHandler;

my $config_file = $0;
$config_file =~ s/\.[^\.]+$/\.cfg/;

my $search = App::Filmore::CgiHandler->new(config_file => $config_file,
                                           code_ptr => 'App::Filmore::SearchEngine',
                                          );

chdir($Bin); 
my %args = (query => join(' ', @ARGV));
my $result = $search->run(%args);
print $result;