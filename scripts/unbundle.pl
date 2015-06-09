#!/usr/bin/env perl

use strict;
use warnings;

use IO::Dir;
use IO::File;
use Data::Dumper;
use File::Spec::Functions qw(catfile rel2abs splitdir);

use constant INTERACTIVE_MODE => 1;
use constant CGI_MODE => 2;

#---------------------------------- ------------------------------------
# Main procedure

my $mode = get_mode();

my $request;
if ($mode == INTERACTIVE_MODE) {
    $request = get_arguments();
} elsif ($mode == CGI_MODE) {
    $request = get_request();
}

eval {
    if ($request->{error} = check_request($request)) {
        show_form($mode, $request);
    } else {
        handle_request($mode, $request);
    }
};

if ($@) {
    $request->{error} = $@;
    $request->{dump} = dump_state();
    show_form($mode, $request);
}

#----------------------------------------------------------------------
# Check request to see if it is complete and valid

sub check_request {
    my ($request) = @_;

    my %missing = (
                    url => "Please paste url of this page",
                    user => "Please enter user email and password",
                    pass1 => "Please enter password",
                   );

    my $empty = "Please enter the info to configure this site";
    my $nomatch = "Passwords don't match";

    return $empty unless %$request;

    foreach my $field (keys %missing) {
        return $missing{$field} unless defined $request->{$field}
                         && $request->{$field} =~ /\S/;
    }

    return $nomatch unless $request->{pass1} eq $request->{pass2};

    return;
}

#----------------------------------------------------------------------
# Dump the state of this script

sub dump_state {
    my ($msg) = @_;

    my $dumper = Data::Dumper->new([\%ENV], ['ENV']);
    my $env = $dumper->Dump();

    return $env;
}

#----------------------------------------------------------------------
# Get the arguments from the command line or interactively

sub get_arguments {

    my $request = {};
    while ($request->{error} = check_request($request)) {
        query_args($request);
    }

    return $request;
}

#----------------------------------------------------------------------
# Determine the mode from the statusof stdin and stdout

sub get_mode {

    my $mode;
    if (-t STDIN && -t STDOUT) {
        $mode = INTERACTIVE_MODE;
    } else {
        $mode = CGI_MODE;
    }

    return $mode;
}

#----------------------------------------------------------------------
# Get the request passed to the script

sub get_request {
    my $cgi = CGI->new;
    my %request = $cgi->Vars();

    # Split request parameters when they are arrays

    foreach my $field (keys %request) {
        next unless $request{$field} =~ /\000/;
        my @array = split(/\000/, $request{$field});
        $request{$field} = \@array;
    }

    return \%request;
}

#----------------------------------------------------------------------
# Handle a validated request

sub handle_request {
    my ($mode, $request) = @_;

    set_directory();
    my $context = Snarf->new($request);
    $context->run();

    if ($mode == INTERACTIVE_MODE) {
        print "Scripts initialized\n";
        unlink($0);

    } elsif (-e 'index.html') {
        redirect($context->get('base_url'));
        unlink($0);

    } else {
        $request->{error} = "Scripts initialized";
        show_form($mode, $request);
    }

    return;
}

#----------------------------------------------------------------------
# Query for the user name and password

sub query_args {
    my ($request) = @_;

    print $request->{error}, "\n\n" if $request->{error};

    my @fields = request_fields();
    for my $field (@fields) {
        my $name = $field->{name};

        print $field->{title};
        print "($request->{$name})" if $request->{$name} && $field->{show};
        print ": ";

        my $value = <STDIN>;
        chomp $value;

        $request->{$name} = $value || $request->{$name};
    }

    return;
}

#----------------------------------------------------------------------
# Redirect browser to url

sub redirect {
    my ($url) = @_;

    print "Location: $url\n\n";
    return;
}

#----------------------------------------------------------------------
# Get a list of the request fields

sub request_fields {
    return (
            {name => 'user', title => 'User Email', show => 1},
            {name => 'pass1', title => 'Password'},
            {name => 'pass2', title => 'Repeat Password'},
            {name => 'url', title => 'Site url', show => 1},
            );
}

#----------------------------------------------------------------------
# Set the directory to the one containing the executable

sub set_directory {
    my @path = splitdir(rel2abs($0));
    pop(@path);

    my $dir = catfile(@path);
    chdir($dir);

    return;
}

#----------------------------------------------------------------------
# Show form to get user name and password

