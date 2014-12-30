use strict;
use warnings;

package Filmore::BrowseUser;

use lib '../../lib';
use base qw(Filmore::ConfiguredObject);

our $VERSION = '0.01';

#----------------------------------------------------------------------
# Set the default parameter values

sub parameters {
    my ($pkg) = @_;

    return (
        web_master => '',
        userdata_ptr => 'Filmore::UserData',
    );
}

#----------------------------------------------------------------------
# Get the information about data fields

sub info_object {
    my ($self, $results) = @_;

    my $passwords = $self->{userdata_ptr}->read_password_file();
    delete $passwords->{$self->{web_master}};

    my $users = join('|', sort keys %$passwords);

    my $info = [{name => 'email',
                 title => 'Email Address',
                 type => 'radio',
                 style => 'linebreak=1',
                 valid => "\&string|$users|"}];
    return $info;
}

#----------------------------------------------------------------------
# No data to read when browsing

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
<b>Add New User</b><br/>
<input type="submit" name="cmd" value="add">
</form>

<form method="post" action="$script_url">
<!-- for @items -->
<b>$title</b><br />
$field<br />
<!-- endfor -->
<input type="submit" name="cmd" value="cancel">
<input type="submit" name="cmd" value="edit">
<input type="submit" name="cmd" value="remove">
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

    my $redirect = 0;
    return $redirect;
}

#----------------------------------------------------------------------
# Call method to validate results if it is present

sub validate_object {
    my ($self, $results) = @_;

    return;
}

1;
