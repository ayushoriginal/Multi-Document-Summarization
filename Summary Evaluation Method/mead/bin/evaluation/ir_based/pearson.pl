#!/usr/local/bin/perl

$one = shift;
$two = shift;

$debug = shift;

print "$one $two ";
open (ONE,"$one");
open (TWO,"$two");

$lastrank = 0;

while (<ONE>) {
    chop;
    next unless /DID/;
    /DID=\"(.*)\".*RANK=\"(.*)\".*SCORE=\"(.*)\".*CORR-DOC=\"(.*)\"/;
    ($did,$rank,$score,$corr) = ($1,$2,$3,$4);
    print "$did $rank $score $corr \n" if $debug;
    if ($did =~ /\.c$/) {
	$did = $corr;
    }
    $score1{$did} = $score;
    $count{$did}++;
    $totalscore1 += $score;
    $items++;
}

while (<TWO>) {
    chop;
    next unless /DID/;
    /DID=\"(.*)\".*RANK=\"(.*)\".*SCORE=\"(.*)\".*CORR-DOC=\"(.*)\"/;
    ($did,$rank,$score,$corr) = ($1,$2,$3,$4);
    print "$did $rank $score $corr \n" if $debug;
    if ($did =~ /\.c$/) {
	$did = $corr;
    }
    $score2{$did} = $score;
    $count{$did}++;
    $totalscore2 += $score;
    $items++;
}

$average1 = $totalscore1 / $items;

if ($debug) {
    print "AVERAGE1 = $average1\n";
}

$average2 = $totalscore2 / $items;

if ($debug) {
    print "AVERAGE2 = $average2\n";
}

%score = (%score1, %score2);

@count = keys %count;
$union = $#count + 1;

if ($debug) {
    print "UNION = $union\n";
}

$inter = 0;

foreach $doc (keys %count) {
#    print "$doc $count{$doc}\n";
    $inter++ if $count{$doc} > 1;
}

if ($debug) {
    print "INTERSECT = $inter\n";
}

$n = $items;
$n = $union;

if ($debug) {
    print "EACH = $n\n";
}

sub pearson {
    foreach $doc (keys %score) {
	$score1 = $score1{$doc} || 0;
	$score2 = $score2{$doc} || 0;
	$t1 = $score1-$average1;
	$t2 = $score2-$average2;
	if ($debug) {
	    print "$doc $score1 $score2 ";
	    print " $t1 $t2 ";
	    print "\n";
	}
	$sum1 += $t1*$t2;
	$sum2 += $t1*$t1;
	$sum3 += $t2*$t2;
    }

    $r = $sum1/(sqrt($sum2)*sqrt($sum3));

#    print "$sum1/(sqrt($sum2)*sqrt($sum3))\n";
    return $r;
}

$pearson = &pearson ();
print "PEARSON = ";
printf "%6.2f\n", $pearson;
