package MEAD::Evaluation;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(precision
         recall
             precisionw
             recallw
         kappa
         relative_utility
         normalized_relative_utility
         unigram_overlap
         bigram_overlap
         simple_cosine
         cosine);

use strict;

use Essence::IDF;
use MEAD::SentJudge;

=head1 NAME

MEAD::Evaluation

=head1 DESCRIPTION

The DUC::Evaluation is the main class for MEADeval, an evaluation 
tool for summarizers, both abstractive and extractive.

TODO: Change this class's name from DUC::Evaluation to MEAD::Evaluation.

=head1 METHODS

=over 2

=cut

=item $p = precision($extract, $standard);

p = match ($extract, $standard) / num ($extract)

=cut

sub precision {
    my ($extract, $standard) = @_;

    my %e;
    my %s;
    my %both;
    my $count_e = 0;
    my $count_s = 0;
    my $count_both = 0;

    foreach my $i (1..$extract->get_num_sentences) {
    my $did = $extract->get_DID_for_sentence($i);
    my $sno = $extract->get_SNO_for_sentence($i);
    $e{"$did#$sno"} = 1;
    }

    foreach my $i (1..$standard->get_num_sentences) {
    my $did = $standard->get_DID_for_sentence($i);
    my $sno = $standard->get_SNO_for_sentence($i);
    $s{"$did#$sno"} = 1;
    }

    foreach my $key (keys %e) {
    $both{$key}++;
    $count_e++;
    }

    foreach my $key (keys %s) {
    $both{$key}++;
    $count_s++;
    }

    foreach my $key (keys %both) {
    if ($both{$key} == 2) {
        $count_both++;
    }
    }

    my $precision = $count_both/$count_e;
    return $precision;
}


=item $r = recall($extract, $standard);

r = match ($extract, $standard) / num ($standard)

=cut

sub recall {
    my ($extract, $standard) = @_;

    my %e;
    my %s;
    my %both;
    my $count_e = 0;
    my $count_s = 0;
    my $count_both = 0;

    foreach my $i (1..$extract->get_num_sentences) {
        my $did = $extract->get_DID_for_sentence($i);
        my $sno = $extract->get_SNO_for_sentence($i);
        $e{"$did#$sno"} = 1;
    }

    foreach my $i (1..$standard->get_num_sentences) {
        my $did = $standard->get_DID_for_sentence($i);
        my $sno = $standard->get_SNO_for_sentence($i);
        $s{"$did#$sno"} = 1;
    }

    foreach my $key (keys %e) {
        $both{$key}++;
        $count_e++;
    }

    foreach my $key (keys %s) {
        $both{$key}++;
        $count_s++;
    }

    foreach my $key (keys %both) {
        if ($both{$key} == 2) {
            $count_both++;
        }
    }

    my $recall = $count_both/$count_s;
    return $recall;
}


=item $pw = precisionw($extract, $standard) 

=cut

sub precisionw {
    my ($extract, $standard) = @_;

    my %e;
    my %ew;
    my %s;
    my %sw;
    my %both;
    my $count_e = 0;
    my $count_s = 0;
    my $count_both = 0;

    foreach my $i (1..$extract->get_num_sentences) {
    my $did = $extract->get_DID_for_sentence($i);
    my $sno = $extract->get_SNO_for_sentence($i);
    my $wcnt = $extract->get_WCNT_for_sentence($i);
    $e{"$did#$sno"} = 1;
    $ew{"$did#$sno"} = $wcnt;
    }

    foreach my $i (1..$standard->get_num_sentences) {
    my $did = $standard->get_DID_for_sentence($i);
    my $sno = $standard->get_SNO_for_sentence($i);
    my $wcnt = $standard->get_WCNT_for_sentence($i);
    $s{"$did#$sno"} = 1;
    $sw{"$did#$sno"} = $wcnt;
    }

    foreach my $key (keys %e) {
    $both{$key}++;
    $count_e+=$ew{$key};
    }

    foreach my $key (keys %s) {
    $both{$key}++;
    $count_s+=$sw{$key};
    }

    foreach my $key (keys %both) {
    if ($both{$key} == 2) {
        $count_both+=$ew{$key};
    }
    }

    my $precisionw = $count_both/$count_e;
    return $precisionw;
}


=item $rw = recallw($extract, $standard) 

=cut

sub recallw {
    my ($extract, $standard) = @_;

    my %e;
    my %ew;
    my %s;
    my %sw;
    my %both;
    my $count_e = 0;
    my $count_s = 0;
    my $count_both = 0;

    foreach my $i (1..$extract->get_num_sentences) {
    my $did = $extract->get_DID_for_sentence($i);
    my $sno = $extract->get_SNO_for_sentence($i);
    my $wcnt = $extract->get_WCNT_for_sentence($i);
    $e{"$did#$sno"} = 1;
    $ew{"$did#$sno"} = $wcnt;
    }

    foreach my $i (1..$standard->get_num_sentences) {
    my $did = $standard->get_DID_for_sentence($i);
    my $sno = $standard->get_SNO_for_sentence($i);
    my $wcnt = $standard->get_WCNT_for_sentence($i);
    $s{"$did#$sno"} = 1;
    $sw{"$did#$sno"} = $wcnt;
    }

    foreach my $key (keys %e) {
    $both{$key}++;
    $count_e+=$ew{$key};
    }

    foreach my $key (keys %s) {
    $both{$key}++;
    $count_s+=$sw{$key};
    }

    foreach my $key (keys %both) {
    if ($both{$key} == 2) {
        $count_both+=$ew{$key};
    }
    }

    my $recallw = $count_both/$count_s;
    return $recallw;
}


