use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Test class

package MinMax;

use lib '../lib';
use base qw(App::Filmore::ConfiguredObject);

#----------------------------------------------------------------------
# Check request

sub check {
    my ($self, $request) = @_;

    my $error;
    if (exists $request->{value}) {
        $error = "Value out of bounds"
            if $request->{value} < $self->{min} ||
               $request->{value} > $self->{max};
    } else {
        $error = "Value not set";
    }

    die $error if $error;
    return $error;
}

#----------------------------------------------------------------------
# Set default parameters

sub parameters {
  my ($pkg) = @_;

    my %parameters = (
            min => 1,
            max => 10,
	);

    return %parameters;
}

#----------------------------------------------------------------------
# Check request

sub query {
    my ($self, $error) = @_;

    my $response = {};
    $response->{result} = "$error value?";

    return $response;
}

#----------------------------------------------------------------------
# Run the handler

sub run {
    my ($self, $request) = @_;

    my $response;
    my $error = $self->check($request);

    if ($error) {
        $response->{code} = 400;
        $response->{msg} = $error;
        $response->{results} = $self->query($error);

    } else {
        $response->{code} = 200;
        $response->{msg} = 'OK';        
        $response->{results} = "Value in bounds";
    }

    return $response;
}

1;
