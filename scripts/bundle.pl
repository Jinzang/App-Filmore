#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use IO::File;
use IO::Dir;
use MIME::Base64  qw(encode_base64);
use File::Spec::Functions qw(catfile no_upwards);

use constant CMD_PREFIX => '#>>>';

#----------------------------------------------------------------------
# Configuration

my $script = 'scripts/unbundle.pl';
my $library = 'lib';

my $include = {
               'site' => '',
               'site/config' => 'config',
               'lib' => 'lib',
               'lib/Filmore' => 'lib/Filmore',
               };

my $types = {
             'inc' => 'include',
             'cfg' => 'configuration',
             'cgi' => 'script',
            };

#----------------------------------------------------------------------
# Main routine

my $output = shift (@ARGV) or die "Must supply name of output file";
my $out = IO::File->new($output, 'w');
die "Can't write to $output: $!\n" unless $out;

chdir("$Bin/..") or die "Couldn't cd to $Bin directory\n";

copy_script($out, $script);
include_dirs($out, $include);

my $visitor = get_visitor($include);

while (my $file = &$visitor) {
    bundle_file($include, $types, $out, $file);
}

protect_dirs($out, $include);
close($out);

chmod(0775, $output);

#----------------------------------------------------------------------
# Append a text file to the bundle

sub append_binary_file {
    my ($out, $file) = @_;


    my $in = IO::File->new($file, 'r');
    die "Couldn't read $file: $!\n" unless $in;

    binmode $in;
    my $buf;

    while (read($in, $buf, 60*57)) {
        print $out encode_base64($buf);
    }

    close($in);
    return;
}

#----------------------------------------------------------------------
# Append a text file to the bundle

sub append_text_file {
    my ($out, $file) = @_;

    my $in = IO::File->new($file, 'r');
    die "Couldn't read $file: $!\n" unless $in;

    while (defined (my $line = <$in>)) {
        print $out $line;
    }

    close($in);
    return;
}

#----------------------------------------------------------------------
# Add a file, prefaced with a comment indicating its name and type

sub bundle_file {
    my ($mapping, $types, $out, $file) = @_;

    my ($root, $ext) = split(/\./, $file);

    my $type = 'file';
    $type = $types->{$ext} if defined $ext && exists $types->{$ext};

    my $bin = -B $file ? 'b' : 't';
    print $out CMD_PREFIX, "copy $type $file $bin\n";

    if ($bin eq 'b') {
        append_binary_file($out, $file);
    } else {
        append_text_file($out, $file)
    }

    return;
}

#----------------------------------------------------------------------
# Copy the script to start

sub copy_script {
    my ($out, $script) = @_;

    my @path = split(/\//, $script);
    $script = catfile(@path);

    append_text_file($out, $script);
    print $out "__DATA__\n";
    return;
}

#----------------------------------------------------------------------
# Return a closure that visits files in a directory in reverse order

sub get_visitor {
    my ($include) = @_;

    my @dirlist = keys %$include;
    my @filelist;

    return sub {
        for (;;) {
            my $file = shift @filelist;
            return $file if defined $file;

            my $dir = shift @dirlist;
            return unless defined $dir;

            my @path = split(/\//, $dir);
            $dir = catfile(@path);

            my $dd = IO::Dir->new($dir) or die "Couldn't open $dir: $!\n";

            while (defined (my $file = $dd->read())) {
                $file = catfile($dir, $file) if $dir;
                push(@filelist, $file) unless -d $file;
            }

            $dd->close;
        }
    };
}

#----------------------------------------------------------------------
# Save names of directories to output file

sub include_dirs {
    my ($out, $include) = @_;

    while (my ($source, $target) = each %$include) {
        print $out CMD_PREFIX, "set map $source $target\n";
    }

    print $out CMD_PREFIX, "set library $library\n";
    return;
}

#----------------------------------------------------------------------
# Save names of directories to output file

sub protect_dirs {
    my ($out, $include) = @_;

    print $out CMD_PREFIX, "call protect\n";
    foreach my $target (values %$include) {
        next unless $target;
        print $out CMD_PREFIX, "call hide $target\n";
    }

    return;
}
