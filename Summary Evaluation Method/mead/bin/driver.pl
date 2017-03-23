#!/usr/bin/perl

use strict;

use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/../lib/arch";

###############################################################################
#
#	Used modules
#
###############################################################################

use POSIX qw(ceil floor);

use FileHandle;
use IPC::Open2;

use XML::Parser;
#use XML::Checker::Parser;
use XML::Writer;

use MEAD::MEAD;
use MEAD::SentFeature;
use MEAD::Extract;

###############################################################################
#
#	Package Variables
#
###############################################################################

# for parsing
my $curr_did;
my $curr_sno;

###############################################################################
#
#	Read Config file
#
###############################################################################

my $lang;
my $cluster_path;
my $cluster_name;
my $datadir;

my $feature_column_base_directory;
my %feature_names;

my $classifier_command_line;
my $system;
my $run;

my %recompute = ();

my $reranker_command_line;

my $compression_basis;
my $compression_percent;
my $compression_absolute;

#my $config_parser = new XML::Checker::Parser(Handlers => {
#		'Start' => \&config_handle_start});

# Validate and parse
#eval { 
#    local $XML::Checker::FAIL = \&my_fail;
#    $config_parser->parse(\*STDIN); 
#};

# Die if we get an error
#sub my_fail {
#    my $code = shift;
#    die XML::Checker::error_string($code, @_) if $code < 200;
#    XML::Checker::print_error($code, @_);
#}
#if ($@) {
#    die "Malformed mead-config: $@";
#}

my $config_parser = new XML::Parser(Handlers => {
		'Start' => \&config_handle_start});
$config_parser->parse(\*STDIN);


sub config_handle_start {
    shift;
    my $element_name = shift;
    my %atts = @_;
    
    if ($element_name eq 'MEAD-CONFIG') {
	$lang = $atts{'LANG'};
	$cluster_path = $atts{'CLUSTER-PATH'};
	
	$cluster_name = $atts{'TARGET'} or die "Config file top-level element does not specify 'TARGET' attribute\n";
	$datadir = $atts{'DOC-DIRECTORY'} || $cluster_path;
    } if ($element_name eq 'FEATURE-SET') {
	$feature_column_base_directory = $atts{'BASE-DIRECTORY'};
    } elsif ($element_name eq 'FEATURE') {
	$feature_names{$atts{'NAME'}} = $atts{'SCRIPT'} || die "'FEATURE' element does not specify 'NAME' attribute\n";
        if ($atts{'RECOMPUTE'} eq "true") {
            $recompute{$atts{'NAME'}} = 1;
        } 
    } elsif ($element_name eq 'CLASSIFIER') {
	$classifier_command_line = $atts{'COMMAND-LINE'} || die "'CLASSIFIER' element does not specifiy 'COMMAND-LINE' attribute\n";
	$system = $atts{'SYSTEM'};
	$run = $atts{'RUN'};
    } elsif ($element_name eq 'RERANKER') {
	$reranker_command_line = $atts{'COMMAND-LINE'} . " " . $datadir; 
    } elsif ($element_name eq 'COMPRESSION') {
	$compression_basis = $atts{'BASIS'} || die "'COMPRESSION' element does not specify 'BASIS' attribute\n";
	$compression_percent = $atts{'PERCENT'};
	$compression_absolute = $atts{'ABSOLUTE'};
	
	unless ($compression_percent || $compression_absolute) {
	    die "'COMPRESSION' element does not specify compression\n";
	}
    }
}

## Cluster information
my $cluster_file = "$cluster_name.cluster";
$cluster_path =~ s/\/\s*$//;
my $full_cluster_path = "$cluster_path/$cluster_file";

###############################################################################
#
#	Build feature merging command
#
###############################################################################

my %combined_features = ();

foreach my $fn (keys %feature_names) {

    my $feature_filename = 
	"$feature_column_base_directory/$cluster_name.$fn.sentfeature";

    # Deleting a preexisting feature file if necessary
    if (-e $feature_filename and $recompute{$fn}) {
        system "rm $feature_filename";
    }

    unless (-e $feature_filename) {
	my $feature_command = "echo $full_cluster_path | ";
	$feature_command .= "$feature_names{$fn} $datadir > ";
	$feature_command .= "$feature_filename";

	my $ret = system $feature_command;

	if ($ret) {
	    Debug("Feature Calculation returned $ret",3,"Driver");
	    system "rm $feature_filename";
	    exit(3);
	}
    }

    my %feature = read_sentfeature($feature_filename);
    
    combine_sentfeatures(\%combined_features, \%feature);
}