sub show_form {
    my ($mode, $request) =  @_;

    my $template = <<'EOS';
<head>
<title>Filmore</title>
<style>
div#header {background: #5f9ea0;color: #fff;}
div#header h1{margin: 0; padding: 10px;}
div#footer {background: #fff; color: #666; border-top: 2px solid #5f9ea0;}
div#footer p{padding: 10px;}
</style>
</head>
<body>
<h1 id="banner">Filmore</h1>
<p>{{error}}</p>

<!--
{{dump}}
-->

<form id="password_form" method="post" action="{{script_url}}">
<b>User Email<b><br />
<input name="user" value="{{user}}" size="20"><br />
<b>Password<b><br />
<input name="pass1" value="" size="20" type="password"><br />
<b>Repeat Password<b><br />
<input name="pass2" value="" size="20" type="password"><br /><br />
<b>Paste URL from Address Bar<b><br />
<input name="url" value="{{url}}" size="60"><br /><br />
<input type="submit" name="cmd" value="Go">
</form>
<div id="footer"><p>This is free software,
licensed on the same terms as Perl.</p></div>
</div>
</body></html>
EOS

    if ($mode == INTERACTIVE_MODE) {
        print $request->{error}, "\n";

    } elsif ($mode == CGI_MODE) {
        $template =~ s/{{([^}]*)}}/$request->{$1} || ''/ge;
        print("Content-type: text/html\n\n$template");
    }

    return;
}

#----------------------------------------------------------------------
# Commands that the snarf command processor will respond to

package SnarfCommand;

use Cwd;
use IO::File;
use File::Spec::Functions qw(catfile splitdir file_name_is_absolute);

use constant DEFAULT_GROUP => '';
use constant DEFAULT_PERMISSIONS => 0644;
use constant DIVIDER => "/* Do not change code below this line */\n";

#----------------------------------------------------------------------

sub new {
    my ($pkg, %args) = @_;

    my $self = {};
    return bless($self, $pkg);
}

#----------------------------------------------------------------------
# Write file that blocks access to directory

sub call_hide {
    my ($self, $context, $directory) = @_;

    my $file = catfile($directory, '.htaccess');
    $self->create_dirs($context, $file);

    my $fd = IO::File->new($file, 'w') or die "Couldn't write $file; $!\n";

    print $fd <<'EOS';
AuthUserFile /dev/null
AuthGroupFile /dev/null
AuthName "No Access"
AuthType Basic
<Limit GET>
order deny,allow
</Limit>
EOS

    close($fd);
    $self->change_permissions($context, $file);

    return;
}

#----------------------------------------------------------------------
# Dump the context to a file, for debugging

sub call_log {
    my ($self, $context, $file) = @_;

    my $dumper = Data::Dumper->new([$context], ['context']);
    my $log = IO::File->new($file, 'w') or die "Couldn't open $file: $!\n";

    print $log $dumper->Dump();
    close($log);

    return;
}

#----------------------------------------------------------------------
# Protect the top directory by writing access, group and password files

sub call_protect {
    my ($self, $context) = @_;

    my $directory = getcwd();
    $self->write_access_file($context, $directory);
    $self->write_group_file($context, $directory);
    $self->write_password_file($context, $directory);

    return;
}

#----------------------------------------------------------------------
# Change the group ownership of a file

sub change_group  {
    my ($self, $file, $group) = @_;

    return unless -e $file;
    return unless $group;

    my $gid = getgrnam($group);
    return unless $gid;

    my $status = chown(-1, $gid, $file);
    return;
}

#----------------------------------------------------------------------
# Change permissions on a file

sub change_permissions {
    my ($self, $context, $file, $modifiers) = @_;
    $modifiers = '' unless defined $modifiers;

    my $permissions = $context->get('permissions') & 0775;
    $permissions |= 0111 if $modifiers =~ /x/;
    $permissions |= 0222 if $modifiers =~ /w/;
    $permissions |= 0444 if $modifiers =~ /r/;

    $self->change_group($file, $context->get('group'));
    chmod($permissions, $file);

    return;
}

#----------------------------------------------------------------------
# Copy the configuration file, noting if the command is protected

sub copy_configuration {
    my ($self, $context, $lines, $file) = @_;

    foreach (@$lines) {
        next if /^#/ || /^\s+/;

        my ($name, $value) = split(/\s*=\s*/, $_);
        next unless $name eq 'protect';

        if ($value) {
            my $basename = $self->get_basename($file);
            $context->{command}->set_note($context, $basename);
        }
    }

    return $self->copy_file($context, $lines, $file);
}

#----------------------------------------------------------------------
# Create a copy of the input file

