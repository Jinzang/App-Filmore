use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Test class

package MinMax;

use lib '../lib';
use base qw(Filmore::ConfiguredObject);

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
# Return info about form parameters

sub info_data {
    my ($self, $response) = @_;

    my %info = (name => 'value',
                msg => 'Value out of bounds',
                valid=>"&int[$self->{min},$self->{max}]"
                );

    return [\%info];
}

#----------------------------------------------------------------------
# Read data associated with a form

sub read_data {
    my ($self, $response) = @_;
    
    $response->{msg} = "Please enter a value";
    return;
}

#----------------------------------------------------------------------
# Return the template used to render the result

sub template_data {
    my ($self, $response) = @_;

    return <<'EOQ';
<html>
<head><title>MinMax</title></head>
<body><p>$msg</p>
<form action="$script_url">
<!-- for @items -->
<div><b>$title</b></div>
<div>$field</div>
<!-- endfor -->
<input type="submit" name="cmd" value="Cancel">
<input type="submit" name="cmd" value="Check">
</body>
</html>
EOQ
}

#----------------------------------------------------------------------
# Run the handler

sub use_data {
    my ($self, $response) = @_;

    $response->{msg} = "Value in bounds";
    return;
}

#----------------------------------------------------------------------
# Validate the data in the response

sub validate_data {
    my ($self, $response) = @_;
    return;
}
    
1;
