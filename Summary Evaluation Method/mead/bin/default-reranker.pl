#!/usr/bin/perl

use strict;

use FindBin;
use lib "$FindBin::Bin/../lib/", "$FindBin::Bin/../lib/arch/";

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
my $similarity_function_name = shift;
my $similarity_threshold = shift;
my $idffile = shift;
my $datadir = shift;

my $compression_basis;
my $compression_percent;
my $compression_absolute;
my $lang;

{
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

    my $bonus_for_chosen_sentences = 10000.0;
    foreach my $sentref (@all_sents) {
	if ($$sentref{'Score'} > $bonus_for_chosen_sentences) {
	    $bonus_for_chosen_sentences += $$sentref{'Score'};
	}
    }

    if ($compression_basis eq "sentences") {
	get_final_sents_by_sentences();
    } else { # $compression_basis eq "words"
	get_final_sents_by_words();
    }

    foreach my $sentref (@final_sents) {
	$$sentref{'Score'} += $bonus_for_chosen_sentences;
    }

    &write_sentjudge();
}

sub get_final_sents_by_sentences {

    my $target = $compression_absolute;
    if ($compression_percent) {
	my $total_sents = @all_sents;
	$target = ceil( ($compression_percent / 100) * $total_sents );
    }

    my $sim_routine = $sim_routines{$similarity_function_name};

    foreach my $sentref (sort {$$b{'Score'} <=> $$a{'Score'}} @all_sents) {

	last if (@final_sents >= $target);

	my $to_add = 1;

	# check that the sentence is not too similar.
	foreach my $summsentref (@final_sents) {
	    my $lexsim = &{$sim_routine}($$summsentref{'TEXT'}, 
					 $$sentref{'TEXT'});

	    if ($lexsim >= $similarity_threshold) {
		$to_add = 0;
		Debug("Not adding, LexSim: $lexsim",1,"GetFinalSents");
		last;
	    }
	}

	next unless $to_add;

	push @final_sents, $sentref;
    }
    
}

sub get_final_sents_by_words {


    my $target = $compression_absolute;

    if ($compression_percent) {
	my $total_words = 0;
	foreach my $sentref (@all_sents) {
	    my @words = split_words($$sentref{'TEXT'});
	    $total_words += @words;
	}
	$target = ceil( ($compression_percent / 100) * $total_words );
    }

    my $min_words = $target * .9;
    my $max_words = $target * 1.1;
    my $summ_words = 0;
    
    my $sim_routine = $sim_routines{$similarity_function_name};

    foreach my $sentref (sort {$$b{'Score'} <=> $$a{'Score'}} @all_sents) {

	my $to_add = 1;

	my @words = split_words($$sentref{'TEXT'});
	my $sent_words = @words;
	my $potential_summ_words = $summ_words + $sent_words;

	if ($potential_summ_words <= $target) {
	    # we add the sentence.
	} elsif ($summ_words == 0) {
	    # add the sentence.
	} elsif ( abs($potential_summ_words - $target) <
		  abs($summ_words - $target) ) {
	    # we add the sentence.
	} else {
	    $to_add = 0;
	}
	
	last unless $to_add;

        # check that the sentence is not too similar.
        foreach my $summsentref (@final_sents) {
            my $lexsim = &{$sim_routine}($$summsentref{'TEXT'},
                                         $$sentref{'TEXT'});

            if ($lexsim >= $similarity_threshold) {
                $to_add = 0;
                Debug("Not adding, LexSim: $lexsim",1,"GetFinalSents");
                last;
            }
        }

        next unless $to_add;

        push @final_sents, $sentref;
	$summ_words += $sent_words;
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
