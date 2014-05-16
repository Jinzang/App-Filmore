use strict;
use warnings;

package SimpleTemplate;

use lib '../../../lib';
use base qw(App::Filmore::ConfiguredObject);
use IO::File;

our $VERSION = '0.01';

# The commands recognized by the template engine and their translations
use constant COMMANDS => {
                            for => 'foreach my $data (%%) {',
                            endfor => '}',
                            if => 'if (%%) {',
                            elsif => '} elsif (%%) {',
                            else => '} else {',
                            endif => '}',
                         };
#----------------------------------------------------------------------
# Compile a template into a subroutine which when called fills itself

sub compile_code {
    my ($self, @templates) = @_;
    
    # Template precedes subtemplate, which precedes subsubtemplate

    my $text;
    my $section = {};
    while (my $template = pop(@templates)) {
        if ($template =~ /\n/) {
            $text = $template;
        } else {
            $text = $self->slurp($template);
        }

        $text = $self->substitute_sections($text, $section);
    }

    return $self->construct_code($text);
}

#----------------------------------------------------------------------
# Compile a subroutine from the code embedded in the template

sub construct_code {
    my ($self, $text) = @_;

    my $start = <<'EOQ';
sub {
my $data = shift(@_);
my $text = '';
EOQ

    my @lines = split(/\n/, $text);    
    my @mid = $self->parse_code(\@lines);

    my $end .= <<'EOQ';
return $text;
}
EOQ

    my $code = join("\n", $start, @mid, $end);
    my $sub = eval ($code);
    die $@ unless $sub;

    return $sub;
}

#----------------------------------------------------------------------
# Parse the templace source

sub parse_code {
    my ($self, $lines, $command) = @_;

    my @code;
    my @stash;

    while (defined (my $line = shift @$lines)) {
        my ($cmd, $cmdline) = $self->parse_command($line);
    
        if (defined $cmd) {
            if (@stash) {
                push(@code, '$text .= <<"EOQ";', @stash, 'EOQ');
                @stash = ();
            }
            push(@code, $cmdline);
            
            if (substr($cmd, 0, 3) eq 'end') {
                my $startcmd = substr($cmd, 3);
                die "Mismatched block end ($command/$cmd)"
                      if defined $startcmd && $startcmd ne $command;
                return @code;

            } elsif (COMMANDS->{"end$cmd"}) {
                push(@code, $self->parse_code($lines, $cmd));
            }
        
        } else {
            $line =~ s/(?<!\\)\$(\w+)/\$data->{$1}/g;
            push(@stash, $line);
        }
    }

    die "Missing end (end$command)" if $command;
    push(@code, '$text .= <<"EOQ";', @stash, 'EOQ') if @stash;

    return @code;
}

#----------------------------------------------------------------------
# Parse a command and its argument

sub parse_command {
    my ($self, $line) = @_;

    return unless $line =~ s/^\s*<!--\s*//;

    $line =~ s/\s*-->//;
    my ($cmd, $arg) = split(' ', $line, 2);
    $arg = '' unless defined $arg;
    
    my $cmdline = COMMANDS->{$cmd};
    return unless $cmdline;
    
    $arg =~ s/([\@\%])(\w+)/$1\{\$$2\}/g;
    $arg =~ s/(?<!\\)\$(\w+)/\$data->{$1}/g;
    $cmdline =~ s/%%/$arg/; 

    return ($cmd, $cmdline);
}

#----------------------------------------------------------------------
# Extract sections from file, store in hash

sub parse_sections {
    my ($self, $text) = @_;

    my $name;
    my %section;

    # Extract sections from input

    my @tokens = split (/(<!--\s*(?:section|endsection)\s+.*?-->)/, $text);

    foreach my $token (@tokens) {
        if ($token =~ /^<!--\s*section\s+(\w+).*?-->/) {
            if (defined $name) {
                die "Nested sections in input: $token\n";
            }
            $name = $1;
    
        } elsif ($token =~ /^<!--\s*endsection\s+(\w+).*?-->/) {
            if ($name ne $1) {
                die "Nested sections in input: $token\n";
            }
            undef $name;
    
        } elsif (defined $name) {
            $section{$name} = $token;
        }
    }
    
    die "Unmatched section (<!-- section $name -->)\n" if $name;
    return \%section;
}

