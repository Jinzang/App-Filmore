use strict;
use warnings;
use integer;

#----------------------------------------------------------------------
# Search engine back end

package Filmore::SearchEngine;

use lib '../../../lib';
use base qw(Filmore::ConfiguredObject);

our $VERSION = '0.01';

use Cwd;
use IO::File;
use Text::ParseWords;
use File::Spec::Functions qw(abs2rel catfile rel2abs splitdir);

#----------------------------------------------------------------------
# Set default parameters

sub parameters {
  my ($pkg) = @_;

    my %parameters = (
        dont_search => '',
        do_search => '*.html',
        number_results => 20,
        context_length => 80,
        body_tag => 'content',
        template_ptr => 'Filmore::SimpleTemplate',
        webfile_ptr => 'Filmore::WebFile',
	);

    return %parameters;
}

#----------------------------------------------------------------------
# Build the page url from the base url and filname

sub build_url {
    my ($self, $base_url, $base_directory, $filename) = @_;

    $filename = abs2rel($filename, $base_directory);
    my @path = splitdir($filename);

    return return join('/', $base_url, @path);
}

#----------------------------------------------------------------------
# Do the search and build the output array

sub do_search {
    my ($self, $base_url, $base_directory, @term) = @_;

    # Create the closure used to search the files

    my $results = [];
    my $do_pattern = $self->globbify($self->{do_search});
    my $dont_pattern = $self->globbify($self->{dont_search});

    if (@term) {
        my $visit = $self->{webfile_ptr}->visitor($base_directory, '-date');
        while (defined (my $filename = &$visit)) {
            my ($dir, $basename) =
                $self->{webfile_ptr}->split_filename($filename);

            next if $do_pattern && ! $basename =~ /$do_pattern/o;
            next if $dont_pattern && $basename =~ /dont_pattern/o;
        
            my $text = $self->{webfile_ptr}->reader($filename);
            next unless $text;
            
            my ($title, $body) =  $self->parse_htmldoc($text);
            next unless length ($body);
        
            my ($count, @pos);
            foreach my $term (@term) {
                my $pos = 0;
                while ($body =~ /$term/gi) {
                    $pos ||= pos ($body);
                    $count ++;
                }
        
                if ($pos) {
                    push (@pos, $pos);
                }
            }
        
            next unless $count;
            
            my $modtime = (stat $filename)[9];
            my $result = {title => $title, count => $count, modtime => $modtime};
        
            $result->{url} = 
              $self->build_url($base_url, $base_directory, $filename);
        
            $result->{context} = $self->get_context($body, $term[0], $pos[0]),;
        
            push (@$results, $result);
        }
    };

    return $results;
}

#----------------------------------------------------------------------
# Add parameters to a url

