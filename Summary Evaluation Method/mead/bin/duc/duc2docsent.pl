#!/usr/bin/perl

use strict;

use File::Spec;
use XML::TreeBuilder;
use HTML::TreeBuilder;

use ParseConfig;

#
# called:
#
# ./duc-duc2docsent.pl <cluster dir>
#
#
# result:
#
# for all *.s documents in the ../clusterdir/docs directory, treats it
# as a DUC format file, and tries to convert it into a docsent file in
# the docsent subdir.  TOOD: create the length sentfeature in feature subdir.
#
# also creates .cluster file in ../clusterdir/. documents listed in
# chronoloical order, assuming file names indicate timestamp
# like so: AP880916-0060

# main code.
{

    my $clusterdir = "/clair4/projects/duc03/clusters/duc03/task2/docs/nyt";

    $clusterdir =~ s/\/$//;

    # my $sourcedir = "$clusterdir/docs";
    my $sourcedir = $clusterdir;

    # get the files.
    opendir (DIR, $sourcedir) or die "Unable to open source dir: $sourcedir\n";
    my @files = grep !/^\.\.?$/, readdir DIR;
    closedir DIR;

print "all files are @files\n";

    my $destdir = "$clusterdir/docsent";

    unless (-e $destdir) {
        print STDERR "Creating directory: $destdir\n";
        mkdir $destdir or die "Unable to create directory: $destdir\n";
        chmod 0770, $destdir;
    }

    # create a docsent from each doc, and build a list of DID, SNO, LENGTH
    # values, pushing each of them onto the end of the list.
    foreach my $file (@files) {

print "doing this file: $file\n";

	my $input = "$sourcedir/$file";

	my $did = $file;
	$did =~ s/\.s$//;

	my $output = "$destdir/$did.docsent";

print "alive\n";
        my $tree = XML::TreeBuilder->new;
print "alive\n";
print "input $input\n";
        $tree->parse_file($input);

print "alive\n";
        my $text_tag = $tree->look_down("_tag", "TEXT");
	die "Could find TEXT tag in document: $input\n" unless $text_tag;

	open (OUTPUT, ">$output") or 
	    die "Unable to open output file $output\n";

print "alive\n";
	# get the docsent DTD file.
	my %config = parse_config("nie.cfg");
	my $dtddir = $config{"dtddir"};
	my $dtd_file = "$dtddir/docsent.dtd";
	
	unless (-s $dtd_file) {
	    die "Docsent DTD file doesn't exist: $dtd_file\n";
	}
print "alive\n";

	# generate XML.
	print OUTPUT "<?xml version='1.0'?>\n";
	print OUTPUT "<!DOCTYPE DOCSENT SYSTEM '$dtd_file'>\n";
	print OUTPUT "<DOCSENT DID='$did'>\n";     # == $docid?????
	print OUTPUT "<BODY>\n";
	print OUTPUT "<TEXT>\n\n";

	my @s_tags = $tree->look_down("_tag", "P");

	my $num = 1;
	foreach my $s (@s_tags) {

	    my ($text) = $s->content_list();

	    print OUTPUT "<S SNO=\"$num\" PAR=\"$num\" RSNT=\"1\">";
	    print OUTPUT $text;
	    print OUTPUT "</S>\n\n";
	    $num += 1;
	}

	print OUTPUT "</TEXT>\n";
	print OUTPUT "</BODY>\n";
	
	print OUTPUT "</DOCSENT>\n";

	close OUTPUT;

	$tree->delete;
    }
}