#----------------------------------------------------------------------
# Read a file into a string

sub slurp {
    my ($pkg, $input) = @_;
    my $self = $pkg->new;

    my $in;
    local $/;

    if (ref $input) {
        $in = $input;
    } else {
        $in = IO::File->new ($input);
        return '' unless defined $in;
    }

    my $text = <$in>;
    $in->close;

    return $text;
}

#----------------------------------------------------------------------
# Substitue comment delimeted sections for same blacks in template

sub substitute_sections {
    my ($self, $text, $section) = @_;

    my $name; 
    my @output;
    
    my @tokens = split (/(<!--\s*(?:section|endsection)\s+.*?-->)/, $text);

    foreach my $token (@tokens) {
        if ($token =~ /^<!--\s*section\s+(\w+).*?-->/) {
            if (defined $name) {
                die "Nested sections in template: $name\n";
            }

            $name = $1;
            push(@output, $token);
    
        } elsif ($token =~ /^\s*<!--\s*endsection\s+(\w+).*?-->/) {
            if ($name ne $1) {
                die "Nested sections in template: $name\n";
            }

            undef $name;
            push(@output, $token);
    
        } elsif (defined $name) {
            $section->{$name} ||= $token;
            push(@output, $section->{$name});
            
        } else {
            push(@output, $token);
        }
    }

    return join('', @output);
}

1;

=pod

=head1 NAME

SimpleTemplate -- Simplate template handling for cgi scripts

=head1 DESCRIPTION

You may want to change the way the output looks. You can do this by editing a
script's template files. The template can be customized to make it look the way
you wish. The template commands and variables are described in the next section.

This script also allows you to create a site wide template so that you can have
a common look for all the web pages and cgi scripts on your site. Blocks in the
site template are wrapped in html comments that look like

    <!-- section name -->
    <!-- endsection name -->

where name is any identifier string. Block delimeted in the same comments in the
search template replace the sections in the site template.

=head1 TEMPLATE CUSTOMIZATION

Whenever a string like $name occurs in the template, it is replaced by the
corresponding value generated by this script. The template also uses simple
control structures: the for and endfor statements that loop over the results
returned by the search engine and the if, else, elsif, and endif statement that
include code conditionally in the output, depending on the value of the variable
on the if statement.

All control structures must be contained in html comments, which must
be the first text on the  template line. The comment must be the only
text on the line and be contained on a single line.

This script produces the results array, whose contents are looped over
to display the search results. The following variables can be used in
the template lines between the "for @results" and "endfor" lines: 

=back

=head1 METHODS

=over 4

=item compile_code

Compile one or more templates into a subroutine. A hash can then be rendered by
calling the subroutine with it as the single argument:

    my $obj = SimpleTemplate->new;
    my $sub = $self->compile_code($template_name, $subtemplate_name);
    my $output = &$sub(\%data);

=item construct_code

Turn a single template into a subroutine. This is a lower level method called by
compile_code.

    my $obj = SimpleTemplate->new;
    my $sub = $obj->construct_code($template);

=item parse_sections

Take a template and extract its sections into a hash

    my $obj = SimpleTemplate->new;
    my $section = $obj->parse_sections($template);
    my $content = $section->{content};

=item substitute_sections

Substitute the sections from one template into another, producing a new template.
Any sections not in the hash will be added, existing sections will not be modified.
This is the method used to combine templates

    my $text;
    my $section = {};
    while (my $template_name = pop(@template_names)) {
        $text = $obj->slurp($template_name);
        $text = $obj->substitute_sections($text, $section);
    }

=back

=head1 AUTHOR

Bernie Simon (bernie.simon@gmail.com)
 
=head1 LICENSE

Copyright Bernard Simon, 2014 under the Perl Artistic License.

=cut
