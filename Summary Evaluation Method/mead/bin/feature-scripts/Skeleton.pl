#!/usr/bin/perl

#
# usage: echo cluster_file query_file | Skeleton.pl <datadir>
#
# Note: datadir is appended by the driver.pl script as it 
# calls the feature script.  
#

use strict;

use FindBin;
use lib "$FindBin::Bin/../../lib", "$FindBin::Bin/../../lib/arch";

use MEAD::SentFeature;

my $datadir = shift;

extract_sentfeatures($datadir, {'Cluster' => \&cluster, 
				'Document' => \&document, 
				'Sentence' => \&sentence});

sub cluster {
    my $clusterref = shift;
    my $queryref = shift;    # This will only be defined if a 
                             # query filename is passed via the
                             # standard input along with the 
                             # cluster filename.
    
    foreach my $did (keys %$clusterref) {
	# This cycling through the DIDs will produce each 
	# document passed to the document subroutine.
	my $docref = $$clusterref{$did};
    }
}

sub document {
    my $docref = shift;

    for my $sno ( 1 .. (scalar(@$docref)-1) ) {
	# This will produce each sentence in the document,
	# and because the document subroutine is called with
	# each document, it will produce every sentence in the 
	# cluster.
	my $sentref = $$docref[$sno]; # note array indices, not hash keys.
    } 
}

sub sentence {
    my $feature_vector = shift;
    my $sentref = shift;

    my $did = $$sentref{"DID"};
    my $sno = $$sentref{"SNO"};
    my $text = $$sentref{"TEXT"};

    # You can compute more than one feature at a time,
    # but all but one may be "lost" as driver.pl looks for features
    # in files with names that include the feature name.
    $$feature_vector{"Skeleton"} = $sno/10;
    $$feature_vector{"Feature2"} = length($did);
    # etc...
}
