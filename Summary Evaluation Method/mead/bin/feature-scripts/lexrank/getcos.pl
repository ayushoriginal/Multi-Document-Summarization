#!/usr/bin/perl

use FindBin;
use lib "$FindBin::Bin/../../../lib";

use MEAD::SimRoutines;

# some vars for the MEAD routines
our $lang ="ENG";
our $idffile = "enidf";

@lines = <>;

foreach $l (@lines) {
    $i = 0;
    foreach $m (@lines) {
        if ($i < $j) {
	  $cosine = GetLexSim ($l,$m);
	  print "$i $j $cosine\n";
	  print "$j $i $cosine\n";
	}
	$i++;
    }
    $j++;
}

__END__
