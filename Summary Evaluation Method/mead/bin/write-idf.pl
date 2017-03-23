#!/usr/bin/perl

use strict;
use DB_File;

my $dbm_name = shift or
    die "Must provide DBM name.";
my $text_file = shift || "-";

my %idf;
#dbmopen %idf, $dbm_name, 0666 or
#    die "Can't open idf: $!\n";

tie(%idf, 'DB_File', $dbm_name) or die "Can't open idf: $!\n";

open INFILE, $text_file or
    die "Unable to open '$text_file' for input\n";

my $total = 0;
while (<INFILE>) {
    my ($key, $value) = /^\s*(\S+)\s+([\d\.]+)\s*/;
    $idf{$key} = $value;

    unless (++$total % 100) {
        print STDERR "Wd: $total\r";
    }
}
print STDERR "\n";

close INFILE;

dbmclose %idf;


