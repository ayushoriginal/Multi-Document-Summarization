#!/usr/bin/perl

use strict;

use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/../lib/arch";

use XML::Parser;
use XML::Writer;

use MEAD::MEAD;
use MEAD::Cluster;
use MEAD::SentFeature;

my %fnames = ();
my @all_sents = ();

{
    &parse_options();
    
    my %features = read_sentfeature();
    @all_sents = @{ flatten_cluster(\%features) };
   
    ##Score the sentences based upon their weights
    &compute_scores();

    ##Write out the new scores to a sentjudge file
    &write_sentjudge();
}

sub compute_scores {
    my $total_sent_num = @all_sents;
    Debug("$total_sent_num sentences",1,"GetScore");

    ##Now compute sentence scores based on weight
    foreach my $sentref (@all_sents) {

	my $sno = $$sentref{'SNO'};
	if ($sno) {
	    $$sentref{'FinalScore'} = 1/$sno;
	} else {
	    $$sentref{'FinalScore'} = 0;
	}

	if (! $$sentref{'Length'}) {
	    Debug("No Length feature.  Ignoring Length for this sentence.",
		  1, "compute_scores");
	} elsif ($$sentref{'Length'} && 
		 $$sentref{'Length'} < $fnames{'Length'}) {
            $$sentref{'FinalScore'} = 0;
	    Debug("Throwing out sentence: Length < $fnames{'Length'}",
		  1, "compute_scores");
	}

        Debug("Assigning Final Score of $$sentref{'FinalScore'}",
	      1, "compute_scores");
    }

}

sub parse_options {

    ##If there's no input file
    if (@ARGV < 1 || @ARGV % 2) {
	Debug ("usage: default-classifier.pl fname1 weight1 fname2 weight2 ..." , 3, "ParseOpts");
	exit(1);
    }

    my $fname;
    my $weight;

    while (($fname = shift @ARGV) && ($weight = shift @ARGV)) {
	$fnames{$fname} = $weight;
	Debug("$fname : $weight",1,"ParseOpts");
    }
}

sub write_sentjudge {

    my $writer = new XML::Writer(DATA_MODE=>1);
   
    $writer->xmlDecl();
    $writer->doctype("SENT-JUDGE", "", "/clair/tools/mead/dtd/sentjudge.dtd");

    $writer->startTag("SENT-JUDGE", "QID"=>"none");

    ##MEAD input doesn't store RSNT and PAR.  For now, don't output it
    foreach my $sentref (@all_sents) {
  	$writer->startTag("S", 
			  "DID"=>$$sentref{"DID"},
			  "SNO"=>$$sentref{"SNO"});
 
        $writer->emptyTag("JUDGE", 
			  "N" => "CLASSIFIER", 
			  "UTIL"=>$$sentref{"FinalScore"});
        $writer->endTag();
    }
    
    $writer->endTag();
    $writer->end();
}
