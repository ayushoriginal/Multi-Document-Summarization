package MEAD::Extract;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(open_from_file
	     
	     read_extract
	     write_extract

	     extract_to_summary
	     sentref_array_to_extract);

use strict;

use XML::TreeBuilder;
use XML::Parser;
use XML::Writer;

use MEAD::MEAD;

#
# TODO: AJW 9/17
# remove the XML TreeBuilder stuff.
#

#
#
# THIS IS THE EXTRACT DATA STRUCTURE METHODS.
#
#

my %read_extract_sents;

sub read_extract {
    my $extract_arg = shift;

    %read_extract_sents = ();

    ## Begin parsing the extract
    my $extract_parser = new XML::Parser(Handlers => {
	'Start' => \&read_extract_handle_start});

    if (ref $extract_arg) {
        $extract_parser->parse($extract_arg);
    } else {    
        $extract_parser->parsefile($extract_arg);
    }

    return \%read_extract_sents;
}

sub read_extract_handle_start {
    shift;
    my $element_name = shift;
    my %atts = @_;

    if ($element_name eq 'S') {
        my $num = $atts{'ORDER'};
        my $did = $atts{'DID'};
        my $sno = $atts{'SNO'};

        my $sentref = {};
        $$sentref{'DID'} = $did;
        $$sentref{'SNO'} = $sno;

        $read_extract_sents{$num} = $sentref;
    }
}

sub write_extract {
    my $extract = shift;
    my %args = @_;

    if (ref($extract) eq "ARRAY") {
	$extract = sentref_array_to_extract($extract);
    }

    my $cluster_name = $args{'QID'};
    my $lang = $args{'LANG'};
    my $compression_percent = $args{'COMPRESSION'};
    my $system = $args{'SYSTEM'};
    my $run = $args{'RUN'};

    my $output = $args{'OUTPUT'} || \*STDOUT;
    unless (ref $output) {
	open TEMP, ">$output" or
	    die "Unable to open '$output' for printing extract.\n";
	$output = \*TEMP;
    }

    my $writer = new XML::Writer(DATA_MODE => 1, OUTPUT => $output);

    $writer->xmlDecl();
    $writer->doctype("EXTRACT", "", "/clair/tools/mead/dtd/extract.dtd");

    $writer->startTag("EXTRACT", 
                      "QID" => $cluster_name,
                      "LANG" => $lang,
                      "COMPRESSION" => $compression_percent,
                      "SYSTEM" => $system,
                      "RUN" => $run);

    foreach my $order (sort { $a <=> $b } keys %{ $extract }) {
	my $sentref = $$extract{$order};
	$writer->emptyTag("S",
			  "ORDER" => $order,
			  "DID" => $$sentref{'DID'},
			  "SNO" => $$sentref{'SNO'});
    }
    
    $writer->endTag();
    $writer->end();
}

sub extract_to_summary {
    my $extract = shift;
    my $cluster = shift;
    
    my $summary = {};

    foreach my $order (keys %{$extract}) {
        my $sentref = $$extract{$order};

        my $did = $$sentref{'DID'};
        my $sno = $$sentref{'SNO'};

        my $cluster_docref = $$cluster{$did};
        my $cluster_sentref = $$cluster_docref[$sno];

        my $summary_sentref = {};
        $$summary_sentref{'DID'} = $did;
        $$summary_sentref{'SNO'} = $sno;
        $$summary_sentref{'TEXT'} = $$cluster_sentref{'TEXT'};

        $$summary{$order} = $summary_sentref;
    }

    return $summary;
}

sub sentref_array_to_extract {
    my $arrayref = shift;

    my $hashref = {};

    my $order = 0;
    foreach my $sentref (sort by_did_and_sno @{$arrayref}) {
	my $new_sentref = {};
	$$new_sentref{'DID'} = $$sentref{'DID'};
	$$new_sentref{'SNO'} = $$sentref{'SNO'};
	
	$order++;
	$$hashref{$order} = $new_sentref;
    }

    return $hashref;
}

sub by_did_and_sno {

    my $comp = $$a{'DID'} cmp $$b{'DID'};
    return $comp if $comp != 0;

    return $$a{'SNO'} <=> $$b{'SNO'};

}

#
#
# BELOW IS THE EXTRACT OBJECT DEFINITION.
#
#

=head1 DESCRIPTION

MEAD::Extract opens and has methods to access various parts of a MEAD-style extract.
Since the extract format differs between DUC-sytle extracts and MEAD-style extracts,
we have a two classes.

=head1 METHODS

=over 2

=item $extract = MEAD::Extract->open_from_file($filename);

=cut

sub open_from_file {
    my ($class, $filename) = @_;
    my $self = {};
    
    bless $self, $class;

    $self->_really_open_me($filename);

    return $self;
}

sub _really_open_me {
    my ($self, $filename) = @_;

    my $extract_tree = XML::TreeBuilder->new;
    $extract_tree->parsefile($filename);
    my $extract_node = $extract_tree->find_by_tag_name("EXTRACT");

    my $node;
    my $i = 0;
    while ($node = $extract_node->look_down("_tag", "S", "ORDER", ++$i)) {
        my $DID = $node->attr("DID");
        my $SNO = $node->attr("SNO");
        my $ORDER = $node->attr("ORDER");

        die unless ($DID and $SNO);

        $self->{DID_list}[$ORDER] = $DID;
        $self->{SNO_list}[$ORDER] = $SNO;
    }

    #cleanup.
    $extract_tree->delete;
}


=item $num = $extract->get_num_sentences();

=cut

sub get_num_sentences {
    my $self = shift;
    return scalar @{$self->{DID_list}} - 1;
}


=item $did = $extract->get_SNO_for_sentence($sentence_index);

=cut

sub get_DID_for_sentence {
    my ($self, $sentence) = @_;
    return $self->{DID_list}[$sentence];
}


=item $sno = $exract->get_SNO_for_sentence($sentence_index);

=cut

sub get_SNO_for_sentence {
    my ($self, $sentence) = @_;
    return $self->{SNO_list}[$sentence];
}

1;






























