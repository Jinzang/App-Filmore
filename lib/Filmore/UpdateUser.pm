use strict;
use warnings;

package Filmore::UpdateUser;

use lib '../../lib';
use base qw(Filmore::AnyCommand);

our $VERSION = '0.01';

#----------------------------------------------------------------------
# Set the default parameter values

sub parameters {
    my ($pkg) = @_;

    return (
        default_cmd => 'browse',
        browse_ptr => 'Filmore::BrowseUser',
        edit_ptr => 'Filmore::EditUser',
        add_ptr => 'Filmore::AddUser',
        remove_ptr => 'Filmore::RemoveUser',
     );
}

1;