=item $k = kappa($num_sentences, @extracts);

k = ( P(A) - P(E) ) / ( 1 - P(E) )

P(A) is the precision between the extract and the standard.
P(E) is the percent of the time that the exract and the
standard would be expected to agree (randomly?)

Also need to get # sentences to compute P(E).  That's why
we take $cluster.

=cut

sub kappa {
    my ($num_sentences, @extracts) = @_;

    my $no_annotators = scalar @extracts;

    # first, make a list of the judges' decisions.
    my %judges;
    my $i = 0; #the judge index.
    foreach my $extract (@extracts) {
    $i++;
    foreach my $s (1..$extract->get_num_sentences) {
        my $did = $extract->get_DID_for_sentence($s);
        my $sno = $extract->get_SNO_for_sentence($s);
        $judges{$i}{"$did#$sno"} = 1;
    }
    }

    # make a list of the sentences used.
    my %sentences;
    foreach my $judgeid (1..$no_annotators) {
    my %sids = %{$judges{$judgeid}};
    foreach my $sid (keys %sids) {
        $sentences{$sid} = 1; # just define it as something.
    }
    }

    # create some fake sentences...
    $num_sentences -= scalar keys %sentences;
    foreach my $i (1..$num_sentences) {
    $sentences{"fakesentence$i"} = 1;
    }

    # now fill up %count and %decision.
    # TODO: we can do this whole damn thing way more efficiently...

    my %count;
    my %decision;

    foreach my $sid (keys %sentences) {
    foreach my $judgeid (1..$no_annotators) {
        if ($judges{$judgeid}{$sid}) {
        $decision{$sid}{$judgeid} = 1;
        $count{$sid}{1}++;
        } else {
        $decision{$sid}{$judgeid} = 0;
        $count{$sid}{0}++;
        }
    }
    }

    # go about calculating P(A), P(E), and Kappa.

    my $N = 0;
    my %columnsum = ();
    my %p = ();
    my $rowsum = 0;
    my $P_A = 0;
    my $P_E = 0;
    my $kappa;

    foreach my $id ( sort keys %count ){
        $N++;
        my $sum_per_line = 0;
        foreach my $cat ( keys %{ $count{ $id }} ){
            $rowsum += 
        ( $count{ $id }{ $cat } * ( $count{ $id }{ $cat } - 1 ) ) / 
            ( $no_annotators * ($no_annotators - 1));
            $columnsum{ $cat } += $count{ $id }{ $cat };
            $sum_per_line += $count{ $id }{ $cat };
        }
        if ($no_annotators ne $sum_per_line){
            print STDERR "Warning: Something wrong with your kappa table at id $id, $no_annotators (annotators) , $sum_per_line (sum per line)\n";
        }
    }

    # calculate P(A)
    if ( $N ne 0 ){
        $P_A = $rowsum / $N;
    } else {
        print STDERR "\n---No lines qualified---\n\n";
    }

    # calculate P(E)
    foreach my $cat ( keys %columnsum ){
        $p{$cat} = $columnsum{$cat} / ( $N * $no_annotators );
        $P_E += 
        ( $columnsum{$cat} / ($N * $no_annotators) ) * 
        ( $columnsum{$cat} / ($N * $no_annotators )) ;
    }

    # calculate kappa
    unless ($P_E == 1.0){
        $kappa = ( $P_A - $P_E ) / ( 1 - $P_E );
    } else {
        print STDERR "WARNING: P_E == $P_E\n";
    }

    # TODO: return a tuple of things...

    return $kappa;
}


=item $ru = relative_utility($extract, $sentjudge);

=cut

sub relative_utility {
    my ($extract, $sentjudge) = @_;

    my $score = 0;
    my $size = $extract->get_num_sentences;
    my $num_judges = $sentjudge->get_num_judges;
    foreach my $snum (1 .. $size) {
    foreach my $jnum (1 .. $num_judges) {
        my $did = $extract->get_DID_for_sentence($snum);
        my $sno = $extract->get_SNO_for_sentence($snum);

        my $util = $sentjudge->get_judgment($jnum, $did, $sno);

        my $judge_score = $util / 
        $sentjudge->get_judge_utility_for_extract_size($jnum, $size);
        $score += $judge_score;
    }
    }

    $score /= $num_judges;
    return $score;
}


=item $nru = normalized_relative_utility($extract, $sentjudge)

=cut

