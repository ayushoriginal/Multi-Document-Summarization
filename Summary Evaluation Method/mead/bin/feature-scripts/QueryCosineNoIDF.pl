#!/usr/bin/perl -w

#########################################################################
#
# usage:
#   echo cluster_filename | ./QueryCosineNoIDF.pl \
#       [-q option] query_filename datadir
#
# option: specify which part of query is used to compute word overlap
#    -q: "t", "title", "n", "narrative", "d", "description", "a", "all"
#
#########################################################################

use strict;

use Getopt::Long;

use FindBin;
use lib "$FindBin::Bin/../../lib/", "$FindBin::Bin/../../lib/arch/";

use MEAD::Query;
use MEAD::SentFeature;
use MEAD::Evaluation;
use Essence::Text;

# get the option
my $q;
GetOptions ("q=s"  => \$q);

my $option = "all";
if ($q) {
    $q =~ tr/[A-Z]/[a-z]/;
    if (($q eq "t") or ($q eq "title")) {
	$option = "title";
    } elsif (($q eq "n") or ($q eq "narrative")) {
	$option = "narrative";
    } elsif (($q eq "d") or ($q eq "description")) {
	$option = "description";
    } elsif (($q ne "a") and ($q ne "all")) {
	die "-q can only take t/title, n/narrative, d/description.\n";
    }
}

my $query_filename = shift;
my $datadir = shift;

unless ($query_filename && $datadir) {
    die "Must provide query_filename and datadir\n";
}

my $query = read_query($query_filename);
my $query_title = $$query{'TITLE'};
my $query_narrative = $$query{'NARRATIVE'};
my $query_description = $$query{'DESCRIPTION'};

extract_sentfeatures($datadir, {'Sentence' => \&sentence});

sub sentence {
    my $feature_vector = shift;
    my $sentref = shift;
  
    my $sentence_text = $$sentref{'TEXT'};
    
    if (($option eq "all" or $option eq "title") and $query_title) {
	$$feature_vector{'QueryTitleCosineNoIDF'} = 
	    simple_cosine($query_title, $sentence_text);
    }

    if (($option eq "all" or $option eq "narrative") and $query_narrative) {
	$$feature_vector{'QueryNarrativeCosineNoIDF'} = 
	    simple_cosine($query_narrative, $sentence_text);
    }

    if (($option eq "all" or $option eq "description") and $query_description) {
	$$feature_vector{'QueryDescriptionCosineNoIDF'} = 
	    simple_cosine($query_description, $sentence_text);
    }

}
