use strict;
use warnings;
use integer;

package Filmore::ConfigFile;

use lib '../../lib';
use base qw(Filmore::ConfiguredObject);

our $VERSION = '0.01';

use IO::File;
use File::Spec::Functions qw(catdir catfile rel2abs splitdir);

use constant CONFIG_EXT => 'cfg';
use constant INCLUDE_EXT => 'inc';

#----------------------------------------------------------------------
# Create new object, configure fields, and create subobjects recursively

sub new {
	my ($pkg, %configuration) = @_;

    my $self = bless({}, $pkg);
	$self->populate_object(\%configuration);

    return $self;
}

#----------------------------------------------------------------------
# Get hardcoded default parameter values

sub parameters {
	my ($pkg) = @_;

	return (
			config_dir => 'config',
		   );
}

#----------------------------------------------------------------------
# Get field's value from a hash

sub get_field {
    my ($self, $hash, $name) = @_;

    while ($name =~ /\./) {
        my $subname;
        ($name, $subname) = split(/\./, $name, 2);
        last unless exists $hash->{$name};

        $hash = $hash->{$name};
        $name = $subname;
    }

    my $value = exists $hash->{$name} ? $hash->{$name} : '';
    return $value;
}

#----------------------------------------------------------------------
# Get the name of a configuration file

sub get_filename {
    my ($self, $ext, $filename) = @_;

    $ext = CONFIG_EXT unless defined $ext;

    unless (defined $filename) {
        my @path = splitdir($0);
        $filename = pop(@path);
        $filename =~ s/\.[^\.]*$//;
    }

    my ($basename) = $filename =~ /^([-\w]+)$/;
    die "Illegal config file name: $filename\n" unless $basename;
    $filename = join('.', $basename, $ext);

    $filename = catfile($self->{config_dir}, $filename);
    $filename = rel2abs($filename);

    return $filename;
}

#----------------------------------------------------------------------
# Set the field values in a new object

sub populate_object {
	my ($self, $configuration) = @_;

    $self->SUPER::populate_object($configuration);

    my $filename =$self->get_filename();
    my $hash = $self->read_file($filename);

    %$configuration = (%$hash, %$configuration);
    return;
}

#---------------------------------------------------------------------------
# Read a configuration file into a hash

sub read_file {
    my ($self, $filename) = @_;

    my $hash = {};
    my $fd = IO::File->new($filename, 'r');

    if ($fd) {
        while (my $line = <$fd>) {
            # Ignore comments and blank lines
            next if $line =~ /^\s*\#/ || $line !~ /\S/;

            if ($line =~ /=/) {
                # Split line into name and value, remove leading and
                # trailing whitespace

                my ($name, $value) = split (/\s*=\s*/, $line, 2);

                die "Bad line in config file: ($name)" unless defined $value;
                $value =~ s/\s+$//;

                # Insert the name and value into the hash

                $self->set_field($hash, $name, $value);

            } else {
                # Lines without equal signs are commands
                $line =~ s/\s+$//;
                my ($cmd, $arg) = split(' ', $line);

                if ($cmd eq 'include') {
                    # Include file
                    $filename = $self->get_filename(INCLUDE_EXT, $arg);
                    my $subhash = $self->read_file($filename);
                    %$hash = (%$hash, %$subhash);

                } else {
                    die "Unrecognized command in config file: $cmd";
                }
            }
        }

        close($fd);
    }

    return $hash;
}

#---------------------------------------------------------------------------
# Insert a field's name and value into a hash

sub set_field {
    my ($self, $hash, $name, $value) = @_;

    $value =~ s/\${([\w\.]+)}/$self->get_field($hash, $1)/ge;
    $value =~ s/\$([\w\.]+)/$self->get_field($hash, $1)/ge;

    while ($name =~ /\./) {
        my $subname;
        ($name, $subname) = split(/\./, $name, 2);
        $hash->{$name} = {} unless exists $hash->{$name};

        $hash = $hash->{$name};
        $name = $subname;
    }

    if (! exists $hash->{$name}) {
        $hash->{$name} = $value;

    } elsif (ref $hash->{$name} eq 'ARRAY') {
        push(@{$hash->{$name}}, $value);

    } elsif (ref $hash->{$name} eq 'HASH') {
        die "Name colision in configuration file: ($name)\n";

    } else {
        $hash->{$name} = [$hash->{$name}, $value];
    }

    return;
}

#---------------------------------------------------------------------------
# Convert data structure to string

sub write_fields {
    my ($self, $hash, $prefix) = @_;

    my @output;
    foreach my $name (sort keys %$hash) {
        next if $name =~ /_ptr$/;

        my $value = $hash->{$name};
        my $longname = defined $prefix ? "$prefix.$name" : $name;

        if (! ref $value) {
            push(@output, "$longname = $value\n");

        } elsif (ref $hash->{$name} eq 'ARRAY') {
            foreach my $subvalue (@{$hash->{$name}}) {
                push(@output, "$longname = $subvalue\n");
            }

        } elsif (ref $hash->{$name} eq 'HASH') {
            push(@output, $self->write_fields($hash->{$name}, $longname));

        } else {
            die " Can't write value to config file: $longname\n";
        }
    }

    return @output;
}

#----------------------------------------------------------------------
# Write a configuration file from a hash

sub write_file {
    my ($self, $filename, $configuration) = @_;

    my $fd = IO::File->new($filename, 'w');
    die "Couln't read $filename: $!" unless $fd;

    my @output = $self->write_fields($configuration);
    print $fd join("\n", @output), "\n";

    close($fd);
    return;
}

1;

__END__
=head1 NAME

Filmore::ConfigFile reads and writes configuration files

=head1 SYNOPSIS

	use Filmore::ConfigFile;
    my $obj = Filmore::ConfigFile->new(config_file => 'example.cfg');
    my $configuration = {};
    $obj->read_file($configuration);
    $obj->write_file($configuration);

=head1 DESCRIPTION

The class reads and writes configuration files. The parameters stored in
configuration files are used to initialize objects when they are created.
Configuration file lines are organized as lines containing

    NAME = VALUE

and may contain blank lines or comment lines starting with a C<#>. The
ConfguredObject class reads a configuration file to override default
parameter values.

If a name is repeated in the configuration file, the values are treated
as an array of values. A name can also contain one or more dots. If it
does, the value is treated like a hash, where the first part of the name
isthe nameof the hash and the second part the name of the field in the
hash.

If a line does not have an equals sign, it is a command. The first word
is the command name and the remaining words are arguments. Only one
command is currently supported, the include command, which includes
the text of another file as if it were part of the configuration file.

=head1 AUTHOR

Bernie Simon, E<lt>bernie.simon@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Bernie Simon

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
