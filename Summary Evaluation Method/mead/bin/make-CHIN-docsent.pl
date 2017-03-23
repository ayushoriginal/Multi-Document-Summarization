#!/usr/bin/perl

use strict;

use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/../lib/arch";

use MEAD::MEAD;

my $MEADDIR = $MEAD::MEAD::MEADDIR;

my $listfile = shift or
    die "Must provide the name of the list file.\n";

my $encoding = shift or
    die "Must provide the encoding name\n";

my $lang = shift || "CHIN";

my @DIDs = ();

open (LIST, $listfile) or 
    die "Unable to open list file '$listfile'\n";

while (my $line = <LIST>) {
    chomp $line;
    push @DIDs, $line;
}

close LIST;

my $clusterfile = "$listfile.cluster";
my ($vol, $dir, $file) = File::Spec->splitpath($clusterfile);
my $cluster_dir = $dir;
my $docsent_dir = File::Spec->catdir($dir, "docsent");

unless (-d $docsent_dir) {
    print STDERR "Making docsent directory '$docsent_dir'\n";
    mkdir $docsent_dir or
	die "Unable to create docsent directory '$docsent_dir'\n";
}

foreach my $did (@DIDs) {
    my $infile = File::Spec->catfile($cluster_dir, $did);
    my $docsent_file = File::Spec->catfile($docsent_dir, "$did.docsent");

    print STDERR "Converting '$infile' to docsent format.\n";

    make_CHIN_docsent($infile, $docsent_file, $did);
}

&write_cluster($clusterfile, $lang, @DIDs);

sub write_cluster {
    my $cluster_file = shift;
    my $lang = shift;
    my @DIDs = @_;

    open (CLUSTER, "> $cluster_file") or 
	die "Unable to open cluster file: '$cluster_file'\n";

    print CLUSTER "<?xml version='1.0'?>\n";
    print CLUSTER "\n";
    print CLUSTER "<CLUSTER LANG='$lang'>\n";

    foreach my $did (@DIDs) {
	print CLUSTER  "    <D DID='$did' />\n";
    }
    
    print CLUSTER "</CLUSTER>";

    close CLUSTER;
}

sub make_CHIN_docsent {

    my $infile = shift;
    my $docsent_file = shift;
    my $did = shift;

    open (INFILE, "iconv -f $encoding -t BIG5 $infile | ") or
	die "Unable to open (and convert) docc file: '$infile'\n";
    
    open (OUTFILE, "> $docsent_file") or
	die "Unable to open output file for writing: '$docsent_file'\n";

    ## XML Header
    print OUTFILE "<?xml version=\"1.0\"?>\n";
    
    # TODO: fixme
    #print OUTFILE "<!DOCTYPE DOCSENT SYSTEM \"$meadbase/dtd/docsent.dtd\">\n";
    
    print OUTFILE "<DOCSENT DID='$did'>\n";
    print OUTFILE "<BODY>\n";
    print OUTFILE "<TEXT>\n";

    my $paragraph = 0;
    my @sentences = ();
    my $rel_sentence = 0;
    my $merge_sentence = "";
    my $count = 0;
    my $abs_sentence = 0;

    while (<INFILE>) {
	if ($_ ne "") {
	    
	    @sentences = split (/(°C\s?°z\s?°v|°I\s?°z\s?°v|°H\s?°z\s?°v|°T\s?°z\s?°v|°S\s?°z\s?°v|°C\s?°v|°I\s?°v|°H\s?°v|°T\s?°v|°S\s?°v|°S|°T|°C|°H|°I|\?|\!)/);
  	
	    $paragraph++;
	    $rel_sentence = 0;
	    $merge_sentence = "";
	    
	    $count = 0;
	    foreach my $sentence (@sentences) {
		unless ($sentence =~ /^(Å°@|\s)*$/) {
		    if (++$count % 2 == 0) {
			$merge_sentence .= $sentence;
			print OUTFILE "<S PAR=\"".$paragraph."\" RSNT=\"".++$rel_sentence."\" SNO=\"".++$abs_sentence."\">";
			print OUTFILE "$merge_sentence</S>\n";
		    } else {
			$merge_sentence = $sentence;
			if ($count == @sentences) {
			    print OUTFILE "<S PAR=\"".$paragraph."\" RSNT=\"".++$rel_sentence."\" SNO=\"".++$abs_sentence."\">";
			    print OUTFILE "$merge_sentence</S>\n";
			}
		    }
		}
	    }
	}
    }
    
    ## XML Footer
    print OUTFILE "</TEXT>\n";
    print OUTFILE "</BODY>\n";
    print OUTFILE "</DOCSENT>\n";
    
    close OUTFILE;
    close INFILE;
}

