package MEAD::SentFeature;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(extract_sentfeatures
	     read_sentfeature
	     write_sentfeature
	     combine_sentfeatures);

#
# TODO: AJW 9/17
# fix/finish:
# read_sentfeature
# write_sentfeature
# combine_sentfeatures
#

use strict;

use XML::Parser;
use Text::Iconv;
my $UTF_8_to_Big5 = Text::Iconv->new("UTF-8", "BIG5");

use MEAD::MEAD;
use MEAD::Cluster qw(read_cluster);
use MEAD::Query qw(read_query);

my $debug = 0;

my %sentfeature;
my $curr_did;
my $curr_sno;

#
# TODO: AJW 9/17
# use write_sentfeature in extract_sentfeatures and remove the 
# methods that extract_sentfeatures currently uses.
#

sub extract_sentfeatures {

    my $datadir = shift;
    my $arg_hash = shift;
    my $input_filehandle = shift || \*STDIN;
    
    my $cluster_sub = $$arg_hash{'Cluster'} || \&dummy_sub;
    my $document_sub = $$arg_hash{'Document'} || \&dummy_sub;
    my $sentence_sub = $$arg_hash{'Sentence'} || \&dummy_sub;
    
    #my %sentfeatures = {};

    &write_header();
    
    while (<$input_filehandle>) {
	print if $debug;
	
	/\s*(\S+)\s*(\S*)\s*$/ or 
	    die "Expected cluster (and maybe also query), got:\n$_";

	my $cluster_filename = $1;
	my $query_filename = $2;
	
	print "cluster_filename = $cluster_filename\n" if $debug;
	print "query_filename = $query_filename\n" if $debug;

	my $cluster = &read_cluster($cluster_filename, $datadir);

	my $query;
	if ($query_filename) {
	    $query = &read_query($query_filename);
	}

	&{ $cluster_sub }($cluster, $query);
	
	foreach my $DID (keys %{ $cluster }) {
	    print "DID = $DID\n" if $debug;
	    
	    my $document = $$cluster{$DID};
	    
	    &{ $document_sub }($document, $DID); 
	    
	    shift @{ $document };  #  drop the dummy sentence # 0

	    #my %doc_hash = {};
	    #$sentfeatures{$DID} = \%doc_hash;

	    foreach my $sentence (@{ $document }) {
		print "sentence...\n" if $debug;

		my %feature_vector;

		&{ $sentence_sub }(\%feature_vector, $sentence);
				
		&write_feature_vector(\%feature_vector, $sentence);
		#$$sentfeature{$DID}[$
	    }

	    print "finished DID $DID\n" if $debug;
	}
		
	print "finished cluster $cluster_filename\n" if $debug;
    }

    &write_footer();
}

#
# source can be a filename, a filehandle, stream, etc.
# and default to STDIN.
#
sub read_sentfeature {

    my $source = shift || \*STDIN;
    
    %sentfeature = ();

    undef $curr_did;
    undef $curr_sno;

    my $xml_parser = new XML::Parser(Handlers => 
	{Start => \&read_sentfeature_handle_start});

    # $source can be a Filehandle or a GLOB 
    if (ref $source) {
	$xml_parser->parse($source);
    } else {
	$xml_parser->parsefile($source);
    }    

    return %sentfeature;
}

#
# $destination can be anything.
#

sub write_sentfeature {

    my $sentfeature_ref = shift;
    my $destination = shift || \*STDOUT;

    # TODO: AJW 9/17
    # Do something with $destination.

    my $writer = new XML::Writer(DATA_MODE => 1, OUTPUT => $destination);

    $writer->xmlDecl();
    $writer->doctype("SENT-FEATURE", "", 
		     "/clair/tools/mead/dtd/sentfeature.dtd");

    $writer->startTag("SENT-FEATURE");

    foreach my $did (keys %{$sentfeature_ref}) {

        my $docref = $$sentfeature_ref{$did};

        for (my $sno = 1; $sno < @{$docref}; $sno++) {
	    $writer->startTag("S", "DID"=>$did, "SNO"=>$sno);

            my $sentref = $$docref[$sno];

            # now print features
            foreach my $fname (keys %{$sentref}) {
		$writer->emptyTag("FEATURE", "N"=>$fname, 
				  "V"=>$$sentref{$fname});
            }

            $writer->endTag();
        }
    }

    $writer->endTag();
    $writer->end();

}

