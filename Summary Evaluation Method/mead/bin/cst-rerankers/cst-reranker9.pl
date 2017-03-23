#!/usr/local/bin/perl

use strict;

use FindBin;
#use lib "$FindBin::Bin/../lib/", "$FindBin::Bin/../lib/arch/";

use lib "/clair2/projects/nie/nie3/MEAD-3.07/lib";
use lib "/clair2/projects/nie/nie3/MEAD-3.07/lib/arch";

################################################################################
#
#	Used modules
#
################################################################################

use POSIX qw(ceil floor);

use XML::Parser;
use XML::Writer;

use MEAD::MEAD;
use MEAD::Cluster;

use Essence::Text;


### Added

# For XML parsing

use lib "/n/nfs/svarog/winkela/perl5/lib/site_perl/5.6.0/";
use XML::TreeBuilder;
use XML::Element;

###

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


### Added

my $MetaDataFileName = shift;
my $SentRelFileName = shift;
my $datadir = shift;

my (%SourceHash, %TimeHash, %SentRelHash, %SourcePriorityHash);
my ($MinTime, $MaxTime);

ParseMetaDataFile($MetaDataFileName);
ParseSentRelFile($SentRelFileName);

# print STDERR "TEST Message!\n";
###

my $compression_basis;
my $compression_percent;
my $compression_absolute;
my $lang;

{
    my $xml_parser = new XML::Parser(Handlers => {
	'Start' => \&read_rerankerinfo_handle_start,
	'End' => \&read_rerankerinfo_handle_end});
    
    $xml_parser->parse(\*STDIN);

    if ($compression_absolute) {
	undef $compression_percent;
    } elsif ($compression_percent) {
	undef $compression_absolute;
    } else {
	$compression_percent = 20;
	Debug("Neither percent nor absolute specified; using 20%",
	      3, "Main");
    }

#    my $bonus_for_chosen_sentences = 10000.0;
#    foreach my $sentref (@all_sents) {
#	if ($$sentref{'Score'} > $bonus_for_chosen_sentences) {
#	    $bonus_for_chosen_sentences += $$sentref{'Score'};
#	}
#    }

#    if ($compression_basis eq "sentences") {
#	get_final_sents_by_sentences();
#    } else { # $compression_basis eq "words"
#	get_final_sents_by_words();
#    }


    ### Ajust scores by time (more recent, the better)
    foreach my $sentref (@all_sents) {
            $$sentref{'Score'} += 
($TimeHash{$$sentref{'DID'}}-$MinTime)/($MaxTime-$MinTime);  
		#'SNO' for sent no.
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

    foreach my $sentref (sort {$$b{'Score'} <=> $$a{'Score'}} @all_sents) {

	last if (@final_sents >= $target);

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


### Added

sub ParseSentRelFile
{
  my $RelationFile = shift;

  my $RelationTree = XML::TreeBuilder->new;
  $RelationTree->parsefile($RelationFile);

  my ($R_node, $REL_node);

  foreach $R_node ($RelationTree->find_by_tag_name('R'))
  {
    my $SDID=$R_node->attr('SDID');
    my $SSENT=$R_node->attr('SSENT');
    my $TDID=$R_node->attr('TDID');
    my $TSENT=$R_node->attr('TSENT');

    my $key = $SDID."\t".$SSENT."\t".$TDID."\t".$TSENT;
    $SentRelHash{$key} = '';

    my @Rel = $R_node->find_by_tag_name('RELATION');
    foreach $REL_node (@Rel)
    {
	my $Type = $REL_node->attr('TYPE');
	$SentRelHash{$key} .= $Type;
    }

  }

}


sub ParseMetaDataFile
{
  my $FileName = shift;
  
  my ($DID, $Source, $Time);
  my $Priority = 0;

  $MinTime = 999999999;
  $MaxTime = -999999999;

  open(TEXT, "<$FileName");

  while (<TEXT>)
  {
	($DID, $Source, $Time) = split;
	$SourceHash{$DID} = $Source;
	$TimeHash{$DID} = $Time;

	if ($MinTime>$Time) {$MinTime=$Time;}
	if ($MaxTime<$Time) {$MaxTime=$Time;}

	if ( !exists($SourcePriorityHash{$Source}) )
	  { $SourcePriorityHash{$Source} = $Priority++; }

  }

  close(TEXT);
}
