use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Create an object that handles file operations

package App::Filmore::WebFile;

use Cwd;
use IO::Dir;
use IO::File;
use File::Copy;
use Digest::MD5 qw(md5_hex);
use File::Spec::Functions qw(abs2rel catfile rel2abs splitdir);

use lib '../../../lib';
use base qw(App::Filmore::ConfiguredObject);

use constant VALID_NAME => qr(^([a-z][\-\w]*\.?\w*)$);

#----------------------------------------------------------------------
# Set default values

sub parameters {
    my ($pkg) = @_;

    my %parameters = (
                    nonce => 0,
                    group => '',
                    data_dir => '',
                    valid_read => [],
                    valid_write => [],
					index_name => 'index',
					permissions => 0664,
	);

    return %parameters;
}

#----------------------------------------------------------------------
# Copy file

sub copy_file {
    my ($self, $input_file, $output_file) = @_;
    
    $input_file = $self->validate_filename($input_file, 'r');
    $output_file = $self->validate_filename($output_file, 'w');
    copy($input_file, $output_file) or die "Copy failed: $!";
    
    return;
}

#----------------------------------------------------------------------
# Check path and create directories as necessary

sub create_dirs {
    my ($self, @dirs) = @_;

    my $path = $self->validate_filename($self->{data_dir}, 'r');
	
    foreach my $dir (@dirs) {
        next if $dir eq '.';

        my ($part) = $dir =~ /^([\w-]*)$/;
        die "Illegal directory: $dir\n" unless $part;
        $path .= "/$part";

        if (! -d $path) {
            mkdir ($path) or die "Couldn't create $path: $!\n";
            $self->set_group($path);
			my $permissions = $self->{permissions} | 0111;
            chmod($permissions, $path);
        }
    }

    return;
}

#----------------------------------------------------------------------
# Get file modification time if file exists

sub get_modtime {
    my ($self, $filename) = @_;
    return unless -e $filename;

    my @stats = stat($filename);
    my $mtime = $stats[9];

    my ($modtime) = $mtime =~/^(\d+)$/; # untaint
    return $modtime;
}

#----------------------------------------------------------------------
# Create the nonce for validated form input

