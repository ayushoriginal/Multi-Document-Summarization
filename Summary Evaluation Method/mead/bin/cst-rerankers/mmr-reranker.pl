#!/usr/bin/perl

# Date:   10/29/02
# Author: Anna Osepayshvili
# 
# This script is a reranker that uses a Maximal Marginal Relevance
# method for adjusting scores of sentences based on their novelty
# and redundancy.
#
# The script takes three parameters:
#
# relevance_weight
# ----------------
# Specifies the script's tendency to prefer relevant sentences even if they are redundant
#
# new_score = relevance_weight * relevance + (1 - relevance_weight) * novelty
#           = relevance_weight * relevance - (1 - relevance_weight) * redundancy
#
# If relevnace_weight = 1 the script behaves exactly as default-reranker.pl
# 
# similarity_function
# -------------------
# Function name that is used to compute similarity between sentences
# This parameter is the same as in default_reranker.pl
#
# idffile
# -------
# Identical to the same parameter in default_reranker.pl
# 
# datadir
# -------
# Identical to the same parameter in default_reranker.pl

use strict;

use FindBin;
#use lib "$FindBin::Bin/../lib/", "$FindBin::Bin/../lib/arch/";
use lib "/clair4/projects/mead307/source/mead/lib", "/clair4/projects/mead307/source/mead/lib/arch";

################################################################################
#
#	Used modules
#
################################################################################

use POSIX qw(ceil floor);

use XML::Parser;
use XML::Writer;

use MEAD::MEAD;
use MEAD::SimRoutines;
use MEAD::Cluster;

use Essence::IDF;
use Essence::Text;

################################################################################
#
#	Package Variables
#
################################################################################

my $cluster;
my @cluster_DIDs;
my @all_sents;
my @final_sents;

## Needed for XML parsing
my $curr_did;
my $curr_sno;

# command line args.
my $relevance_weight = shift;
my $similarity_function_name = shift;
my $idffile = shift;
my $datadir = shift;

my $compression_basis;
my $compression_percent;
my $compression_absolute;
my $lang;

{
    Debug("runing MMR reranker...",1,"Main");
    Debug("relevance weight     = $relevance_weight", 1, "Main");
    Debug("similarity function  = $similarity_function_name", 1, "Main");

    if ($compression_basis eq "words") {
 	Debug("The MMR reranker only works on sentence compression level",
	      3, "Main");
    }

    my $xml_parser = new XML::Parser(Handlers => {
	'Start' => \&read_rerankerinfo_handle_start,
	'End' => \&read_rerankerinfo_handle_end});
    
    $xml_parser->parse(\*STDIN);

    open_nidf($idffile);

    if ($compression_absolute) {
	undef $compression_percent;
    } elsif ($compression_percent) {
	undef $compression_absolute;
    } else {
	$compression_percent = 20;
	Debug("Neither percent nor absolute specified; using 20%",
	      3, "Main");
    }
   

    normalize_sentence_scores();

    mmr_modify_sentence_scores();

    get_top_sentences();

    &write_sentjudge();
}

#
# Pick ($compression_percent) percent of sentences from
# @all_sents and add them to @final_sents.
#
sub get_top_sentences() {
    my $target = $compression_absolute;
    if ($compression_percent) {
	my $total_sents = @all_sents;
	$target = ceil( ($compression_percent / 100) * $total_sents );
    }

    foreach my $sentref (sort {$$b{'Score'} <=> $$a{'Score'}} @all_sents) {
	last if (@final_sents >= $target);
	push @final_sents, $sentref;
    }
}

