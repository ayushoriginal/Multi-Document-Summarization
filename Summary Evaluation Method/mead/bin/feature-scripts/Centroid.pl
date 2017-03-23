#!/usr/bin/perl
#
# usage: echo cluster_file_name | Centroid.pl <idffile> (ENG|CHIN) <datadir>
#

#
# TODO: AJW 9/23
# actually use the IDF file information.
#

use strict;

use FindBin;
use lib "$FindBin::Bin/../../lib/", "$FindBin::Bin/../../lib/arch/";

use Essence::IDF;
use Essence::Centroid;

use MEAD::SentFeature;

# command-line args.
my $idf_file = shift;
my $lang = shift;
my $datadir = shift;

# open the specified IDF file.
open_nidf($idf_file);

# Centroid and the max value for any sentence.
my $centroid = Essence::Centroid->new();
my $max_cent = 0;

extract_sentfeatures($datadir, {'Cluster'=>\&cluster, 
				'Sentence' =>\&sentence});

sub cluster {
    my $cluster = shift;
    my $query = shift; # ignored.

    my @sents;

    foreach my $did (keys %{$cluster}) {
	my $docref = $$cluster{$did};
	
	my $text;
	foreach my $sentref (@{$docref}) {
	    $text .= " " . $$sentref{'TEXT'};
	    push @sents, $$sentref{'TEXT'};
	}

	$centroid->add_document($text);
    }

    foreach my $s (@sents) {
	my $score = $centroid->centroid_score($s);
	if ($score > $max_cent) {
	    $max_cent = $score;
	}
    }

}

sub sentence {
    my $feature_vector = shift;
    my $attribs = shift;

    my $text = $$attribs{"TEXT"};
    my $score = $centroid->centroid_score($text);
    $$feature_vector{'Centroid'} = sprintf("%17.15f", $score / $max_cent);
}
