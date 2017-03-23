#! /usr/bin/perl

# data must be in this format:
#
#     J1 J2 J3
# S-1  0  0  0
# S-2  1  0  0
# S-3  1  1  0
# S-4  1  1  1
# S-5  0  0  0
# S-6  0  0  1

sub main{

    local $no_annotators;
    local $no_categories;
    local %decision = ();
    local %count = ();

    &read_kappa_tab;
    &calculate_kappa;
}

sub read_kappa_tab{
    $lineno = 0;
    while( <> ){
	unless (/^\s*$/){
	    $w = @w = split;
	    if ( $lineno == 0 ){
		for ( $r = 0; $r < $w; $r++ ){
		    if ( $w[$r] !~ /^\s*$/){
			push @annotators,$w[ $r ];
			$no_annotators++;
		    }
		}
	    }
	    else{
		if ( $w ne $no_annotators + 1 ){
		    foreach $w (@w){
			print "$w\n";
		    }
		    chop;
		    $only = $w - 1;
		    die "Kappa.pl:Something wrong with line *$_* ($only annotators 
present, should be $no_annotators)";
		}
		else{
		    for ( $r = 1; $r < $w; $r++ ){
			# have I seen this ID before?
			foreach $cat (keys %{ $count{ $w[ 0 ]}}){
			    if ( $count{ $w[ 0 ] }{ $cat } > 0){
				$seen_before++;
			    }
			}
		    }
		    if ($seen_before){
			$seen_before = 0;
			print STDERR "Ignoring $w[0], seen it before!!!!!!\n";
		    }
		    else{
			for ( $r = 1; $r < $w; $r++ ){
			    #print STDERR "Not ignoring $w[0], never seen it before!!!!!!";
			    $count{ $w[ 0 ] }{ $w[ $r ] }++;
			    $decision{ $w[ 0 ] }{ $annotators[ $r ]} = $w[ $r ];
			    $category{ $w[ $r ]} = "yes";
			}
		    }
		}
	    }
	    $lineno++;
	}
    }
    foreach $cat (keys %category){
	$no_categories++;
    }
}

# before you can call this, you must have called
# read_kappa_tab  and  table_to_accum
# which turns simple table into accumulated table
#  - decision{id}{annotator} = decision
#
# the following data structures must be filled:
#  - %count{id}{decision}
#  - no_annotators (k)
#  - no_categories (n)

sub calculate_kappa{
    local $N = 0;
    local %columnsum = ();
    local %p = ();
    local $rowsum = 0;
    local $P_A = 0;
    local $P_E = 0;

    foreach $id ( sort keys %count ){
	#print "In kappa, I have $id; $no_annotators\n";
	$N++;
	$sum_per_line = 0;
	foreach $cat ( keys %{ $count{ $id }} ){
	    #print "In kappa, I have $cat\n";
	    $rowsum += ( $count{ $id }{ $cat } * ( $count{ $id }{ $cat } - 1)) / ( 
$no_annotators * ( $no_annotators - 1));
	    $columnsum{ $cat } += $count{ $id }{ $cat };
	    $sum_per_line += $count{ $id }{ $cat };
	    #print "Adding up $rowsum (rowsum), $columnsum[$i] (columnsum[i])\n";
	    $no_values = $no_categories;
	}
	if ($no_annotators ne $sum_per_line){
	    print STDERR "Warning: Something wrong with your kappa table at id $id, 
$no_annotators (annotators) , $sum_per_line (sum per line)\n";
	    #print "$_\n";
	}
    }
	
    # calculate P(A)
    if ( $N ne 0 ){
	$P_A = $rowsum / $N;
    }
    else {
	print STDERR "\n---No lines qualified---\n\n";
    }
    
    # calculate P(E)
    foreach $cat ( keys %columnsum ){
	$p{$cat} = $columnsum{$cat} / ( $N * $no_annotators );
	#print "And the probab was $column (column) $p{$cat}\n";
	$P_E += ( $columnsum{$cat} / ($N * $no_annotators) ) * ( $columnsum{$cat} / ($N * 
$no_annotators )) ;
    }


    # calculate kappa
    unless ($P_E == 1.0){
	$kappa = ( $P_A - $P_E ) / ( 1 - $P_E );
    }
    else {
	print STDERR "WARNING: P_E == $P_E\n";
    }

    printf "K=%2.3f, P(A)=%2.3f, P(E)=%2.3f, N=%d, k=%d,  n=%d ( ", $kappa, $P_A, $P_E, 
$N, $no_annotators, $no_categories;
    #print "$kappa\n";
    foreach $cat (keys %category){
	print "$cat ";
    }
    print ")\n";
    if ($print_distribution){
	foreach $cat (keys %columnsum){
	    printf "          %s %1.1f\%", $cat, $p{$cat} * 100.0 ;
	}
	print "\n";
    }
}


sub numerically{ $a <=> $b;}

&main;


