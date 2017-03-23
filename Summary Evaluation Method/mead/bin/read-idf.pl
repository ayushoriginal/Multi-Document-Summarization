#!/usr/bin/perl

$db = "/path/to/enidf";

dbmopen %db, $db, 0666;

while (($l,$r) = each %db) {
    $ct++;
    print "$ct\t$l\t*$r*\n";
}
