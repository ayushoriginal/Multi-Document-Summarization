#!/usr/bin/perl
#
#usage: cat <file>.cluster | centroid.pl <datadir>
#

use strict;

use FindBin;
use lib "$FindBin::Bin/../../lib", "$FindBin::Bin/../../lib/arch";

use MEAD::SentFeature;

my $datadir = shift;

extract_sentfeatures($datadir, {'Sentence' => \&sentence});

sub sentence {
    my $feature_vector = shift;
    my $attribs = shift;

    my $num = $$attribs{"SNO"};

    if ($num > 0) {
	$$feature_vector{"Position"} = sprintf("%17.15f", sqrt(1/$num));
    } else {
	$$feature_vector{"Position"} = 0;
    }
}