sub copy_file {
    my ($self, $context, $lines, $file, $mode) = @_;
    $mode = 't' unless defined $mode;

    $file = $self->map_filename($context, $file);
    $self->create_dirs($context, $file);

    my $out = IO::File->new($file, 'w') or die "Couldn't write $file: $!\n";

    if ($mode eq 'b') {
        binmode($out);
        foreach my $line (@$lines) {
            print $out decode_base64($line);
        }

    } else {
        foreach my $line (@$lines) {
            print $out $line;
        }
    }

    close($out);
    return;
}

#----------------------------------------------------------------------
# Update include file and then write it

sub copy_include {
    my ($self, $context, $lines, $file) = @_;

    foreach (@$lines) {
        next if /^#/ || /^\s+/ || ! /=/ ;

        my ($name, $value) = split(/\s*=\s*/, $_);

        my $new_value = $context->get($name);
        $new_value= '' unless defined $new_value;
        $_ = "$name = $new_value\n" if defined $new_value;
    }

    return $self->copy_file($context, $lines, $file);
}

#----------------------------------------------------------------------
# Update cgi script and then write it

sub copy_script {
    my ($self, $context, $lines, $file) = @_;

    my $perl = $context->get('perl');
    my $map = $context->get('map');
    my $library = $context->get('library');
    $library = $self->map_filename($context, $library);

    foreach (@$lines) {
        # Change shebang line
        s/^\#\!(\S+)/\#\!$perl/;
        # Change use lib line
        s/^use lib \'(\S+)\'/use lib \'$library\'/;
    }

    my $status = $self->copy_file($context, $lines, $file);
    $self->change_permissions($context, $file, 'x') if $status;

    return $status;
}

#----------------------------------------------------------------------
# Check path and create directories as necessary

sub create_dirs {
    my ($self, $context, $file) = @_;

    my @dirs = splitdir($file);
    pop @dirs;

    my @path;
    while (@dirs) {
        push(@path, shift(@dirs));
        my $path = catfile(@path);

        if (! -d $path) {
            mkdir ($path) or die "Couldn't create $path: $!\n";
            $self->change_permissions($context, $path, 'x')
        }
    }

    return;
}

#----------------------------------------------------------------------
# Encrypt password

sub encrypt {
	my ($self, $plain) = @_;;

	my $salt = join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];
    return crypt($plain, $salt);
}

#----------------------------------------------------------------------
# Find the path to the sendmail command

sub find_sendmail {
    my ($self) = @_;
    my $path;

    foreach $path (qw(/usr/lib/sendmail /usr/sbin/sendmail)) {
        return $path if -e $path;
    }

    $path = `which sendmail`;
    chomp $path;

    return $path || '';
}

#----------------------------------------------------------------------
# Extract basename from filename

sub get_basename {
    my ($self, $file) = @_;

    my @path = splitdir($file);
    my $root = pop(@path);
    my ($basename, $ext) = split(/\./, $root);

    return $basename;
}

#----------------------------------------------------------------------
# Get the base url from the script url

sub get_base_url {
    my ($self, $request) = @_;

    my $parsed_url = $self->parse_url($request->{url});
    my @script_path = split('/', $parsed_url->{path});
    pop(@script_path);

    my $base_url = @script_path ? join('/', @script_path) : '/';
    return $base_url;
}

#----------------------------------------------------------------------
# Initialize variables for script

sub initialize {
    my ($self, $request) = @_;

    my $base_directory = getcwd();
    my $base_url = $self->get_base_url($request);

    my $sendmail = $self->find_sendmail();
    my $password = $self->encrypt($request->{pass1});

    my $perl = `/usr/bin/which perl`;
    chomp $perl;

    # Set reasonable defaults for parameters

    my $variables = {
                     group => DEFAULT_GROUP,
                     permissions => DEFAULT_PERMISSIONS,
                     perl => $perl,
                     base_directory => $base_directory,
                     base_url => $base_url,
                     sendmail_command => $sendmail,
                     password => $password,
                     valid_read => [$base_directory],
                     web_master => $request->{user},
                    };

    return $variables;
}

#----------------------------------------------------------------------
# Map filename to name on uploaded system

sub map_filename {
    my ($self, $context, $file) = @_;

    my $map = $context->get('map');
    if ($map) {
        my @path = splitdir($file);
        my $dir = shift(@path);

        if (exists $map->{$dir}) {
            if ($map->{$dir}) {
                unshift(@path, $map->{$dir});
            }

        } else {
            unshift(@path, $dir);
        }

        $file = catfile(@path);
    }

    return $file;
}

#----------------------------------------------------------------------
# Parse a url into its components