sub encode_url {
    my ($self, $url, %param) = @_;

    my $arglist;
    foreach my $key (sort keys %param) {
        $arglist .= '&' if $arglist;

        my $value = $param{$key};
        $value =~ s/([&\+\"\'])/sprintf ('%%%02x', ord($1))/ge;
        $value =~ tr/ /+/;
	
        $arglist .= "$key=$value";
    }

    return $arglist ? "$url?$arglist" : $url;
}

#----------------------------------------------------------------------
# Get the context of a search term match

sub get_context {
    my ($self, $text, $term, $pos) = @_;

    my $start = $pos - $self->{context_length} / 2;
    $start = 0 if $start < 0;

    my $end = $pos + $self->{context_length} / 2;
    my $len = ($end - $start) + 1;
    $len = length ($text) - $start if $len > length ($text) - $start;

    my $context = substr ($text, $start, $len);

    $context =~ s/^\S*\s+//g;
    $context =~ s/\s+\S*$//g;
    $context =~ s!($term)!<b>$1</b>!gi;
    $context =~ s/\s+/ /g;
    
    return $context;
}

#----------------------------------------------------------------------
# Convert filename wildcards into regexp wildcards

sub globbify {
    my ($self, $pattern) = @_;

    my @pattern;
    if (ref $pattern) {
        @pattern = @$pattern;
    } else {
        push (@pattern, $pattern);
    }

    my %patmap = (
		    '*' => '.*',
		    '?' => '.',
		    '[' => '[',
		    ']' => ']',
		  );

    my @regexp;
    foreach my $pattern (@pattern) {
        next unless length ($pattern);
    
        $pattern =~ s/(.)/$patmap{$1} || "\Q$1"/ge;
        $pattern = '(^' . $pattern . '$)';
        push (@regexp, $pattern);
    }

    return join ('|', @regexp);
}

#----------------------------------------------------------------------
# Return info about form parameters

sub info_data {
    my ($self, $response) = @_;

    my $info = [{name => 'query',
                title => 'Search',
                valid=>"&string"},
               ];

    return $info;
}

#----------------------------------------------------------------------
# Create urls for previous and next queries

sub navlinks {
    my ($self, $response) = @_;

    if ($response->{start} > 1) {
	my $first = $response->{start} - $self->{number_results};
	$first = 1 if $first < 1;


	$response->{previous_url} = $self->encode_url($response->{script_url}, 
                                'start', $first, 
                                'query', $response->{query});
    }

    if ($response->{finish} < $response->{total}) {
        $response->{next_url} = $self->encode_url ($response->{script_url}, 
                                'start', $response->{finish} + 1, 
                                'query', $response->{query});
    }
    
    return $response;
}

#----------------------------------------------------------------------
# Get title and remove html from document

sub parse_htmldoc {
    my ($self, $text) = @_;

    return $text unless length ($text);

    my ($title) = $text =~ m!<title>(.*)</title>!i;
    $title =~ tr/\t\r\n / /s;
    $title = '(No Title)' unless length ($title);
    
    my $body_tag = $self->{body_tag};
    my $section = $self->{template_ptr}->parse_sections($text);
    my $body = $section->{$body_tag} || '';
    $body =~ s/<[^>]*>//g;

    return ($title, $body);
}

#----------------------------------------------------------------------
# Sort and restrict the set of results

sub restrict_page {
    my ($self, $response, $results, $start) = @_;

    $response->{total} =  @$results;
    $response->{start} = $start || 1;

    $response->{finish} = $self->{number_results} + $response->{start} - 1;
    $response->{finish} = $response->{total}
        if $response->{finish} > $response->{total};

    my $sorter = sub {
        $b->{count} <=> $a->{count} || $b->{modtime} <=> $a->{modtime}
    };

    @$results = sort $sorter @$results;

    my @restricted = @$results[$response->{start}-1 .. $response->{finish}-1];
    $response->{results} = \@restricted;
    
    return $response;
}

#----------------------------------------------------------------------
# Return the template used to render the result

sub template_data {
    my ($self, $response) = @_;

    return <<'EOQ';
<html>
<head>
<title>Site Search</title>
</head>
<body>
<!-- section content -->
<h2>Site Search</h2>

<p>$msg</p>

<div id="searchform">
<form method="post" action="$script_url">
<!-- for @items -->
<div>$title</div>
$field
<!-- endfor -->
</form>
</div>
<!-- if $cmd -->
<!-- if $total -->
<p>Documents $start to $finish of $total</p>
<!-- else -->
<p>No documents matched</p>
<!-- endif -->
<!-- else -->
<p>Enter one or more words to search for. The results will list pages
containing all the search terms. The match is case insensitive and
only matches entire words. To search for a phrase, enclose it "in
quotes".</p>
<!-- endif -->
<!-- for @results -->
<p><a href="$url"><b>$title</b></a><br />
$context</p>
<!-- endfor -->
<p>
<!-- if $previous_url -->
<a href="$previous_url"><b>Previous</b></a>
<!-- endif -->
<!-- if $next_url -->
<a href="$next_url"><b>Next</b></a>
<!-- endif -->
</p>
<!-- endsection content -->
</body>
</html>
EOQ
}

#----------------------------------------------------------------------
# Run the handler

sub write_data {
    my ($self, $response) = @_;

    # Set configuration variables if left empty
    
    my $base_directory = $response->{base_directory} || getcwd();
    my $base_url = $response->{base_url} || '';
    $base_url =~ s!/[^/]*$!!;
    
    # Perform the search and put results into an array
    
    my @term = map ('\b'.quotemeta($_).'\b', shellwords ($response->{query}));
    my $results = $self->do_search($base_url, $base_directory, @term);
    
    # Build navigation links 
    
    $response = $self->restrict_page ($response, $results, $response->{start});
    $response = $self->navlinks ($response);
    
    return;
}

1;
