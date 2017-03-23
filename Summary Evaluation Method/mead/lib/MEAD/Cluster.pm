package MEAD::Cluster;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(load_cluster
	     read_cluster
	     flatten_cluster);


# TODO: AJW 9/17
# write_cluster
#

use strict;

use XML::Parser;

use MEAD::MEAD;
use MEAD::Document;

my @read_cluster_DIDs;
my $lang;

sub load_cluster {
    my $datadir = shift;
    my @DIDs = @_;

    my $result = {};

    foreach my $DID (@DIDs) {
	my $document_filename = &DID_to_docsent_filename($DID,$datadir);
	$$result{$DID} = read_document($DID, $document_filename);
    }

    return $result;
}

sub read_cluster {
    my $cluster_arg = shift;
    my $datadir = shift;
    
    @read_cluster_DIDs = ();

    my $xml_parser = new XML::Parser(Handlers => {
	Start => \&read_cluster_handle_start});

    # $cluster_arg can be a filehandle, a stream, or a filename.
    if (ref $cluster_arg) {
	$xml_parser->parse($cluster_arg);
    } else {
	$xml_parser->parsefile($cluster_arg);
    }

    my $result = {};

    foreach my $DID (@read_cluster_DIDs) {
	my $document_filename = &DID_to_docsent_filename($DID, $datadir);
	$$result{$DID} = read_document($DID, $document_filename);
    }

    return $result;
}

sub flatten_cluster {
    my $cluster = shift;

    my @flattened_cluster = ();

    foreach my $did (keys %{$cluster}) {

	my $docref = $$cluster{$did};

        for (my $sno = 1; $sno < @{$docref}; $sno++) {

	    my $sentref = $$docref[$sno];
	    next unless $sentref;

	    my %sentence = ();

	    $sentence{'DID'} = $did;
	    $sentence{'SNO'} = $sno;

            foreach my $key (keys %{$sentref}) {
		$sentence{$key} = $$sentref{$key};
            }

	    push @flattened_cluster, \%sentence;
        }
    }

    return \@flattened_cluster;
}

sub read_cluster_handle_start {
    shift;
    my $element_name = shift;
    my %atts = @_;

    if ($element_name eq 'CLUSTER') {
	$lang = $atts{'LANG'};
    } elsif ($element_name eq 'D') {
	push @read_cluster_DIDs, $atts{'DID'};
    }	
}

1;







