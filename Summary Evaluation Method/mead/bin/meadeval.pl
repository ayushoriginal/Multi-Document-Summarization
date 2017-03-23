#!/usr/bin/perl

use strict;

use FindBin;

use lib "$FindBin::Bin/../lib", "$FindBin::Bin/../lib/arch";

use MEAD::Extract;
use MEAD::Evaluation;

my $e1_file = shift;
my $e2_file = shift;
my $IDF = shift || "../etc/HK-WORD-enidf";

unless ( (defined $e1_file) && (defined $e2_file) ) {
    die "Usage: ./meadeval.pl extract_file_1 extract_file_2\n";
}

my $e1 = MEAD::Extract->open_from_file($e1_file);
my $e2 = MEAD::Extract->open_from_file($e2_file);

print "Precision:\t", precision($e2, $e1), "\n";
print "Recall:\t", recall($e2, $e1), "\n";

print "Kappa:\t", kappa(100, $e1, $e2), "\n";

#
# NOTE: the following content-based measures cannot be directly
# applied to MEAD-style extracts.
#
#print "Unigram Overlap:\t", unigram_overlap($e1->get_text, $e2->get_text), "\n";
#print "Bigram Overlap:\t", bigram_overlap($e1->get_text, $e2->get_text), "\n";
#print "Simple Cosine:\t", simple_cosine($e1->get_text, $e2->get_text), "\n";
#print "Cosine:\t", cosine($e1->get_text, $e2->get_text, $IDF), "\n";


=item NAME

meadeval.pl

=item DESCRIPTION

This is an example script for some of the MEADeval metrics using
MEAD-style extracts.

Usage:

./meadeval.pl extract_file_1 extract_file_2

=cut

