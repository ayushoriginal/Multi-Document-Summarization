#!/usr/local/bin/perl -w
#use NDBM_File;
package Essence::IDF;
require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw(open_nidf
             get_nidf);

use strict;

use File::Spec;

use MEAD::MEAD;

use vars qw($current_dbmname
            $DEFAULT_DBMNAME
            $DEFAULT_UNKNOWN_IDF
            $IDFDIR
            %nidf);

$DEFAULT_DBMNAME = "enidf";

# if the word is not in the dbm, return this value.
$DEFAULT_UNKNOWN_IDF = 0.1;

$IDFDIR = File::Spec->catdir($MEAD::MEAD::MEADDIR, "etc");

sub open_nidf{
    my $dbmname = shift || $DEFAULT_DBMNAME;

    $dbmname = File::Spec->rel2abs($dbmname, $IDFDIR);

    if ($current_dbmname && $current_dbmname eq $dbmname) {
        return 1;
    }

use DB_File;
    #unless (dbmopen %nidf, $dbmname, 0666) {
    #    die "Cannot open DBM $dbmname";
    #}

    unless (tie(%nidf,"DB_File", $dbmname, O_RDWR|O_CREAT, 0644)) {
        die "Cannot open DBM $dbmname";
    }
    
    unless (scalar(keys(%nidf))) {
        die "Empty DBM $dbmname";
    }

    $current_dbmname = $dbmname;

    return 1;
}

sub get_nidf {

    my $word = shift;

    unless (defined $current_dbmname) {
        open_nidf($DEFAULT_DBMNAME);
    }

    if (defined $nidf{$word}) {
        return $nidf{$word};
    }

    return $DEFAULT_UNKNOWN_IDF;
}

1;






