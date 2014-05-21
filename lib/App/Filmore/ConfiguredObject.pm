use strict;
use warnings;
use integer;

package App::Filmore::ConfiguredObject;

our $VERSION = '0.01';

use Scalar::Util qw(blessed weaken);

#----------------------------------------------------------------------
# Create new object, configure fields, and create subobjects recursively

sub new {
	my ($pkg, %configuration) = @_;
    
	my $self = bless({}, 'App::Filmore::ConfiguredObject');
	$self->populate_object(\%configuration);
    
    $self = bless($self, $pkg);
	$self->populate_object(\%configuration);

    return $self;
}

#----------------------------------------------------------------------
# Get default parameter values

sub parameters {
	my ($pkg) = @_;
	return (config_ptr => 'App::Filmore::ConfigFile');
}

#----------------------------------------------------------------------
# Create the subobject contained in an object field

sub create_object {
	my ($self, $configuration, $field, $class) = @_;

    if ($class && ! blessed $class) {
        if ($class eq ref $self) {
            $configuration->{$field} = $self;

        } else {
            $self->load_class($field, $class);
            
            if ($class->isa('App::Filmore::ConfiguredObject')) {
                my $obj = bless({}, $class);
                $configuration->{$field} = $obj;   
                $obj->populate_object($configuration);
        
            } else {
                $configuration->{$field} = $class->new();
            }
        }
    }

    return;
}

#----------------------------------------------------------------------
# Set the default parameters for an object

sub default_parameters {
    my ($pkg, $cycle) = @_;

    no strict 'refs';

    $cycle ||= {};
    return if $cycle->{$pkg};
    
    $cycle->{$pkg} = 1;
    my %parameters = $pkg->parameters();
    
    foreach my $super (@{"${pkg}::ISA"}) {
        %parameters = ($super->default_parameters($cycle), %parameters);
    }

    return %parameters;    
}

#----------------------------------------------------------------------
# Load the file containing a class

sub load_class {
    my ($self, $field, $class) = @_;

	# Untaint class name
	my ($klass) = $class =~ /^(\w+(?:\:\:\w+)*)$/;

    unless ($klass) {
        $class ||= $field;
        die "Invalid class name: $class\n";
    }

    eval "require $klass" or die "$@\n";
    return;
}

#----------------------------------------------------------------------
# Set the field values in a new object

sub populate_object {
	my ($self, $configuration) = @_;

    my $pkg = ref $self;
	my %parameters = $pkg->default_parameters();

    # Recursively create subobjects
    
	foreach my $field (keys %parameters) {
		next unless $field =~ /_ptr$/;

        my $class = $configuration->{$field} || $parameters{$field};
        $self->create_object($configuration, $field, $class);
    }
    
    # Populate object from configuration
    
	foreach my $field (keys %parameters) {
		if (exists $configuration->{$field}) {
			$self->{$field} = $configuration->{$field};
		} else {
			$self->{$field} = $parameters{$field};
		}
	}

	return;
}

1;

__END__
=head1 NAME

App::Filmore::ConfiguredObject is the base class for configured objects

=head1 SYNOPSIS

	use App::Filmore::ConfiguredObject;
    $obj = $pkg->new(par1 => 'val1',
                     par2 => 'val2',
                     config_file => 'example.cfg');

=head1 DESCRIPTION

The class implements a dependency injection framework. It combines values passed
as parameters with values read from a configuration file. Any subclass must
implement the parameters method, which returns a hash containing the fields of
the class and their default values. If the name of a field ends in '_ptr', it
indicates that the field is a subobject. The value of the field ending in _ptr
is the package implementing the subobject. Values of the parameters are taken
from the argument list, then the configuration file, and finally from the
parameters method in that order of priority.

=head1 AUTHOR

Bernie Simon, E<lt>bernie.simon@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Bernie Simon

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
