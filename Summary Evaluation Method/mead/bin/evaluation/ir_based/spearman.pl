#!/usr/local/bin/perl

$one = shift;
$two = shift;

$debug = shift;

print "$one $two\n";
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
    $rank1{$did} = $rank;
    $count{$did}++;
    $items++;
#    print "rank = $rank lastrank = $lastrank\n";
    if ($rank > $lastrank) {
	if (($rank - $lastrank) > 1) {
#	    print "\n";
#	    print " NR ";
#	    print "rank = $rank lastrank = $lastrank\n";
	    $rerank = ($rank - 1 - $lastrank)/2 + $lastrank;
	    foreach $did (@dids) {
#		print "$did ";
#		print "old rank = $rank1{$did} ";
		$rank1{$did} = $rerank;
#		print "new rank = $rank1{$did} ";
	    }
	}
	@dids = ();
    }
    $lastrank = $rank;
    push (@dids,$did);
#    print "\n";
}

while (<TWO>) {
    chop;
    next unless /DID/;
    /DID=\"(.*)\".*RANK=\"(.*)\".*SCORE=\"(.*)\".*CORR-DOC=\"(.*)\"/;
    ($did,$rank,$score,$corr) = ($1,$2,$3,$4);
    if ($did =~ /\.c$/) {
	$did = $corr;
    }
    print "$did $rank $score $corr \n" if $debug;
#    print "$did $rank $score";
    $score2{$did} = $score;
    $rank2{$did} = $rank;
    $count{$did}++;
#    print "rank = $rank lastrank = $lastrank\n";
    if ($rank > $lastrank) {
	if (($rank - $lastrank) > 1) {
#	    print "\n";
#	    print " NR ";
#	    print "rank = $rank lastrank = $lastrank\n";
	    $rerank = ($rank - 1 - $lastrank)/2 + $lastrank;
	    foreach $did (@dids) {
#		print "$did ";
#		print "old rank = $rank2{$did} ";
		$rank2{$did} = $rerank;
#		print "new rank = $rank2{$did} ";
	    }
	}
	@dids = ();
    }
    $lastrank = $rank;
    push (@dids,$did);
#    print "\n";
}

@count = keys %count;
$union = $#count + 1;

if ($debug) {
    print "UNION = $union\n";
}

%rank = (%rank1,%rank2);

$inter = 0;

foreach $doc (keys %count) {
#    print "$doc $count{$doc}\n";
    $inter++ if $count{$doc} > 1;
}

if ($debug) {
    print "INTERSECT = $inter\n";
}

$n = $union;


if ($debug) {
    print "EACH = $n\n";
}

$n2 = $n * ($n * $n - 1);

sub spearman {
    foreach $doc (keys %rank) {
	$rank1 = $rank1{$doc} || $items+1;
	$rank2 = $rank2{$doc} || $items+1;
	$d = $rank1 - $rank2;
	if ($d < 0) { $d = -$d };
	if ($debug) {
	    print "$doc $rank1 $rank2";
	    print " $d ";
	    print $d*$d;
	}
	$sumd2 += $d * $d;
	if ($debug) {
	    print " $sumd2";
	    print "\n";
	}
    }

    if ($debug) {
	print "1 - ";
	print 6*$sumd2;
	print "/";
	print $n2;
	print " = ";
	print 1-6*$sumd2/$n2;
	print "\n";
    }

return 1-6*$sumd2/$n2;
}

$spearman = &spearman ();
print "SPEARMAN = ";
printf "%6.2f\n", $spearman;
