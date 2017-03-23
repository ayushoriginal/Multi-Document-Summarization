#!/usr/bin/perl

#
#usage: cat <file>.cluster | ./IsLongestSentence.pl <datadir>
#

# NOTE: this script assigns feature value of 1 to only THE FIRST
# sentence whose length is >= the length of any other sentence
# in the document.  This doesn't sound right to me.

use strict;

use FindBin;
use lib "$FindBin::Bin/../../lib/", "$FindBin::Bin/../../lib/arch/";

use MEAD::SentFeature;
use Essence::Text qw(split_words);

my $datadir = shift;

my $longest_sentence_sno;

extract_sentfeatures($datadir, {'Sentence' => \&sentence,
				'Document' => \&document});

sub document {
    my $document = shift;

    # find longest sentence
    $longest_sentence_sno = 0;
    my $longest_sentence_length = 0;
    foreach my $sentence (@{$document}) {
	my @sentence = split_words($$sentence{'TEXT'});
	my $current_sentence_length = @sentence;
	if ($current_sentence_length > $longest_sentence_length) {
	    $longest_sentence_length = $current_sentence_length;
	    $longest_sentence_sno = $$sentence{'SNO'};
	}
    }
}

sub sentence {
    my $feature_vector = shift;
    my $attribs = shift;

    if ($$attribs{'SNO'} == $longest_sentence_sno) {
	$$feature_vector{'IsLongestSentence'} = 1;
    } else {
	$$feature_vector{'IsLongestSentence'} = 0;
    }
}
