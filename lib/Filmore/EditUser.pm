use strict;
use warnings;

package Filmore::EditUser;

use lib '../../lib';
use base qw(Filmore::ConfiguredObject);

our $VERSION = '0.01';

#----------------------------------------------------------------------
# Set the default parameter values

sub parameters {
    my ($pkg) = @_;

    return (
        userdata_ptr => 'Filmore::UserData'
    );
}

#----------------------------------------------------------------------
# Get the information about data fields

sub info_object {
    my ($self, $results) = @_;

    my $groups = $self->{userdata_ptr}->read_groups_file();
    my $choices =  join('|', sort keys %$groups);

    my $info = [{name => 'email',
                 title => 'Email Address',
                 type => 'hidden',
                 valid=>"&email"},
                {name => 'group',
                 title => 'Applications',
                 type => 'checkbox',
                 valid => "\&string|$choices|"},
               ];

    return $info;
}

#----------------------------------------------------------------------
# Read the data to be displayed in the form

sub read_object {
    my ($self, $results) = @_;

    my @groups;
    my $user = $results->{email};

    if ($user) {
        my $groups = $self->{userdata_ptr}->read_groups_file();

        foreach my $group (sort keys %$groups) {
            push(@groups, $group) if $groups->{$group}{$user};
        }
    }

    $results->{group} = \@groups;
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
<!-- if $type eq 'hidden' -->
<b>$value</b>
<!-- else -->
<b>$title</b><br />
<!-- endif -->
$field<br />
<!-- endfor -->
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
    $self->{userdata_ptr}->update_groups_file($results->{email},
                                              $results->{groups});

    return $redirect;
}

#----------------------------------------------------------------------
# Call method to validate results if it is present

sub validate_object {
    my ($self, $results) = @_;

    my $user = $results->{email};
    my $passwords = $self->{userdata_ptr}->read_password_file();
    return "User not found: $user" unless exists $passwords->{$user};

    my $groups = $self->{userdata_ptr}->read_groups_file();
    my %groups = map {$_ => 1} keys %$groups;

    my @groups;
    foreach my $group (@{$results->{group}}) {
        push(@groups, $group) unless exists $groups{$group};
    }

    return "Group not found: " . join(',', @groups) if @groups;

    return;
}

1;