#
# Modify scores of all sentences, using an Maximal Marginal Relevance
# (MMR) style approach
#
# This funtion assumes that the old scores are normalized to [0,1]
# This function assumes that the current scores represent the relevance
# measure of the sentences. For every sentence, the function iterates
# through all sentences with higher scores and computes the similarity
# measure using the provided similarity function. The new score for
# every sentence is computed as follows:
# 
# new_score = relevance_weight * relevance - (1-relevance_weight) * similarity
# where
# relevance  = old_score
# similarity = maximum similarity between current sentence and sentences with
#              higher scores
#
sub mmr_modify_sentence_scores {
    my $target = $compression_absolute;
    if ($compression_percent) {
        my $total_sents = @all_sents;
        $target = ceil( ($compression_percent / 100) * $total_sents );
    }

    my @tmp_sents;

    my $sim_routine = $sim_routines{$similarity_function_name};

     foreach my $sentref (sort {$$b{'Score'} <=> $$a{'Score'}} @all_sents) {

 	Debug("Processing sentence $$sentref{'TEXT'}", 1, "mmr_modify_sentence_scores");

 	my $max_lexsim = 0.0;

	if (@tmp_sents <= (2*$target)) {
		# compute maximum similarity of sentence to sentences with higher score
 		foreach my $summsentref (@tmp_sents) {
	 	    my $lexsim = &{$sim_routine}($$summsentref{'TEXT'}, 
 					 $$sentref{'TEXT'});
 		    if ($lexsim > $max_lexsim) {
 			$max_lexsim = $lexsim;
	 	    }

 		    Debug("\tSimilarity of $lexsim to $$summsentref{'TEXT'}",
 			  1,"mmr_modify_sentence_scores");
	 	}
		Debug("Max similarity is $max_lexsim",
              	       1,"mmr_modify_sentence_scores");

	        my $old_score = $$sentref{'Score'};

	        # update sentence score
	        $$sentref{'Score'} = $relevance_weight * $$sentref{'Score'} - 
        	                     ( 1 - $relevance_weight) * $max_lexsim;
	        Debug("MMR updating sentence score from $old_score to $$sentref{'Score'}",
	              1,"mmr_modify_sentence_scores");
	       # add current sentence to list of processed sentences
		push @tmp_sents, $sentref;

	}
	else {
		$$sentref{'Score'} -= 2.0;
	}
     }
}

#
# Normaize scores of all sentences in @all_sents to [0,1] as follows:
# 
# new_score = old_score / maximum_score
#
sub normalize_sentence_scores {
    # find sentence with maximum score
    my $max_sentence_score = 0.0;
    foreach my $sentref (@all_sents) {
	if ($$sentref{'Score'} > $max_sentence_score) {
	    $max_sentence_score = $$sentref{'Score'};
	}
    }
    Debug("maximum sentence score is $max_sentence_score", 1, "NormalizeSentenceScores");
    
    # normalize sentence scores to be in [0,1]
    foreach my $sentref (@all_sents) {
 	my $old_sentence_score = $$sentref{'Score'};
 	$$sentref{'Score'} /= $max_sentence_score;
 	Debug("changing sentence score from $old_sentence_score to $$sentref{'Score'}",
 	      1, "NormalizeSentenceScores");
    }
}

###############################################################################
#
# Utilities.
#
###############################################################################

sub read_rerankerinfo_handle_start {
    shift;
    my $element_name = shift;
    my %atts = @_;

    if ($element_name eq 'COMPRESSION') {
	$compression_basis = $atts{'BASIS'};
	$compression_percent = $atts{'PERCENT'};
	$compression_absolute = $atts{'ABSOLUTE'};
    } elsif ($element_name eq 'CLUSTER') {
	$lang = $atts{'LANG'};
    } elsif ($element_name eq 'D') {
	push @cluster_DIDs, $atts{'DID'}; 
    } elsif ($element_name eq 'S') {
	$curr_did = $atts{'DID'};
	$curr_sno = $atts{'SNO'};
    } elsif ($element_name eq 'JUDGE') {    
	##Add Score element to the current sentence's entry in %{$cluster}
	&record_sentence_info($atts{'UTIL'});
    }
}

sub read_rerankerinfo_handle_end {
    shift;
    my $element_name = shift;
    
    if ($element_name eq 'CLUSTER') {
	$cluster = &load_cluster($datadir, @cluster_DIDs);
    }
}

sub record_sentence_info {

    my $value = shift;

    my %curr_sent = ();

    $curr_did =~ s/\s//;
    my $docref = $$cluster{$curr_did};
    my $sentref = $$docref[$curr_sno];

    $$sentref{'Score'} = $value;

    ## Add a reference to this sentence to the array containing all sentences
    push @all_sents, $sentref;
}

sub write_sentjudge {
    my $total_in_sum = @final_sents;

    my $writer = new XML::Writer(DATA_MODE=>1);
   
    $writer->xmlDecl();
    $writer->doctype("SENT-JUDGE", "", "/clair/tools/mead/dtd/sentjudge.dtd");

    $writer->startTag("SENT-JUDGE", 
		      "QID" => "none",
		      "SENTS-FOR-SUMMARY" => $total_in_sum);

    foreach my $sentref (@all_sents) {

	$writer->startTag("S",
			  "DID" => $$sentref{'DID'},
			  "SNO" => $$sentref{'SNO'},
			  "PAR" => $$sentref{'PAR'},
			  "RSNT" => $$sentref{'RSNT'});
	$writer->emptyTag("JUDGE",
			  "N" => "RERANKER",
			  "UTIL" => $$sentref{'Score'});
	$writer->endTag();
    }

    $writer->endTag();
}