sub get_nonce {
    my ($self) = @_;
    return $self->{nonce} if $self->{nonce};

    my $nonce = time() / 24000;
    return md5_hex($(, $nonce, $>);
}


#----------------------------------------------------------------------
# Read contents of file

sub reader {
    my ($self, $filename) = @_;

    # Check filename and make absolute
    $filename = $self->validate_filename($filename, 'r');

    local $/;
    my $in = IO::File->new($filename, "r");
    die "Couldn't read $filename: $!\n" unless $in;

    flock($in, 1);
    my $input = <$in>;
    close($in);

    return $input;
}

#----------------------------------------------------------------------
# Move to the base directory

sub relocate {
    my ($self, $dir) = @_;

    $dir = $self->untaint_filename($dir);
    chdir($dir) or die "Couldn't move to $dir: $!\n";
    return;
}

#----------------------------------------------------------------------
# Set the group of a file

sub set_group  {
    my ($self, $filename) = @_;

    return unless -e $filename;
    return unless $self->{group};

    my $group_id = getgrnam($self->{group});
    return unless $group_id;
    
    my ($gid) = $group_id =~ /^(\d+)$/; # untaint
    return unless $gid;

    chown(-1, $gid, $filename);
    return;
}

#----------------------------------------------------------------------
# Set the mode of the file i/o

sub set_mode {
    my ($self, $handle, $binmode) = @_;

    if (defined $binmode) {
        $binmode = ':raw' unless $binmode =~ /^:/;
        binmode($handle, $binmode);
    }

    return;
}

#----------------------------------------------------------------------
# Set the file modification time

sub set_modtime {
    my ($self, $filename, $modtime) = @_;

    utime($modtime, $modtime, $filename) if $modtime;
    return;
}

#----------------------------------------------------------------------
# Sort files by modification date, name, or extension

sub sorted_files {
    my ($self, $sort_field, @unsorted) = @_;

    $sort_field =~ s/^([+-])//;
    my $order = $1 || '+';

    my @sorted;
    my @augmented;
    
    if ($sort_field eq 'date') {
        foreach (@unsorted) {
            push(@augmented, [-M, $_]);
        }
				
    } elsif ($sort_field eq 'ext') {
        foreach (@unsorted) {
            my ($ext) = /\.([^\.]*)$/;
            $ext = '' unless defined $ext;
            push(@augmented, [$ext, $_]);
        }
    }

    if (@augmented) {
        @augmented = sort {$a->[0] cmp $b->[0]
                   || $a->[1] cmp $b->[1]} @augmented;
        
        @sorted =  map {$_->[1]} @augmented;

    } else {
        @sorted = sort @unsorted;
    }

    @sorted = reverse @sorted if $order eq '-';
    return @sorted;
}

#----------------------------------------------------------------------
# Split off basename from rest of filename

sub split_filename {
    my ($self, $filename) = @_;

    my @dirs = splitdir($filename);
    my $basename = pop(@dirs);
    
    my $dir = catfile(@dirs) || '';
    return ($dir, $basename);
}

#----------------------------------------------------------------------
# True if variable is tainted

sub taint_check {
    my ($self, $var) = @_;
    return ! eval { eval("#" . substr($var, 0, 0)); 1 };
}

#----------------------------------------------------------------------
# Check if the filename is under a valid directory

sub under_any_dir {
    my ($self, $filename, $mode) = @_;

    my $valid_dirs;
    if ($mode eq 'r') {
        $valid_dirs = $self->{valid_read};
    } else {
        $valid_dirs = $self->{valid_write};
    }

    my $path = rel2abs($filename);
    foreach my $dir (@$valid_dirs) {
        return 1 unless grep {/\.\./} splitdir($path)
    }

    return;
}

#----------------------------------------------------------------------
# Make sure filename passes taint check

sub untaint_filename {
    my ($self, $filename) = @_;

    $filename = rel2abs($filename);
    my ($newname) = $filename =~ m{^([-\w\./]+)$};

    die "Illegal filename: $filename\n" unless $newname;
    die "Tainted filename: $filename\n" if $self->taint_check($newname);

    return $newname;
}

#----------------------------------------------------------------------
# Check to make sure filename is under a valid directory

sub validate_filename {
    my ($self, $filename, $mode) = @_;

    my $valid;
    if ($mode eq 'r') {
        $valid = $self->under_any_dir($filename, 'r') ||
                 $self->under_any_dir($filename, 'w');
    } else {
        $valid = $self->under_any_dir($filename, 'w') &&
                 ! $self->under_any_dir($filename, 'r');
    }

    die "Invalid filename: $filename\n" unless $valid;
    return $self->untaint_filename($filename);
}

#----------------------------------------------------------------------
# Return a closure that visits files in a directory in reverse order

sub visitor {
    my ($self, $top_dir, $sort_field) = @_;
    $sort_field = '' unless defined $sort_field;
    
    my @dirlist;
    my @filelist;
    
    $top_dir = $self->validate_filename($top_dir, 'r');
    push(@dirlist, $top_dir) if -e $top_dir;

    return sub {
        for (;;) {
            my $file = shift @filelist;
            return $file if defined $file;

            my $dir = shift @dirlist;
            return unless defined $dir;

            my $dd = IO::Dir->new($dir) or die "Couldn't open $dir: $!\n";

            # Find matching files and directories
            my $valid_name = VALID_NAME;
            while (defined (my $file = $dd->read())) {

                next unless $file =~ /$valid_name/;
                my $newfile = catfile($dir, $1);

                if (-d $newfile) {
                   push(@dirlist, $newfile);
                } else {
                    push(@filelist, $newfile);                    
                }
            }

            $dd->close;

            @filelist = $self->sorted_files($sort_field, @filelist);
            @dirlist = $self->sorted_files($sort_field, @dirlist);
        }
    };
}

#----------------------------------------------------------------------
# Write file to disk after validating the filename

sub writer {
    my ($self, $filename, $output, $binmode) = @_;
    $filename = abs2rel($filename);

    # Check path and create directories as necessary

    my @dirs = splitdir($filename);
    pop @dirs;
    $self->create_dirs(@dirs);

    # Check filename and make absolute
    $filename = $self->validate_filename($filename, 'w');

    # After validation, write the file
    $self->write_wo_validation($filename, $output, $binmode);
    
    return;
}

#----------------------------------------------------------------------
# Write file to disk without filename validation

sub write_wo_validation{
    my ($self, $filename, $output, $binmode) = @_;

    # Invalidate cache, if any
    $filename = $self->untaint_filename($filename);
    
    # Write file

    my $modtime = $self->get_modtime($filename);

    my $out = IO::File->new($filename, "w");
    die "Couldn't write $filename: $!" unless $out;
    $self->set_mode($out, $binmode);

    flock($out, 2);
    print $out $output if defined $output;
    close($out);

    $self->set_modtime($modtime);
    $self->set_group($filename);
    chmod($self->{permissions}, $filename);

    return;
}

1;

__END__
=head1 NAME

App::Filmore::WebFile encapsulates file i/o

=head1 SYNOPSIS

    use App::Onsite::Support::WebFile;
    my $binmode = 0;
    my $maxlevel= 0;
    my $sort_field = 'id';
    my $obj = App::Onsite::Support::WebFile->new(valid_write => [$dir]);
    my $visitor = $obj->visitor($dir, $maxlevel, $sort_field);
    while (my $file = &$visitor()) {
        my $text = $obj->reader($file, $binmode);
        $obj->writer($file, $data, $binmode);
    }

=head1 DESCRIPTION

This class encapsulates the file i/o performed by Onsite::Editor. All file
access is checked against a list of directories to see if Stiki is allowed
to read or write to the directory. If the access is not in a valid directory,
an error is thrown.

=head1 AUTHOR

Bernie Simon, E<lt>bernie.simon@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Bernie Simon

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
