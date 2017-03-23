#!/usr/bin/perl

use strict;

use FindBin;

use lib "$FindBin::Bin/../lib", "$FindBin::Bin/../lib/arch";

use MEAD::Evaluation;
use MEAD::Extract;
use MEAD::SentJudge;

my $extract_file = shift;
my $sentjudge_file = shift;

unless ( (defined $extract_file) && (defined $sentjudge_file) ) {
    die "\n\nUsage: ./relative-utility.pl extract_file sentjudge_file";
}

my $e = MEAD::Extract->open_from_file($extract_file);
my $sj = MEAD::SentJudge->open_from_file($sentjudge_file);


my $num = $e->get_num_sentences();
my $total = $sj->get_num_sentences();
my $judges = $sj->get_num_judges();

print "Sentences in Extract: ", $num, "\n";
print "Total Sentences: ", $total, "\n";
print "Num Judges: ", $judges, "\n";

print "\n";

foreach my $jnum (1 .. $judges) {
    print "Judge $jnum Avg: ", $sj->judge_performance($jnum, $num), "\n";
}

print "\n";

print "Average Judge Perf: ", $sj->average_judge_performance($num), "\n";
print "Expected Random Perf: ", $sj->expected_random_performance($num), "\n";
print "Relative Utility: ", relative_utility($e, $sj), "\n";
print "Normalized Relative Utility: ", normalized_relative_utility($e, $sj), "\n";

=item NAME

relative-utility.pl

=item DESCRIPTION

This is an example script that demonstrates the use of the relative utility
metric, and the supporting MEAD::SentJudge module.

Usage:

./relative-utility.pl extract_file sentjudge_fil

=cut
