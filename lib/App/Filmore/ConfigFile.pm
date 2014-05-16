use strict;
use warnings;
use integer;

package App::Filmore::ConfigFile;

use lib '../../../lib';
use base qw(App::Filmore::ConfiguredObject);
use IO::File;

my %cache;
our $VERSION = '0.01';

#----------------------------------------------------------------------
# Get hardcoded default parameter values

sub parameters {
	my ($pkg) = @_;

	return (
			config_file => '',
		   );
}

#----------------------------------------------------------------------
# Set the configuration values from a file

sub populate_object {
	my ($self, $configuration) = @_;

    $self->SUPER::populate_object($configuration);
    $self->read_file($configuration);
    
    return $self;
}

#----------------------------------------------------------------------
# Read a configuration file into a hash

sub read_file {
    my ($self, $configuration) = @_;

    return unless $self->{config_file};
    return unless -e $self->{config_file};
    
    unless (%cache) {
        my $fd = IO::File->new($self->{config_file}, 'r');
        die "Couln't read $self->{config_file}: $!" unless $fd;
        
        while (my $line = <$fd>) {
            # Ignore comments and blank lines
            next if $line =~ /^\s*\#/ || $line !~ /\S/;
    
            # Split line into name and value, remove leading and
            # trailing whitespace
    
            my ($name, $value) = split (/\s*=\s*/, $line, 2);
            die "Bad line in config file: ($name)" unless defined $value;
    
            $value =~ s/\s+$//;
            $cache{$name} = $value;
        }

        close($fd);
    }
    
    %$configuration = (%cache, %$configuration);
    return;
}

#----------------------------------------------------------------------
# Write a configuration file from a hash

sub write_file {
    my ($self, $configuration) = @_;

    die "Configuration file undefined" unless $self->{config_file};
    
    my $fd = IO::File->new($self->{config_file}, 'w');
    die "Couln't read $self->{config_file}: $!" unless $fd;

    undef %cache;
    
    my $pkg = ref $self;
    my %parameters = $pkg->parameters();
    
    foreach my $name (sort keys %$configuration) {
        next if exists $parameters{$name};

        my $value = $configuration->{$name};
        $value = ref $value if ref $value;
        
        print $fd "$name = $value\n";
    }

    close($fd);
    return;
}

1;

__END__
=head1 NAME

App::Filmore::ConfigFile reads and writes configuration files

=head1 SYNOPSIS

	use App::Filmore::ConfigFile;
    $obj = App::Filmore::ConfigFile->new(config_file => 'example.cfg');
    my $configuration = $obj->read_file();
    $obj->write_file($configuration);

=head1 DESCRIPTION

The class reads and writes configuration files. The parameters stored in
configuration files are used to initialize objects when they are created.
Configuration file lines are organized as lines containing

    NAME = VALUE

and may contain blank lines or comment lines starting with a C<#>. The
ConfguredObject class reads a configuration file to override default
parameter values. 

=head1 AUTHOR

Bernie Simon, E<lt>bernie.simon@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Bernie Simon

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
