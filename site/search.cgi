#!/usr/bin/perl

use strict;
use warnings;
use lib '../lib';

use Filmore::CgiHandler;

my $search = Filmore::CgiHandler->new(code_ptr => 'Filmore::SearchEngine');
my %args = (query => join(' ', @ARGV), cmd => 'Edit');
my $result = $search->run(%args);
print $result;
