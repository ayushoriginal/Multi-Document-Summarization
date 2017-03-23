


sub my_lcs {


# computes the EDIT matrix

my $string1 = shift;

die "Where is the string?\n" unless defined($string1);


my $string2 = shift;

die "Where is the second string?\n" unless defined($string2);
 



($edi,$l1,$l2) = my_edit_di($string1,$string2);

$lcs = ($l1+$l2-$edi)/2;



return $lcs;




}


sub my_edit_di {
my @EDIT;
my @DECODING;
my $x = shift; # first string
my $y = shift; # scond string



my @array_x = split(/ /,$x);
my @array_y = split(/ /,$y);



my $m = $#array_x + 1; # length of first string
my $n = $#array_y + 1; # length of second string
#print "A: @array_x, $m\n";
#print "B: @array_y, $n\n";



# initialization

for($i=0; $i<= $m; $i++) {
    $EDIT[$i][0]=$i;
    $DECODING[$i][0]=0;
}
for($j=0; $j<= $n; $j++) {
    $EDIT[0][$j]=$j;
    $DECODING[0][$j]=1;
}  
# dynamic programming
for($i=1; $i<= $m; $i++) {

    for($j=1;$j<= $n; $j++) {
	@aux = ($EDIT[$i-1][$j]+1,
		$EDIT[$i][$j-1]+1, 
		$EDIT[$i-1][$j-1]+delta($array_x[$i-1],$array_y[$j-1])
		);
	    $pos = where_min(@aux);
	$EDIT[$i][$j] = $aux[$pos];

	$DECODING[$i][$j] = $pos;
    }
}

#for($i=1; $i<= $m; $i++) {

#    for($j=1;$j<= $n; $j++) {
#	print  $EDIT[$i][$j]." - ";
#    }
#    print "\n";
#}


# print decoding

$row = $m; 
$col = $n;
my @instructions = ();
my $count=0;
while($row>=0 && $col>=0) {
#    print "AT POSITION: $row, $col\n";
    if($row==0 && $col==0) {
	$row--;
	$col--;
	next;
    } else {
    if($DECODING[$row][$col]==0) {
	$row=$row-1;
        $instruction = "delete ".$array_x[$row];$count++;
    } elsif($DECODING[$row][$col]==1) {
	$col=$col-1;
	$instruction = "insert ".$array_y[$col];$count++;
    } elsif($DECODING[$row][$col]==2) {
	$row=$row-1;
	$col=$col-1;
	if($EDIT[$row][$col]==$EDIT[$row+1][$col+1]) {
	    $instruction="no change";
	} else { $instruction = "change ".$array_x[$row]." by ".$array_y[$col];$count=$count+2; }

    } else { die "Invalid Code\n"; }

    push @instructions, $instruction;
}
}

#foreach $e (reverse @instructions) {

#    print "$e\n";
#}


return ($count,$m,$n);



}




sub edit_tokens {

my @EDIT;
my @DECODING;
my $x = shift; # first string
my $y = shift; # scond string



my @array_x = split(/ /,$x);
my @array_y = split(/ /,$y);



my $m = $#array_x + 1; # length of first string
my $n = $#array_y + 1; # length of second string
#print "A: @array_x, $m\n";
#print "B: @array_y, $n\n";



# initialization

for($i=0; $i<= $m; $i++) {
    $EDIT[$i][0]=$i;
    $DECODING[$i][0]=0;
}
for($j=0; $j<= $n; $j++) {
    $EDIT[0][$j]=$j;
    $DECODING[0][$j]=1;
}  
# dynamic programming
for($i=1; $i<= $m; $i++) {

    for($j=1;$j<= $n; $j++) {
	@aux = ($EDIT[$i-1][$j]+1,
		$EDIT[$i][$j-1]+1, 
		$EDIT[$i-1][$j-1]+delta($array_x[$i-1],$array_y[$j-1])
		);
	    $pos = where_min(@aux);
	$EDIT[$i][$j] = $aux[$pos];

	$DECODING[$i][$j] = $pos;
    }
}

#for($i=1; $i<= $m; $i++) {

#    for($j=1;$j<= $n; $j++) {
#	print  $EDIT[$i][$j]." - ";
#    }
#    print "\n";
#}


# print decoding

$row = $m; 
$col = $n;
my @instructions = ();
while($row>=0 && $col>=0) {
#    print "AT POSITION: $row, $col\n";
    if($row==0 && $col==0) {
	$row--;
	$col--;
	next;
    } else {
    if($DECODING[$row][$col]==0) {
	$row=$row-1;
        $instruction = "delete ".$array_x[$row];
    } elsif($DECODING[$row][$col]==1) {
	$col=$col-1;
	$instruction = "insert ".$array_y[$col];
    } elsif($DECODING[$row][$col]==2) {
	$row=$row-1;
	$col=$col-1;
	if($EDIT[$row][$col]==$EDIT[$row+1][$col+1]) {
	    $instruction="no change";
	} else { $instruction = "change ".$array_x[$row]." by ".$array_y[$col]; }

    } else { die "Invalid Code\n"; }

    push @instructions, $instruction;
}
}

#foreach $e (reverse @instructions) {

#    print "$e\n";
#}
return $EDIT[$m][$n];

}

sub where_min {
    my @a = @_;
    my $l = $#a;
    my $i;
    my $min = 0;
    for($i=0;$i<=$l;$i++) {
       
	if($a[$min]>$a[$i]) { $min = $i; }
    }
    return $min;

}

sub min {
    my @a = @_;
    my $l = $#a;
    my $i;
    my $min = $a[0];
    for($i=0;$i<=$l;$i++) {
       
	if($min>$a[$i]) { $min = $a[$i]; }
    }
    return $min;
}

sub delta {
    my $a = shift;
    my $b = shift;
    return ($a eq $b ? 0 : 1);
    
    
}


return(5);
