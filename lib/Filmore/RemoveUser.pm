use strict;
use warnings;

package Filmore::RemoveUser;

use lib '../../lib';
use base qw(Filmore::ConfiguredObject);

our $VERSION = '0.01';

#----------------------------------------------------------------------
# Set the default parameter values

sub parameters {
    my ($pkg) = @_;

    return (
        web_master => '',
        userdata_ptr => 'Filmore::UserData'
    );
}

#----------------------------------------------------------------------
# Get the information about data fields

sub info_object {
    my ($self, $results) = @_;

    my $groups = $self->read_groups_file();
    my $choices =  join('|', sort keys %$groups);

    my $info = [{name => 'email',
                 title => 'Email Address',
                 type => 'hidden',
                 valid=>"&email"},
               ];

    return $info;
}

#----------------------------------------------------------------------
# Read the data to be displayed in the form

sub read_object {
    my ($self, $results) = @_;
    return;
}

#----------------------------------------------------------------------
# Get the subtemplate used to render the file

sub template_object {
    my ($self, $results) = @_;

    return <<'EOQ';
<html>
<head>
<!-- section meta -->
<title>Application Users</title>
<!-- endsection meta -->
</head>
<body>
<!-- section content -->
<h1 id="banner">Application Users</h1>
<p>$error</p>

<form method="post" action="$script_url">
<!-- for @items -->
$field
<!-- endfor -->
Remove $email?<br/>
<input type="submit" name="cmd" value="cancel">
<input type="submit" name="cmd" value="$cmd">
</form>
<!--endsection content -->
</body>
</html>
EOQ
}

#----------------------------------------------------------------------
# Call method to use data gathered from form

sub use_object {
    my ($self, $results) = @_;

    my $redirect = 1;
    my $user = $results->{email};

    $self->{userdata_ptr}->update_groups_file($user, []);

    my $passwords = $self->{userdata_ptr}->read_password_file();
    delete $passwords->{$user};
    $self->{userdata_ptr}->write_password_file($passwords);

    return $redirect;
}

#----------------------------------------------------------------------
# Call method to validate results if it is present

sub validate_object {
    my ($self, $results) = @_;

    my $user = $results->{email};

    return "Cannot remove web master" if $user eq $self->{web_master};

    my $passwords = $self->{userdata_ptr}->read_password_file();
    return "User not found: $user" unless exists $passwords->{$user};

    return;
}

1;
