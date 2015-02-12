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
# Combine an array of hashes into a single hash

sub combine_hashes {
    my ($self, @array) = @_;

    my $config = shift(@array) || {};

    while (@array) {
        %$config = (%$config, %{shift @array});
    }

    return $config;
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
    my @array = $self->read_file($filename);
    my $config = $self->combine_hashes(@array);

    %$configuration = (%$config, %$configuration);
    return;
}

#---------------------------------------------------------------------------
# Read a configuration file into a hash

sub read_file {
    my ($self, $filename) = @_;

    my @data = ();
    my $hash = {};
    my $field = '';
    my $fd = IO::File->new($filename, "r");

    my $n = 0;
    if ($fd) {
        $n ++;
        while (my $line = <$fd>) {
            if ($line =~/\S/) {
                $line =~ s/\s+$//;

                if ($line =~ /^\s+/) {
                    die "Indentation error in $filename on line $n\n"
                        unless length $field;

                    $line =~ s/^\s+/\n/;
                    $hash->{$field} .= $line;

                } elsif ($line =~ /^#/) {
                    $field = '';

                } elsif ($line =~ /=/) {
                    my $value;
                    ($field, $value) = split(/\s*=\s*/, $line, 2);
                    $hash->{$field} = $value;

                } else {
                    my ($cmd, $arg) = split(' ', $line, 2);
                    if ($cmd eq 'include') {
                        # Include file
                        push(@data, $hash) if %$hash;

                        $filename = $self->get_filename(INCLUDE_EXT, $arg);
                        my @subarray = $self->read_file($filename);
                        $hash = $self->combine_hashes(@subarray);

                        push(@data, $hash);
                        $hash = {};

                    } else {
                        die "Indentation error in $filename on line $n\n";
                    }
                }

            } elsif (%$hash) {
                push(@data, $hash);
                $field = '';
                $hash = {};
            }
        }

        close($fd);
    }

    push(@data, $hash) if %$hash;
    return @data;
}

#---------------------------------------------------------------------------
# Convert data structure to string

sub write_fields {
    my ($self, $data, $name) = @_;

    my @output;
    my $ref = ref $data;

    if (defined $name) {
        die "Can't write a $ref\n" if $ref;

        $data =~ s/\n/\n    /g;
        push(@output, "$name = $data");

    } elsif ($ref eq 'ARRAY') {
        foreach my $subdata (@$data) {
            push(@output, $self->write_fields($subdata));
        }

    } elsif ($ref eq 'HASH') {
        foreach my $name (sort keys %$data) {
            push(@output, $self->write_fields($data->{$name}, $name));
        }

    } else {
        die "Can't write a $ref\n";
    }

    return @output;
}

#----------------------------------------------------------------------
# Write a configuration file from a hash

sub write_file {
    my ($self, $filename, $data) = @_;

    my $fd = IO::File->new($filename, 'w');
    die "Couln't write $filename: $!" unless $fd;

    my @output = $self->write_fields($data);
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

If subsequent lines are indented, they are considered part of the previous
line.

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
