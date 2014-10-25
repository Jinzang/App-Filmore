use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Test class

package MockMail;

use lib '../lib';
use base qw(Filmore::ConfiguredObject);

our $buffer = '';

#----------------------------------------------------------------------
# Set default parameters

sub parameters {
  my ($pkg) = @_;

    my %parameters = (
	);

    return %parameters;
}

#----------------------------------------------------------------------
# Close the pipe

sub close_mail {
    my ($self) = @_;
    
    return;
}

#----------------------------------------------------------------------
# Open a pipe to sendmail command

sub get_mail {
    my ($self) = @_;

    return $buffer;;
}

#----------------------------------------------------------------------
# Open a pipe to sendmail command

sub open_mail {
    my ($self) = @_;

    $buffer = '';
    return;
}

#----------------------------------------------------------------------
# Print a line to the pipe

sub print_mail {
    my ($self, $text) = @_;
    
    $buffer .= $text;
    return;
}
    
1;
