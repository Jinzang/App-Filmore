#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Filmore::HttpHandler;
use File::Spec::Functions qw(catdir catfile rel2abs splitdir);


use constant ROUTE_TABLE => [
                            {route => '/search', code_ptr => 'SearchEngine'},
                           ];

my $base_dir =rel2abs ("$Bin/..");
my $port = '8080';

my $config_file = $0;
$config_file =~ s/\.[^\.]*/\.cfg/;

my %params = (
                nofork => 1,
                protocol => 'text/html',
                port => $port.
                base_url => "http://localhost/",
                base_directory => $base_dir,
                config_file => $config_file,
             );

 my $handler = HttpHandler->new(%params);
 $handler->run();