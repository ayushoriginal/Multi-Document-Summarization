package MEAD::Query;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(read_query); 

use strict;

use XML::Parser;
use Text::Iconv;

my $UTF_8_to_Big5 = Text::Iconv->new("UTF-8", "BIG5");

my $read_query_result;
my $current_element_name; 

sub read_query {
    my $query_filename = shift;

    $read_query_result = {};

    my $xml_parser = new XML::Parser(Handlers => {
	Start => \&read_query_handle_start,
	Char => \&read_query_handle_char});

    open(UNICODE_VERSION, "iconv -f BIG5 -t UTF-8 $query_filename |");
    $xml_parser->parse(\*UNICODE_VERSION);
    close(UNICODE_VERSION);
    
    return $read_query_result;
}

sub read_query_handle_start {
    shift;
    my $element_name = shift;
    my %atts = @_;

    if ($element_name eq 'QUERY') {
	$$read_query_result{'QID'} = $atts{'QID'};
    }

    $current_element_name = $element_name;
}

sub read_query_handle_char {
    shift;
    my $text = shift;

    if ($text =~ /\S/) {
	$$read_query_result{$current_element_name} .=
	    $UTF_8_to_Big5->convert($text);
    }
}

1;
