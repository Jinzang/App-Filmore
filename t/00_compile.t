use strict;

use Test::More;
use File::Spec::Functions qw(rel2abs catdir splitdir);

my @path = splitdir(rel2abs($0));
pop(@path);
pop(@path);

my $lib = catdir(@path, 'lib');
unshift(@INC, $lib);

use_ok $_ for qw(
    App::Filmore::CgiHandler
    App::Filmore::ConfigFile
    App::Filmore::ConfiguredObject
    App::Filmore::FormHandler
    App::Filmore::FormMail
    App::Filmore::SearchEngine
    App::Filmore::SimpleTemplate
    App::Filmore::WebFile
);

done_testing;