###############################################################################
#
#	Call Classifier
#
###############################################################################

my $classreader = new FileHandle;
my $classwriter = new FileHandle;

open2($classreader, $classwriter, "$classifier_command_line");

Debug("Begin Classifier",1,"Main");

write_sentfeature(\%combined_features, $classwriter);
$classwriter->close();

Debug("Output written to Classifier",1,"Main");

my $compression_string;

if ($compression_absolute) {
    $compression_string = "<COMPRESSION ABSOLUTE='$compression_absolute' ".
	"BASIS='$compression_basis' />";
} else {
    $compression_string = "<COMPRESSION PERCENT='$compression_percent' ".
	"BASIS='$compression_basis'/>";
}

unless (open CLUSTER_FILE, $full_cluster_path) {
    Debug("Can't open cluster: $full_cluster_path",3,"Main");
    exit(1);
}

my $cluster_string = "";
while (<CLUSTER_FILE>) {
    if (!(/(\?xml|\!DOCTYPE)/)) { 
	$cluster_string .= $_; 
    }
}

## Sentjudge information
my $sentjudge_string = "";
while (<$classreader>) {
    if (!(/(\?xml|\!DOCTYPE)/)) { 
	$sentjudge_string .= $_; 
    }
}

Debug("Done Classifier",1,"Main");

###############################################################################
#
#       Build Reranker info for the reranker
#
###############################################################################

Debug("Begin Reranker",1,"Main");

## Print the reranker info into the reranker
my $rankreader = new FileHandle;
my $rankwriter = new FileHandle;

open2($rankreader, $rankwriter, "$reranker_command_line");

print $rankwriter "<?xml version='1.0'?>
<RERANKER-INFO>
$compression_string
$cluster_string
$sentjudge_string
</RERANKER-INFO>\n";

$rankwriter->close();

my @all_sents = ();
my $total_sents_in_summary;

my $sentjudge_parser = new XML::Parser(Handlers => {
    Start => \&read_sentjudge_handle_start});
$sentjudge_parser->parse($rankreader);

$rankreader->close();

Debug("Done Reranker",1,"Main");

###############################################################################
#
#	Choose Sentences
#
###############################################################################

Debug("Begin Chooser",1,"Main");

my @sorted_sents =
    sort { $$b{'FinalScore'} <=> $$a{'FinalScore'} } @all_sents;

#my @final_sents = @sorted_sents[1 .. $total_sents_in_summary];
my @final_sents = @sorted_sents[0 .. ($total_sents_in_summary-1)];

Debug("End Chooser",1,"Main");

###############################################################################
#
#	Write out the sentences in @final_sents
#
###############################################################################

Debug("Write out final sentences",1,"Main");

write_extract(\@final_sents,
	      "QID" => $cluster_name,
	      "LANG" => $lang,
	      "COMPRESSION" => $compression_percent || $compression_absolute,
	      "SYSTEM" => $system,
	      "RUN" => $run);

Debug("Done",1,"Main");

###############################################################################
#
#	Utilities
#
###############################################################################

sub read_sentjudge_handle_start {
    shift; #don't care about Expat
    my $element_name = shift;
    my %atts = @_;

    if ($element_name eq 'SENT-JUDGE') {
	$total_sents_in_summary = $atts{'SENTS-FOR-SUMMARY'};
	Debug("Total sents to put in summary : $total_sents_in_summary",
	      1,"ReadScores");
    } elsif ($element_name eq 'S') {		
	$curr_did = $atts{'DID'};
	$curr_did =~ s/\s//;
	$curr_sno = $atts{'SNO'};
    } elsif ($element_name eq 'JUDGE') {	
	my $sentref = {};

	$$sentref{'DID'} = $curr_did;
	$$sentref{'SNO'} = $curr_sno;
	$$sentref{'FinalScore'} = $atts{'UTIL'};
	
	push @all_sents, $sentref;
	
	Debug("Adding sentence w/score $$sentref{'FinalScore'} to all_sents", 
	      1, "ReadScores");
    }
}
