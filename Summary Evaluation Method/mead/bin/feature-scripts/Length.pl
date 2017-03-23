#!/usr/bin/perl

#
#usage: cat <file>.cluster | centroid.pl  <datadir>
#

use strict;

use FindBin;
use lib "$FindBin::Bin/../../lib", "$FindBin::Bin/../../lib/arch";

use Essence::Text;
use MEAD::SentFeature;

my $datadir = shift;

extract_sentfeatures($datadir, {'Sentence' => \&sentence});

sub sentence {
    my $feature_vector = shift;
    my $attribs = shift;
     
    my @words = split_words($$attribs{'TEXT'});
    $$feature_vector{'Length'} = @words;
}