sub parse_url {
    my ($self, $url) = @_;
    die "Url undefined" unless defined $url;

    my %parsed_url = (method => 'http:', domain => '', path => '',
                      file => '', params => '');

    my ($method, $rest) = split(m!//!, $url, 2);

    unless (defined $rest) {
        $rest = $method;
    } else {
        $parsed_url{method} = $method;
    }


    if ($rest) {
        my ($rest, $params) = split(/\?/, $rest);
        $parsed_url{params} = $params || '';
        my @path = split(m!/!, $rest);

        if (@path) {
            if ($path[0] =~ /\.(com|org|edu|us)$/) {
                $parsed_url{domain} = $path[0];
                $path[0] = '';
            }

            $parsed_url{file} = pop(@path) if $path[-1] =~ /\./;
            $parsed_url{path} = join('/', @path);
        }
    }

    return \%parsed_url;
}

#----------------------------------------------------------------------
# Read the access control file up until a divider comment

sub read_access_file {
    my ($self, $file) = @_;

    my $fd;
    $fd = IO::File->new($file, 'r') if -e $file;
    my @lines = ('');

    if ($fd) {
        while (<$fd>) {
            last if $_ eq DIVIDER;
            push(@lines, $_);
        }

        close $fd;
    }

    return join('', @lines);
}

#----------------------------------------------------------------------
# Read the groups files

sub read_groups_file {
    my ($self, $file, $note, $web_master) = @_;
    my $scripts = {};

    my $fd;
    $fd = IO::File->($file, 'r') if -e $file;

    if ($fd) {
        while (<$fd>) {
            chomp;
            my ($group, $user_list) = split(/\s*:\s*/, $_, 2);
            next unless $group && exists $scripts->{$group};

            my %users = map {$_ => 1} split(' ', $user_list);
            $users{$web_master} = 1;

            $scripts->{$group} = \%users;
        }

        close $fd;
    }

    foreach my $group (keys %$note) {
        next if $scripts->{$group};
        $scripts->{$group} = {$web_master => 1};
    }

    return $scripts;
 }

#----------------------------------------------------------------------
# Read the current password file into a hash

sub read_password_file {
    my ($self, $file) = @_;

    my $fd;
    my %passwords;
    $fd = IO::File->($file, 'r') if -e $file;

    if ($fd) {
        while (<$fd>) {
            chomp;
            my ($user, $password) = split(/\s*:\s*/, $_, 2);
            next unless $password;

            $passwords{$user} = $password;
        }

        close $fd;
    }

    return \%passwords;
}

#----------------------------------------------------------------------
# Convert relative filename to absolute

sub rel2abs {
    my ($self, $filename) = @_;

    my @path;
    my $base_dir = getcwd();
    @path = splitdir($base_dir) unless file_name_is_absolute($filename);
    push(@path, splitdir($filename));

    my @newpath = ('');
    while (@path) {
        my $dir = shift @path;
        if ($dir eq '' or $dir eq '.') {
            ;
        } elsif ($dir eq '..') {
            pop(@newpath) if @newpath > 1;
        } else {
            push(@newpath, $dir);
        }
    }

    $filename = catfile(@newpath);
    return $filename;
}

#----------------------------------------------------------------------
# Add a mapping from source to target location

sub set_map {
    my ($self, $context, $source, $target) = @_;

    $target = '' unless defined $target;
    my $map = $context->get('map');

    unless ($map) {
        $map = {};
        $context->set('map', $map);
    }

    $map->{$source} = $target;
    return;
}

#----------------------------------------------------------------------
# Add a mapping from source to target location

sub set_note {
    my ($self, $context, $name) = @_;

    my $note = $context->get('note');

    unless ($note) {
        $note = {};
        $context->set('note', $note);
    }

    $note->{$name} = 1;
    return;
}

#----------------------------------------------------------------------
# Write access file for password protected site

sub write_access_file {
    my ($self, $context, $directory) = @_;

    $directory = $self->rel2abs($directory);
    my $file = catfile($directory, '.htaccess');
    my $text = $self->read_access_file($file);

    my $fd = IO::File->new($file, 'w') or return;

    print $fd $text;
    print $fd DIVIDER;
    my $note = $context->get('note');
    foreach my $basename (keys %$note) {

        print $fd <<"EOS";
<Files "$basename.cgi">
  AuthName "Password Required"
  AuthType Basic
  AuthUserFile $directory/.htpasswd
  AuthGroupFile $directory/.htgroups
  Require group $basename
</Files>
EOS
    }

    close($fd);
    $self->change_permissions($context, $file, 'w');
    return 1;
}

#----------------------------------------------------------------------
# Write group file for password protected site

sub write_group_file {
    my ($self, $context, $directory) = @_;

    my $file = catfile($directory, '.htgroups');

    my $note = $context->get('note');
    my $web_master = $context->get('web_master');

    my $scripts = $self->read_groups_file($file, $note, $web_master);

    my $fd = IO::File->new($file, 'w') or return;

    foreach my $basename (keys %$scripts) {
        my $user_list = join(' ', sort keys %{$scripts->{$basename}});
        print $fd "$basename: $user_list\n";
    }

    close($fd);
    $self->change_permissions($context, $file);

    return;
}

#----------------------------------------------------------------------
# Write password file

sub write_password_file {
    my ($self, $context, $directory)= @_;

    my $web_master = $context->get('web_master');
    my $password = $context->get('password');

    my $file = catfile($directory, '.htpasswd');
    my $passwords = $self->read_password_file($file);
    $passwords->{$web_master} = $password;

    my $fd = IO::File->new($file, 'w') or return;

    foreach my $user (sort keys %$passwords) {
        my $password = $passwords->{$user};
        print $fd "$user:$password\n";
    }

    close($fd);
    $self->change_permissions($context, $file);

    return;
}

#----------------------------------------------------------------------
# A very simple command processor based around copying files

package Snarf;

use Cwd;
use constant CMD_PREFIX => '#>>>';

#----------------------------------------------------------------------
# Createa new command pocessor

sub new {
    my ($pkg, $request) = @_;

    my $self = bless({}, $pkg);
    $self->{command} = SnarfCommand->new();
    $self->{var} = $self->{command}->initialize($request);

    return $self;
}

#----------------------------------------------------------------------
# Read and processcommands in DATA sement of file

sub run {
    my ($self) = @_;

    my ($read, $unread) = $self->data_readers();

    while (my ($command, $lines) = $self->next_command($read, $unread)) {
        my @args = split(' ', $command);
        my $cmd = shift @args;
        my $subcmd = shift @args;

        $self->error("Error in command name", $command) unless defined $subcmd;

        $self->error("Missing lines after command", $command)
            if $cmd eq 'copy' && @$lines == 0;

        $self->error("Unexpected lines after command", $command)
            if $cmd ne 'copy' && @$lines > 0;

        my $method = join('_', $cmd, $subcmd);

        if ($cmd eq 'call') {
            $self->error("Error in command name", $command)
                unless defined $self->{command}->can($method);
            $self->{command}->$method($self, @args);

        } elsif ($cmd  eq 'copy') {
           $self->error("Error in command name", $command)
                unless defined $self->{command}->can($method);

            $self->{command}->$method($self, $lines, @args);

        } elsif ($cmd eq 'set') {
            if ($self->{command}->can($method)) {
                $self->error("No arguments for set command", $command)
                    unless @args;
                $self->{command}->$method($self, @args);

            } else {
                @args = ('') unless @args;
                my $value = join(' ', @args);
                $self->set($subcmd, $value);
            }

        } else {
            $self->error("Error in command name", $command);
        }
    }

    return;
}

#----------------------------------------------------------------------
# Return closures to read the data section of this file

sub data_readers {
    my ($self) = @_;
    my @pushback;

    my $read = sub {
        if (@pushback) {
            return pop(@pushback);
        } else {
            return <DATA>;
        }
    };

    my $unread = sub {
        my ($line) = @_;
        push(@pushback, $line);
    };

    return ($read, $unread);
}

#----------------------------------------------------------------------
# Die with error

sub error {
    my ($self, $msg, $line) = @_;
    die "$msg: " . substr($line, 0, 30) . "\n";
}

#----------------------------------------------------------------------
# Get a value by name

sub get {
    my ($self, $name) = @_;

    return unless exists $self->{var}{$name};
    return $self->{var}{$name};
}

#----------------------------------------------------------------------
# Is the line a command?

sub is_command {
    my ($self, $line) = @_;

    my $command;
    my $prefix = CMD_PREFIX;

    if ($line =~ s/^$prefix//) {
        $command = $line;
        chomp $command;
    }

    return $command;
}

#----------------------------------------------------------------------
# Get the name and contents of the next file

sub next_command {
    my ($self, $read, $unread) = @_;

    my $line = $read->();
    return unless defined $line;

    my $command = $self->is_command($line);
    die "Command not supported: $line" unless $command;

    my @lines;
    while ($line = $read->()) {
        if ($self->is_command($line)) {
            $unread->($line);
            last;

        } else {
            push(@lines, $line);
        }
    }

    return ($command, \@lines);
}

#----------------------------------------------------------------------
# Get a value by name

sub set {
    my ($self, $name, $value) = @_;

    $self->{var}{$name} = $value;
    return;
}
