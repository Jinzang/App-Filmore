use strict;
use warnings;

package Filmore::UpdatePassword;

use lib '../../lib';
use base qw(Filmore::AnyCommand);

our $VERSION = '0.01';

#----------------------------------------------------------------------
# Set the default parameter values

sub parameters {
    my ($pkg) = @_;

    return (
        default_cmd => 'request',
        change_ptr => 'Filmore::ChangePassword',
        request_ptr => 'Filmore::RequestPassword',
    );
}

1;
