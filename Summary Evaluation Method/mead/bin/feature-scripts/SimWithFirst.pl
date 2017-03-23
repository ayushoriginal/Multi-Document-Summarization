#!/usr/bin/perl

#
#usage: cat <file>.cluster | centroid.pl <idffile> (ENG|CHIN) <datadir>
#

use strict;

use FindBin;
use lib "$FindBin::Bin/../../lib/", "$FindBin::Bin/../../lib/arch/";

use Essence::IDF;

use MEAD::SentFeature;
use MEAD::Evaluation;

my $idffile = shift;
my $lang = shift;
my $datadir = shift;

my %first_sents_text = ();

open_nidf($idffile);

extract_sentfeatures($datadir, 
		     {'Sentence' =>\&sentence, 'Document' => \&document});

sub document {
    my $sents = shift;
    my $did = shift;

    my $first_sent = $$sents[1];
    $first_sents_text{$did} = $$first_sent{'TEXT'};
}

sub sentence {
    my $feature_vector = shift;
    my $sentref = shift;

    my $did = $$sentref{'DID'};
    my $text = $$sentref{'TEXT'};
    my $first_sent_text = $first_sents_text{$did};

    $$feature_vector{'SimWithFirst'} = cosine($text, $first_sent_text);
}
