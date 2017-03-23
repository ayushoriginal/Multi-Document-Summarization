package MEAD::Document;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(DID_to_docsent_filename
	     read_document);

use strict;

use XML::Parser;
use Text::Iconv;

my $UTF_8_to_Big5 = Text::Iconv->new("UTF-8", "BIG5");

sub DID_to_docsent_filename {
    my $DID = shift;
    my $datadir = shift;

    my $docsent_filename = "$datadir/$DID.docsent";
    return $docsent_filename;
}

my $read_document_sentences;
my $read_document_sentence;

my $read_document_DID;
my $read_document_extrinsic_DID;

sub read_document {

    # this is the DID that is listed in the cluster
    # file and was used to look up the filename for this cluster;
    $read_document_extrinsic_DID = shift;  	
    my $document_filename = shift;

    $read_document_sentences = [];

    my $xml_parser = new XML::Parser(Handlers => {
	Start => \&read_document_handle_start,
	Char => \&read_document_handle_char});

    open (INSTREAM, "iconv -f BIG5 -t UTF-8 $document_filename |");
    $xml_parser->parse(\*INSTREAM);
    return $read_document_sentences;

}

sub read_document_handle_start {
    shift;
    my $element_name = shift;
    my %atts = @_;
	
    if ($element_name eq 'DOCSENT') {
	
	$read_document_DID = $atts{'DID'};
	unless ($read_document_DID eq $read_document_extrinsic_DID) {
	    my $message = "DID mismatch:\n";
	    $message .= "extrinsic = $read_document_extrinsic_DID\n";
	    $message .= "intrinsic = $read_document_DID\n";
	    die $message;
	}

    }  elsif ($element_name eq 'S') {

	#$read_document_sentence = { @_ };
	$read_document_sentence = \%atts;
	$$read_document_sentence{'DID'} = $read_document_DID;

    }

}	

sub read_document_handle_char {
    shift;
    my $text = shift;

    if ($text =~ /\S/) {
	$text = $UTF_8_to_Big5->convert($text);
	$$read_document_sentence{'TEXT'} .= $text;
	$$read_document_sentences[$$read_document_sentence{'SNO'}] = 
	    $read_document_sentence;
    }
}

1;
