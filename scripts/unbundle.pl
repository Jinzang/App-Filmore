#!/usr/bin/env perl

use strict;
use warnings;

use CGI;
use Cwd;
use IO::Dir;
use IO::File;
use Data::Dumper;
use MIME::Base64 qw(decode_base64);
use File::Spec::Functions qw(catfile splitdir file_name_is_absolute);

use constant DEFAULT_GROUP => '';
use constant DEFAULT_PERMISSIONS => 0666;

our $modeline;
my $interactive = is_interactive();

my $request;
if ($interactive) {
    $request = get_arguments(@ARGV);
} else {
    $request = get_request();
}

eval {
    if ($request->{error} = check_request($request)) {
        show_form($interactive, $request);
    } else {
        run($interactive, $request);
    }
};

if ($@) {
    $request->{error} = $@;
    $request->{dump} = dump_state();
    show_form($interactive, $request);
}

#----------------------------------------------------------------------
# Main routine

sub run {
    my ($interactive, $request) = @_;

    my $include = get_include();
    my %parameters = set_parameters($include, $request);

    my $scripts = copy_site($include, %parameters);
    protect_files($include, $request, $scripts, \%parameters);

    if ($interactive) {
        print "Scripts initialized\n";
        unlink($0);

    } elsif (-e 'index.html') {
        redirect($parameters{base_url});
        unlink($0);

    } else {
        $request->{error} = "Scripts initialized";
        show_form($interactive, $request);
    }

    return;
}

#----------------------------------------------------------------------
# Check request to see if it is complete and valid

sub check_request {
    my ($request) = @_;

    my %missing = (
                    url => "Please paste url of this page",
                    user => "Please enter user email and password",
                    password => "Please enter password",
                   );
    
    my $nomatch = "Passwords don't match";
    
    foreach my $field (keys %missing) {
        return $missing{$field} unless exists $request->{$field}
                         && $request->{$field} =~ /\S/;
    }
    
    return $nomatch unless $request->{pass1} eq $request->{pass2};
    
    return;
}

#----------------------------------------------------------------------
# Build an argument list from the command line, for testing

sub command_line {
    my @args = @_;
    
    my %request;
    foreach my $arg (@args) {
        my ($name, $value);
        if ($arg =~ /=/) {
            ($name, $value) = split(/=/, $arg, 2);
            $request{$name} = $value;
        }
    }

    $request{pass2} ||= $request{pass1};
    return \%request;
}

#----------------------------------------------------------------------
# Read the script configuration information

sub configuration_info {
    my ($file, $text) = @_;

    my $info = {};
    my %vars = map {$_ => 1} qw(public);
    my @lines = split(/\n/, $text);
    my ($basename) = get_basename($file);

    foreach my $line (@lines) {
        next if $line =~ /^\s*\#/;

        my ($name, $value) = split(/\s*=\s*/, $line);
        next unless defined $value;

        $value =~ s/\s+$//;
        $info->{$name} = $value if $vars{$name};
    }

    return ($basename, $info);    
}

#----------------------------------------------------------------------
# Create a copy of the input file

sub copy_file {
    my ($mode, $file, $text) = @_;

    my $out = IO::File->new($file, 'w') or die "Can't write $file";

    if ($mode eq 'b') {
        binmode($out);
        my @lines = split(/\n/, $text);
        foreach my $line (@lines) {
            print $out decode_base64($line);
        }

    } else {
        chomp $text;
        print $out $text;        
    }
    
    close($out);
    return;
}

#----------------------------------------------------------------------
# Copy initial version of website to target

sub copy_site {
    my ($include, %parameters) = @_;   

    my $scripts = {};
    while (my ($mode, $file, $text) = next_file()) {
        $file = map_filename($include, $file);
        create_dirs($file, \%parameters);        
        my $modifiers;

        if ($file =~ /\.cgi$/) {
            $modifiers = 'x';
            my $parameters = update_parameters($file, %parameters);
            $text = edit_script($file, $text, $include, $parameters);

        } elsif ($file =~ /\.cfg$/) {
            my $parameters = update_parameters($file, %parameters);
            $text = update_configuration($text, $parameters);

            my ($basename, $info) = configuration_info($file, $text);
            $scripts->{$basename} = $info;
        }
    
        copy_file($mode, $file, $text);    
        set_permissions($file, \%parameters, $modifiers);
    }

    return $scripts;
}

