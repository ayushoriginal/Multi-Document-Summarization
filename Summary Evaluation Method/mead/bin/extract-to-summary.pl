#!/usr/bin/perl

use strict;

use FindBin;
use lib "$FindBin::Bin/../lib/", "$FindBin::Bin/../lib/arch/";

#use XML::Parser;
use MEAD::MEAD;
use MEAD::Cluster;
use MEAD::Extract;


{
    my $cluster_file = shift or
	die "Must provide cluster file\n";
    my $docsent_dir = shift or
	die "Must provide docsent dir\n";
    my $extract_arg = shift || "-";

    my $extract = read_extract($extract_arg);
    
    my $cluster = read_cluster($cluster_file, $docsent_dir);
    
    my $summary = extract_to_summary($extract, $cluster);
    
    write_summary($summary);

    exit(0);
}    