sub normalized_relative_utility {
    my ($extract, $sentjudge) = @_;

    my $random = $sentjudge->expected_random_performance
    ($extract->get_num_sentences);
        
    my $judges = $sentjudge->average_judge_performance
    ($extract->get_num_sentences);

    if ($judges <= $random) {
    die "Judges = $judges, Random = $random!!!!\n";
    }

    my $score = relative_utility($extract, $sentjudge);

    my $normalized_ru = ($score - $random) / ($judges - $random);
    return $normalized_ru;
}

=item relevance_correlation

Haven't implemented this yet...

=cut

sub relevance_correlation {

}

=item $uo = unigram_overlap($text1, $text2);

=cut

sub unigram_overlap {
    my ($text1, $text2) = @_;

    # better way to split?  Maybe get rid of some punctuation???
    my @tokens1 = split(/ /, $text1);
    my @tokens2 = split(/ /, $text2);

    my %set1 = ();
    my %set2 = ();

    foreach my $token (@tokens1) {
    $set1{$token}++;
    }

    foreach my $token (@tokens2) {
        $set2{$token}++;
    }

    my $overlap = _set_overlap(\%set1,\%set2);
    my $normalized = $overlap / 
    ( scalar(keys(%set1)) + scalar(keys(%set2)) - $overlap);

    return $normalized;
}

# two questions:
# 1) is there a better way to split tokens????
# 2) do we really want to alphabetize the tokens????

=item $bg = bigram_overlap($text1, $text2);

=cut

sub bigram_overlap {
    my ($text1, $text2) = @_;

    # better way to split?  Maybe get rid of some punctuation???
    my @tokens1 = split(/ /, $text1);
    my @tokens2 = split(/ /, $text2);

    my %set1 = ();
    my %set2 = ();

    my $bigram;
    my $last;
    
    $last = scalar(@tokens1) - 1;
    for (my $i = 0; $i < $last; $i++) {
    if ($tokens1[$i] le $tokens1[$i+1]) {
        $bigram = "$tokens1[$i]#$tokens1[$i+1]";
    } else {
        $bigram = "$tokens1[$i+1]#$tokens1[$i]";
    }

    $set1{$bigram}++;
    }

    $last = scalar(@tokens2) - 1;
    for (my $i = 0; $i < $last; $i++) {
        if ($tokens2[$i] le $tokens2[$i+1]) {
            $bigram = "$tokens2[$i]#$tokens2[$i+1]";
        } else {
            $bigram = "$tokens2[$i+1]#$tokens2[$i]";
        }

        $set2{$bigram}++;
    }

    my $overlap = _set_overlap(\%set1,\%set2);
    my $normalized = $overlap /
        ( scalar(keys(%set1)) + scalar(keys(%set2)) - $overlap);

    return $normalized;
}


sub _set_overlap {
    my ($s1, $s2) = @_;

    my %s1 = %$s1;
    my %s2 = %$s2;
    my $overlap = 0;

    foreach my $key (keys %s1) {
        if ($s2{$key}) {
            $overlap++;
        }
    }

    return $overlap;
}

#
# Make me so that I can accept lists of tokens...
#

=item $c = simple_cosine($text1, $text2);

=cut

sub simple_cosine {
    my ($text1, $text2) = @_;

    # again, a better way to split????
    my @tokens1 = split(/ /, $text1);
    my @tokens2 = split(/ /, $text2);

    my %set1;
    my %set2;

    foreach my $token (@tokens1) {
    $set1{$token}++;
    }

    foreach my $token (@tokens2) {
    $set2{$token}++;
    }

    my $cos = 0;

    foreach my $key (keys %set1) {
        if ( $set2{$key} ) {
            $cos++;
        }
    }

    $cos = $cos / sqrt ( (scalar keys %set1) * (scalar keys %set2) );
    return $cos;
}

#
# same as above, but with IDF.
#

=item $c = cosine($text1, $text2, $idf_filename);

=cut

sub cosine {
    my ($text1, $text2, $idf_file) = @_;

    if ($idf_file) {
        open_nidf($idf_file);
    }

    # better way to split...
    my @tokens1 = split(/ /, $text1);
    my @tokens2 = split(/ /, $text2);

    my %set1;
    my %set2;

    # TODO: do we need to lowercase all these tokens???

    foreach my $token (@tokens1) {
        $set1{$token}++;
    }

    foreach my $token (@tokens2) {
        $set2{$token}++;
    }

    foreach my $key (keys %set1) {
        $set1{$key} *= get_nidf($key);
    }

    foreach my $key (keys %set2) {
        $set2{$key} *= get_nidf($key);
    }

    my $norm1 = 0;
    my $norm2 = 0;
    my $cos = 0;

    foreach my $key (keys %set1) {
        my $val = $set1{$key};
        $norm1 += $val * $val;

        if ($set2{$key}) {
            $cos += $val * $set2{$key};
        }
    }

    foreach my $key (keys %set2) {
        my $val = $set2{$key};
        $norm2 += $val * $val;
    }

    if ($cos == 0) {
        return $cos;
    }

    $cos = $cos / sqrt($norm1 * $norm2);
    return $cos;
}