#----------------------------------------------------------------------
# Check path and create directories as necessary

sub create_dirs {
    my ($file, $parameters) = @_;

    my @dirs = split(/\//, $file);
    pop @dirs;
    
    my @path = ('/');
    while (@dirs) {
        push(@path, shift(@dirs));
        my $path = catfile(@path);

        if (! -d $path) {
            mkdir ($path) or die "Couldn't create $path: $!\n";
            set_permissions($path, $parameters, 'x')
        }
    }

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
# Edit script to work on website

sub edit_script {
    my ($file, $text, $include, $parameters) = @_;
        
    # Change shebang line
    my $perl = `/usr/bin/which perl`;
    chomp $perl;
    $text =~ s/\#\!(\S+)/\#\!$perl/;

    # Change use lib line
    if ($text =~ /use lib/) {
        $text  =~ s/use lib \'(\S+)\'/use lib \'$include->{lib}\'/;
    }
    
    # Set configuration file

    if ($text =~ /my \$config_file/) {
        $text  =~ s/my \$config_file = \'(\S*)\'/my \$config_file = \'$parameters->{config_file}\'/;
    }
    
    return $text;
}

#----------------------------------------------------------------------
# Encrypt password

sub encrypt {
	my ($plain) = @_;;

	my $salt = join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];
    return crypt($plain, $salt);
}

#----------------------------------------------------------------------
# Find the path to the sendmail command

sub find_sendmail {
    my $path;
    
    foreach $path (qw(/usr/lib/sendmail /usr/sbin/sendmail)) {
        return $path if -e $path;       
    }
    
    $path = `which sendmail`;
    chomp $path;
    
    return $path || '';
}

#----------------------------------------------------------------------
# Get the arguments from the command line or interactively

sub get_arguments {
    my @args = @_;
    
    my $request = command_line(@args);
    while ($request->{error} = check_request($request)) {
        query_args($request);
    }
    
    return $request;
}

#----------------------------------------------------------------------
# Extract basename from filename

sub get_basename {
    my ($file) = @_;
    
    my @path = splitdir($file);
    my $root = pop(@path);
    my ($basename, $ext) = split(/\./, $root);
    
    return $basename;
}

#----------------------------------------------------------------------
# Get the locations of the directories we need

sub get_include {
    # Set directory to one containing this script
    
    my $dir = $0;
    $dir =~ s{/?[^/]*$}{};
    $dir ||= '.';
    
    chdir $dir or die "Cannot cd to $dir";
    
    my $include = {};
    while (my ($source, $target) = next_dir()) {
        $include->{$source} = rel2abs($target);
    }
    
    return $include;    
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
# Check if script is being run interactively

sub is_interactive {
    return -t STDIN && -t STDOUT
}

#----------------------------------------------------------------------
# Map filename to name on uploaded system

sub map_filename {
    my ($include, $file) = @_;
    
    my @path = splitdir($file);
    my $dir = shift(@path);
    
    if (exists $include->{$dir}) {
        unshift(@path, $include->{$dir}) if $include->{$dir};
        $file = catfile(@path);
    }
        
    return $file;
}

#----------------------------------------------------------------------
# Get the name of the next directory

sub next_dir {
    $modeline = <DATA>;
    return unless $modeline =~ /^\#\+\+\%X\+\+\%X/;
    
    my ($comment, $source, $target) = split(' ', $modeline);
    die "Bad modeline: $modeline\n" unless defined $source;
    $target = '' unless defined $target;
    
    return ($source, $target)
}

#----------------------------------------------------------------------
# Get the name and contents of the next file

sub next_file {
    
    return unless $modeline;
    my ($comment, $mode, $file) = split(' ', $modeline);
    die "Bad modeline: $modeline\n" unless defined $file;
    
    my $text = '';
    $modeline = '';
    
    while (<DATA>) {
        if (/^\#--\%X--\%X/) {
            $modeline = $_;
            last;

        } else {
            $text .= $_;
        }
    }
    
    return ($mode, $file, $text);
}

#----------------------------------------------------------------------
# Parse a url into its components

sub parse_url {
    my ($url) = @_;

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
# Protect the files with access and password files

sub protect_files {
    my ($include, $request, $scripts, $parameters) = @_;

    while (my($source, $target) = each %$include) {
        if ($source eq 'site') {
            write_access_file($target, $scripts, $parameters);
            write_group_file($target, $request, $scripts, $parameters);
            write_password_file($target, $request, $parameters);

        } else {
            write_no_access_file($target, $parameters);
        }
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
# Read the access control file up until a files command is seen

sub read_access_file {
    my ($file) = @_;
    
    my $fd;
    $fd = IO::File->($file, 'r') if -e $file;
    my @lines = ('');

    if ($fd) {
        while (<$fd>) {
            last if /^<Files/;
            push(@lines, $_);
        }

        close $fd;
    }

    return join('', @lines);
}

#----------------------------------------------------------------------
# Read the groups files

sub read_groups_file {
    my ($file, $scripts) = @_;    

    my $fd;
    $fd = IO::File->($file, 'r') if -e $file;
 
    if ($fd) {
        while (<$fd>) {
            chomp;
            my ($group, $user_list) = split(/\s*:\s*/, $_, 2);
            next unless $group && exists $scripts->{$group};
            
            my %users = map {$_ => 1} split(' ', $user_list);
            $scripts->{$group}{users} = \%users;
        }

        close $fd;
    }
    
    return $scripts;
 }

#----------------------------------------------------------------------
# Read the current password file into a hash

sub read_password_file {
    my ($file, $scripts) = @_;    

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
    
    return $scripts;
 }

#----------------------------------------------------------------------
# Redirect browser to url

sub redirect {
    my ($url) = @_;
    
    print "Location: $url\n\n";
    return;
}

#----------------------------------------------------------------------
# Convert relative filename to absolute

sub rel2abs {
    my ($filename) = @_;

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
# Set the base url from the script url

sub set_base_url {
    my ($request) = @_;
    
    my $parsed_url = parse_url($request->{url});
    my @script_path = split('/', $parsed_url->{path});
    pop(@script_path);
        
    my $base_url = join('/', @script_path);
    return $base_url;
}

#----------------------------------------------------------------------
# Set the group of a file

sub set_group  {
    my ($filename, $group) = @_;

    return unless -e $filename;
    return unless $group;

    my $gid = getgrnam($group);
    return unless $gid;

    my $status = chown(-1, $gid, $filename);
    return;
}

#----------------------------------------------------------------------
# Set parameters for script

sub set_parameters {
    my ($include, $request) = @_;

    my $base_directory = getcwd();
    my $base_url = set_base_url($request);
    my $sendmail = find_sendmail();
    
    # Set reasonable defaults for parameters
    
    my %parameters = (
                    group => DEFAULT_GROUP,
                    permissions => DEFAULT_PERMISSIONS,
                    base_directory => $base_directory,
                    base_url => $base_url,
                    config_file => "*.cfg",
                    sendmail_command => $sendmail,
                    site_template => "$include->{templates}/*.htm",
                    valid_read => [$base_directory],
                    web_master => $request->{user},
                   );

    return %parameters;
}

#----------------------------------------------------------------------
# Set permissions on a file

sub set_permissions {
    my ($file, $parameters, $modifiers) = @_;
    $modifiers = '' unless defined $modifiers;

    my $permissions = $parameters->{permissions} & 0775;
    $permissions |= 0111 if $modifiers =~ /x/;
    $permissions |= 0222 if $modifiers =~ /w/;
    $permissions |= 0444 if $modifiers =~ /r/;    
    
    set_group($file, $parameters->{group});
    chmod($permissions, $file);

    return;
}

#----------------------------------------------------------------------
# Show form to get user name and password

sub show_form {
    my ($interactive, $request) =  @_;    
    
    my $template = <<'EOS';
<head>
<title>Onsite Editor</title>
<style>
div#header {background: #5f9ea0;color: #fff;}
div#header h1{margin: 0; padding: 10px;}
div#footer {background: #fff; color: #666; border-top: 2px solid #5f9ea0;}
div#footer p{padding: 10px;}
</style>
</head>
<body>
<h1 id="banner">Onsite Editor</h1>
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

    if ($interactive) {
        print $request->{error}, "\n";
    } else {
        $template =~ s/{{([^}]*)}}/$request->{$1} || ''/ge;
        print("Content-type: text/html\n\n$template");
    }
    
    return;
}

#----------------------------------------------------------------------
# Update configuration file

sub update_configuration {
    my ($text, $parameters) = @_;

    my %done;
    my @new_lines;
    my @lines = split(/\n/, $text);
    
    foreach my $line (@lines) {
        if ($line =~ /^\s*#/) {
            push(@new_lines, $line);

        } else {
            my ($name, $value) = split(/\s*=\s*/, $line);
 
            if (! defined $value) {
                push(@new_lines, $line);

            } elsif (! $done{$name}) {
                if ($parameters->{$name}) {
                    if (ref $parameters->{$name} eq 'ARRAY') {
                        foreach my $val (@{$parameters->{$name}}) {
                            push(@new_lines, "$name = $val");
                        }

                    } else {
                        push(@new_lines, "$name = $parameters->{$name}")
                    }
                    $done{$name} = 1;

                } else {
                    push(@new_lines, $line);
                }
            }
        }
    }
    
    return join("\n", @new_lines) . "\n";
}

#----------------------------------------------------------------------
# Update parameters by substituting for wild card

sub update_parameters {
    my ($file, %parameters) = @_;

    my ($basename) = get_basename($file);
    
    while (my ($name, $value) = each %parameters) {
        $value =~ s/\*/$basename/;
        $parameters{$name} = $value;        
    }

    return \%parameters;
}

#----------------------------------------------------------------------
# Write access file for password protected site

sub write_access_file {
    my ($directory, $scripts, $parameters) = @_;

    my $file = "$directory/.htaccess";

    my $text = read_access_file($file);
    
    my $fd = IO::File->new($file, 'w')
        or die "Can't open $file: $!\n";

    print $text;
    foreach my $basename (keys %$scripts) {
        next if $scripts->{$basename}{public};
        
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
    set_permissions($file, $parameters);  
    return;
}

#----------------------------------------------------------------------
# Write group file for password protected site

sub write_group_file {
    my ($directory, $request, $scripts, $parameters) = @_;

    my $file = "$directory/.htgroups";
    $scripts = read_groups_file($file, $scripts);
 
    my $fd = IO::File->new($file, 'w')
        or die "Can't open $file: $!\n";

    my $user = $request->{user};
    foreach my $basename (keys %$scripts) {
        next if $scripts->{$basename}{public};
        $scripts->{$basename}{users}{$user} = 1;
 
        my $user_list = join(' ', sort keys $scripts->{$basename}{users});
        print $fd "$basename: $user_list\n";
    }

    close($fd);
    set_permissions($file, $parameters);  
    return;
}

#----------------------------------------------------------------------
# Write file that blocks access to site

sub write_no_access_file {
    my ($directory, $parameters) = @_;

    my $file = "$directory/.htaccess";
    my $fd = IO::File->new($file, 'w')
        or die "Can't open $file: $!\n";

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
    set_permissions($file, $parameters);  

    return;    
}

#----------------------------------------------------------------------
# Write password file

sub write_password_file {
    my ($directory, $request, $parameters)= @_;

    my $file = "$directory/.htpasswd";
    my $passwords = read_password_file($file);
    $passwords->{$request->{user}} = encrypt($request->{pass1});
    
    my $fd = IO::File->new($file, 'w')
        or die "Can't open $file: $!\n";
   
    foreach my $user (sort keys %$passwords) {
        my $password = $passwords->{$user};
        print $fd "$user:$password\n";
    }

    close($fd);
    set_permissions($file, $parameters);  

    return;
}
