#!/usr/bin/perl

use File::Copy;

print "<P>CIDR started.";

$code = "T";

dbmopen %nidf, "nidf", 0666
    or die "Can't read nidf: $!\n";

$nidf{'numberofarticles'} = 0;

$nb_clusters = shift || 0;

$threshold = shift || .1;

$debug = 1;
$| = 1;

$capital_bonus = 2;
$word_bonus = 1;

$word_decay = shift || .01;
$keep_threshold = shift || 3;

$tokeep = shift || 10;

$nb_articles = 0;

while (<>) {
    chop;
    $nb_articles++;
    print "Article $nb_articles\n" if $debug; 

    unless ($nb_articles % 500) {
	print "\n"; print `date`;
	print "articles: $nb_articles ";
	print "clusters: $nb_clusters ";
	print "largest cluster: $lg_cluster ";
	print "size: $lg_clustersize\n";
    }

    $this_file = $_;

    print "Checking $this_file\n" if $debug;

    dbmclose %centroid;
    dbmopen %centroid, "centroid", 0666;
    
    %centroidt = ();

   
	my $text = extract_text($this_file);   
	#print STDERR "text = $text\n";
   # open (FILE1,$this_file);
   # while (<FILE1>) {
	#next if />/;
	@words = split (/[0-9\_\W]/,$text);
	$decay = 1;
	for (@words) {
	    next if /^$/;
	    last if $decay <= 0;
	    $n++;
	    $bonus = $word_bonus;
	    if ($_ =~ /^[A-Z][a-z]/) { 
		$bonus = $capital_bonus;
	    };
#	    $decay -= $word_decay if $nidf{$_} > $keep_threshold;
	    $decay -= $word_decay;
#	    $centroidt{&lc($_)} += $bonus*$decay; 
	    $centroidt{&lc($_)} += $bonus;
	}
    #}
    close (FILE1);

    $countc = 0;

    while (($key,$val) = each %centroidt) {
	$test = $val * $nidf{$key};
#	print "$test --> $val --> $nidf{$key}\n";
	if (($test > $keep_threshold) || ($countc < $tokeep)) {
	    $centroid{$key} = $val;
	    $countc++;
	}
    }
    
    $nc = $nb_clusters + 1;
    
#    dbmclose %centroid;

    $max_sim = -1;
    $max_cluster = 0;

    foreach $cluster (1 .. $nb_clusters) {

	print "Checking cluster $cluster\n" if $debug;

	$cl = "00000".$cluster;
	$cl = substr($cl,-5,5);

	

	$sim = &sim("$code-CLUSTER".$cl."/centroid");
	print "Similarity w/cluster $cl is $sim\n" if $debug;

	if ($sim > $max_sim) {
	    $max_cluster = $cluster;
	    $max_sim = $sim;
	}
    }

    if (($max_cluster == 0) || ($max_sim < $threshold)) {
	$nb_clusters++;
	$cl = "00000".$nb_clusters;
	$cl = substr($cl,-5,5);
	print "cl = $cl\n";
	$centroid{'numberofarticles'}++;
	if ($centroid{'numberofarticles'} > $lg_clustersize) {
	    $lg_clustersize = $centroid{'numberofarticles'};
	    $lg_cluster = $cl;
	}
	mkdir "$code-CLUSTER$cl", 0777;
	print "New cluster: $cl\n" if $debug;
	dbmclose %centroid;
	`mv centroid* $code-CLUSTER$cl`;
	copy("$this_file","$code-CLUSTER$cl");
	$where{$this_file} = $cl;
    }
    else {
	$cl = $max_cluster;
	$cl = "00000".$cl;
	$cl = substr($cl,-5,5);
	print "Adding to cluster: $cl\n" if $debug;
	dbmopen %centroid2, "$code-CLUSTER$cl/centroid", 0666;
	
	$na = $centroid2{'numberofarticles'};

	%centroid2t = %centroid2;
	%centroid2 = ();

	@keys = &uniq (sort ((keys %centroid2t),(keys %centroid)));

	foreach $f (@keys) {
	    unless ($f eq "numberofarticles") {
		$centroid2t{$f} = (($centroid2t{$f} * $na) + $centroid{$f}) / ($na + 1);
	    }
	}

	$countc = 0;

	foreach $key (sort revbynidf (keys %centroid2t)) {
	    $val = $centroid2t{$key};
	    $test = $val * $nidf{$key};
	    if (($test > $keep_threshold) || ($countc < $tokeep)) {
		$centroid2{$key} = $val;
		$countc++;
	    }
	}
    
	$centroid2{'numberofarticles'} = $na + 1;
	if ($centroid2{'numberofarticles'} > $lg_clustersize) {
	    $lg_clustersize = $centroid2{'numberofarticles'};
	    $lg_cluster = $cl;
	}
	copy("$this_file","$code-CLUSTER$cl");
	$where{$this_file} = $cl;
	`rm centroid*`;
	dbmclose %centroid2;
    }
}

#while (($key,$val) = each %where) {
#    print "$key --> $val \n";
#}

sub sim {
    ($lcentroid) = @_;

    print "Comparing against $lcentroid\n" if $debug;

#    %lcentroid = ();
    
    dbmclose %lcentroid;
    dbmopen %lcentroid, "$lcentroid", 0666
	or die "Can't read lcentroid: $!\n";

    $ref1 = \%centroid;
    $ref2 = \%lcentroid;

    return &cosine ($ref1,$ref2);

    dbmclose %lcentroid;

}

sub lc {

    ($_) = @_;
   
    tr/[A-Z]/[a-z]/;

    return $_;
}

sub cosine {

    %count1 = %$ref1;
    %count2 = %$ref2;

    @words = &uniq (sort ((keys %count1), (keys %count2)));

    $rs1 = 0;
    $rs2 = 0;
    $c = 0;

#    $more = 5;

    foreach $wd (@words) {

	$c1 = $count1{$wd} || 0;
	$c2 = $count2{$wd} || 0;

#	$idf = log ($NB_DOCS/$nidf{$wd});
	$idf = $nidf{$wd};

#	print "$wd $c1 $c2 $idf\n" if ($debug && $more > 0);
#	$more--;

	$c1 = $c1 * $idf;
	$c2 = $c2 * $idf;

	$c += $c1 * $c2;

	$rs1 += $c1 * $c1;
	$rs2 += $c2 * $c2;

    }

    $r = sqrt ($rs1 * $rs2);

#    print "$c $r\n";
    if ($r == 0) {
	return 0;
    } else {
	return $c/$r;
    }
}

sub uniq {

    $old = "";
    @out = ();

    for (@_) {
	push (@out, $_) unless $_ eq $old;
	$old = $_;
    }

    return @out;

}

sub revbynidf {
    ($centroid2t{$b} * $nidf{$b}) <=> ($centroid2t{$a} * $nidf{$a});
}


sub extract_text($)
	{
	my $filename = shift;
	my $text;
	open (FILE,$filename);
	while (<FILE>)
		{
		#print STDERR "line = $_\n";
		$_ =~ s/<S PAR='.*' RSNT='.*' SNO='.*'>|<\/S>|<\/TEXT>|<\/BODY>|<\/DOCSENT>|<!DOCTYPE .*>|<\?xml version='1.0'\?>|<S PAR=".*" RSNT=".*" SNO=".*">|<BODY>|<HEADLINE>|<\/HEADLINE>|<DOCSENT DID=.*>|<TEXT>//g;
		#print STDERR "line = $_\n";
		if($_ eq "")
			{
			next;
			}
		else
			{
			$text .= $_
			}
		
		}
	close FILE;
	return $text;
	}
