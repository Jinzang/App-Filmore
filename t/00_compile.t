use strict;

use Test::More;
use File::Spec::Functions qw(rel2abs catdir splitdir);

my @path = splitdir(rel2abs($0));
pop(@path);
pop(@path);

my $lib = catdir(@path, 'lib');
unshift(@INC, $lib);

use_ok $_ for qw(
    Filmore::AddUser
    Filmore::BrowseUser
    Filmore::CgiHandler
    Filmore::ConfigFile
    Filmore::ConfiguredObject
    Filmore::EditUser
    Filmore::FormHandler
    Filmore::FormMail
    Filmore::HttpHandler
    Filmore::MailPage
    Filmore::MimeMail
    Filmore::RemoveUser
    Filmore::Response
    Filmore::SearchEngine
    Filmore::Sendmail
    Filmore::SimpleTemplate
    Filmore::UpdateUser
    Filmore::UserData
    Filmore::WebFile
);

done_testing;