#
# Combines the sentfeatures in @sources and adds them to $destination.
#
# TODO: AJW 9/18
# to make this more efficient, maybe we should ensure that $destination
# has an entry for every DID/SNO combination first before we add all the
# source features, so that we don't have to check in the loop so much.
#
# $destination is a reference to a sentfeature structure.
# @sources is a list of references to sentfeature structures.
#
sub combine_sentfeatures {
    
    my $destination = shift;
    my @sources = @_;

    foreach my $source (@sources) {

	foreach my $did (keys %{$source}) {

	    my $source_docref = $$source{$did};
	    my $dest_docref = $$destination{$did};
	    
	    # make sure that $destination has an entry for $did.
	    unless (defined $dest_docref) {
		my @tempdoc = ();
		$dest_docref = \@tempdoc;
		$$destination{$did} = $dest_docref;
	    }

	    for (my $sno = 1; $sno < @{$source_docref}; $sno++) {

		my $source_sentref = $$source_docref[$sno];
		my $dest_sentref = $$dest_docref[$sno];
		
		# make sure that $dest_docref has an entry for $sno.
		unless (defined $dest_sentref) {
		    my %tempsent = ();
		    $dest_sentref = \%tempsent;
		    $$dest_docref[$sno] = $dest_sentref;
		}
		
		foreach my $fname (keys %{$source_sentref}) {

		    $$dest_sentref{$fname} = $$source_sentref{$fname};

		}

	    }

	}

    }

    return $destination;

}

#
# Callback for read_sentfeature.
#

sub read_sentfeature_handle_start {
    
    shift; #don't care about Expat
    my $element_name = shift;
    my %atts = @_;

    if ($element_name eq 'S') {
	
	$curr_did = $atts{'DID'};
	$curr_sno = $atts{'SNO'};
	
    } elsif ($element_name eq 'FEATURE') {
	
	my @curr_doc = (); 
	my $curr_doc_ref = 0;
	my %curr_sent = (); 
	my $curr_sent_ref = 0;
	
	my $name = $atts{'N'};
	my $value = $atts{'V'};
	
	##if there's no document, we need to create everything
	if  (!($sentfeature{$curr_did})) {
	
	    $curr_sent{$name} = $value;
	    $curr_doc[$curr_sno] = \%curr_sent;
	    $sentfeature{$curr_did} = \@curr_doc;
	    # print "Doc $curr_did not found.  Added it along with\n";
	    # print " $curr_sno($name)=$curr_sent{$name}\n";
	
	} else { 
 
	    $curr_doc_ref = $sentfeature{$curr_did};
	    @curr_doc = @{$curr_doc_ref};

	    ##if there's no sentence, we need to create a sentence
	    if (!($curr_doc[$curr_sno])) {
		
		$curr_sent{$name} = $value;
		$curr_doc[$curr_sno] = \%curr_sent;
		$sentfeature{$curr_did} = \@curr_doc;
	    
	    } else { ##otherwise, just do what we normally would

		my $sentref = $curr_doc[$curr_sno];
		$$sentref{$name} = $value;
		$curr_doc[$curr_sno] = $sentref;
		$sentfeature{$curr_did} = \@curr_doc;
		#print "Added $name=${$sentref}{$name}\n";
	    
	    }
	}
    }
}

sub dummy_sub {}

sub write_header {
    print "<?xml version='1.0'?>\n";
    print "<SENT-FEATURE>\n";
}

sub write_feature_vector {
    my $feature_vector = shift;
    my $sentence = shift;

    if ($debug) {
	foreach my $sent_key (keys %{ $sentence }) {
	    print "$sent_key => $$sentence{$sent_key}\t";
	}
	print "\n";
    }

    print "\t<S DID=\"$$sentence{'DID'}\" SNO=\"$$sentence{'SNO'}\" >\n";
    foreach my $feature_name (keys %{ $feature_vector }) {
	print "\t\t<FEATURE N=\"$feature_name\" V=\"$$feature_vector{$feature_name}\" />\n";
    }
    
    print "\t</S>\n";
}

sub write_footer {
    print "</SENT-FEATURE>\n";
}

1;











