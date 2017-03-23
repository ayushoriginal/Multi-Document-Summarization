#!/usr/bin/perl

use strict;

use FindBin;
use lib "$FindBin::Bin/../lib/", "$FindBin::Bin/../lib/arch/";

use POSIX qw(ceil);

use MEAD::Cluster;
use MEAD::SentJudge;
use MEAD::Extract;

my $DEFAULT_SIZE = 10; # in sentences.

my $percent;
my $absolute;

my @judges;

my $sentjudge_arg;

{
    parse_options(@ARGV);

    my %sentjudge = read_sentjudge($sentjudge_arg);

    # resolve the percent/absolute tension...
    my $size;
    if ($absolute) {
	$size = $absolute;
    } elsif ($percent) {
	my $flattened_sentjudge = flatten_cluster(\%sentjudge);
	$size = ceil( ($percent/100) * scalar(@$flattened_sentjudge) );
    } else {
	$size = $DEFAULT_SIZE;
    }

    my $extract = sentjudge_to_extract(\%sentjudge, $size, @judges);

    write_extract($extract);
}

sub parse_options {
    my @params = @_;

    my $p;

    while (1) {
	$p = shift @params;
	last unless $p=~ /^-/;

	if ($p eq '-J') {
	    @judges = ();
	} elsif ($p eq '-j') {
	    my $judge = double_shift(\@params);
	    push @judges, $judge;
	} elsif ($p eq '-p' || $p eq '-percent') {
	    $percent = double_shift(\@params);
	    show_help() unless $percent > 0 && $percent < 100;
	} elsif ($p eq '-a' || $p eq '-absolute') {
	    $absolute = double_shift(\@params);
	    show_help() unless $absolute > 0;
	} elsif ($p eq '-h' || $p eq '-help' || $p eq '-?') {
	    show_help();
	}
    }

    if ($p) {
	$sentjudge_arg = $p;
    } else {
	print STDERR "\nMust provide Sentjudge argument.\n";
	show_help();
    }

    if (@params) {
	print STDERR "\nToo many arguments provided.\n";
    }

}

sub double_shift {
    my $array = $_[0];
    if (@$array == () ||  $$array[0] =~ /^-/) {
        show_help();
    }
    return shift @$array;
}

sub show_help {

    print STDERR "\n";
    print STDERR "Usage:\n";
    print STDERR "\n";
    print STDERR "./sentjudge-to-extract.pl [options] <sentjudge_file>\n";
    print STDERR "\n";
    print STDERR "Available options are:\n";
    print STDERR "\n";
    print STDERR "  -J   (all judges)\n";
    print STDERR "  -judge, -j\n";
    print STDERR "  -percent, -p\n";
    print STDERR "  -absolute, -a\n";
    print STDERR "  -help, -?\n";
    print STDERR "\n";
    print STDERR "There is no documentation for this script.\n";  
    print STDERR "You are officially on your own.  Enjoy!\n";
    print STDERR "\n";
    
    exit(0);
}
