#!/usr/bin/perl

# TODO: AJW
# MEAD::Config::read_meadconfig(\*IN);
# MEAD::Config::write_meadrc{\%args, \*OUT)
#

#
# Usage:
#
#   ./mead.pl [options] clustername
#
#   for a description of the options, type 
#
#   ./mead.pl -help
#

use strict;

use File::Spec;
use FileHandle;
use IPC::Open2;

use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/../lib/arch";

use MEAD::MEAD;
use MEAD::Config;
use MEAD::Cluster;
use MEAD::Extract;
use MEAD::SentFeature;
use MEAD::SentJudge;

use Essence::Centroid;

#
# Constants.
#

my $MEADDIR = "$FindBin::Bin/..";
my $BINDIR = $FindBin::Bin;
my $SCRIPTSDIR = "$BINDIR/feature-scripts";
my $DATADIR = "$MEADDIR/data";

my $MEADORIG = "MEADORIG";
my $RANDOM = "RANDOM";
my $LEADBASED = "LEADBASED";
my $USER = "USER";

my $DEFAULT_CLASSIFIER = 
    "$BINDIR/default-classifier.pl Centroid 1 Position 1 Length 9";
my $RANDOM_CLASSIFIER = 
    "$BINDIR/random-classifier.pl Length 9";
my $LEADBASED_CLASSIFIER =
    "$BINDIR/leadbased-classifier.pl Length 9";

my $DEFAULT_RERANKER = 
    "$BINDIR/default-reranker.pl MEAD-cosine .7 enidf";
my $IDENTITY_RERANKER =
    "$BINDIR/identity-reranker.pl";

my $DEFAULT_CENTROID = "$SCRIPTSDIR/Centroid.pl enidf ENG";
my $DEFAULT_LENGTH = "$SCRIPTSDIR/Length.pl";
my $DEFAULT_POSITION = "$SCRIPTSDIR/Position.pl";

#
# Variables.
#

# 0, 1, or 2.
my $verbose;

# the cluster to process.
my $cluster;

my @data_path;
my $data_dir;

my $cluster_name;
my $cluster_dir;
my $docsent_dir;
my $docsent_subdir;
my $feature_dir;
my $feature_subdir;

my $lang;

# A hash of features which will be recomputed
my %recompute;

my $feature_cache_policy;

my %features;
my $classifier;
my $reranker;

# a system just gives a name to the configuration (classifier, reranker,
# features, etc) UNLESS it is one of the special systems: RANDOM and
# LEADBASED.
my $system;
my $run = localtime;

my $compression_basis;
my $compression_absolute;
my $compression_percent;

# this may be a file if only one input is specified (or multiple docsents)
# but must be a directory if multiple clusters/directories is specified.
# if relative, will assume relative to each cluster directory.
my $output_location;

# this is either summary or extract.
my $output_mode;

#
# Stuff to get to the user's rc file in his home directory.
# Alternately, the user can specify a different rc file on the 
# command line using -rc.
# Whichever file we get information from, it will be stored in
# %user_meadrc.
#

my $user_dir;
my $user_rcfile;
my %user_meadrc;

#
# The system's rc information is in $MEADDIR/.meadrc
# It is read into %system_meadrc
#

my $system_rcfile;
my %system_meadrc;

#
# Execution Code
#
{
    &process_command_line(@ARGV);

    # get the contents of $MEADDIR/.meadrc
    &get_system_meadrc();

    # we must do this after we parse the command line, because the user
    # can specify an rc file on the command line.
    &get_user_meadrc();

    # resolve the command line options, and the user/system meadrc files.
    &resolve_options();

    # actually do the summarization (or other task) for the cluster.
    process_cluster($cluster);    
}

sub process_cluster {

    my $cluster_arg = shift;

    # this sets $cluster_name, $cluster_dir, $docsent_dir, $feature_dir,
    # if needed and makes sure that they all exist, etc.
    get_cluster_specs($cluster_arg);

    print STDERR "Cluster: $cluster_dir/$cluster_name.cluster\n";

    my %options = (target => $cluster_name,
                   lang => $lang,
                   cluster_dir => $cluster_dir,
                   docsent_dir => $docsent_dir,
                   feature_dir => $feature_dir,
                   features => \%features,
                   recompute => \%recompute,
                   feature_cache_policy => $feature_cache_policy,
                   classifier => $classifier,
                   system => $system,
                   run => $run,
                   reranker => $reranker,
                   compression_basis => $compression_basis,
                   compression_absolute => $compression_absolute,
                   compression_percent => $compression_percent);

    # print out the extract/summary
    if ($output_mode eq "extract") {
	my $extract = run_mead(%options);
	write_extract($extract, 
		      OUTPUT => $output_location,
		      "QID" => $cluster_name,
		      "LANG" => $lang,
		      "COMPRESSION" => 
		      $compression_percent || $compression_absolute,
		      "SYSTEM" => $system,
		      "RUN" => $run);
    } elsif ($output_mode eq "summary") {
	my $extract = run_mead(%options);
	my $cluster_file = 
	    File::Spec->catfile($cluster_dir, "$cluster_name.cluster");
	my $cluster = read_cluster($cluster_file, $docsent_dir);
	my $summary = extract_to_summary($extract, $cluster);
	write_summary($summary, $output_location);
    } elsif ($output_mode eq "meadconfig") {
	write_meadconfig(%options, OUTPUT => $output_location);
    } elsif ($output_mode eq "centroid") {
	my $cluster_file = 
	    File::Spec->catfile($cluster_dir, "$cluster_name.cluster");
	my $cluster = read_cluster($cluster_file, $docsent_dir);
	my $centroid = compute_centroid($cluster);
	write_centroid($centroid, OUTPUT => $output_location);
    } elsif ($output_mode eq "scores") {
        # NOTE: get_sentfeatures, classify_sentences, and 
        # write_features_and_scores are all methods in this file.
	my $sentfeatures = get_sentfeatures(\%features,
					    $cluster_name,
					    $cluster_dir,
					    $feature_dir, 
					    $docsent_dir);
	my $sentjudge = classify_sentences($sentfeatures, $classifier);
	write_sentfeatures_and_scores($sentfeatures, $sentjudge);
    } else {
	die "Unknown output mode: '$output_mode'\n";
    }

}

sub run_mead {

    my %options = @_;

    my $reader = FileHandle->new();
    my $writer = FileHandle->new();
    
    unless ( open2($reader, $writer, "$FindBin::Bin/driver.pl") ) {
        die "Unable to run MEAD.\n";
    }

    write_meadconfig(%options, OUTPUT => $writer);
    $writer->close();

    my $extract = read_extract($reader);
    $reader->close();

    return $extract;
}

sub get_sentfeatures {
    my $features = shift; # a hashref
    my $cluster_name = shift;
    my $cluster_dir = shift;
    my $feature_dir = shift;
    my $docsent_dir = shift;

    my $cluster_file = "$cluster_name.cluster";
    my $full_cluster_path = "$cluster_dir/$cluster_file";

    my %combined_features = ();

    foreach my $fn (keys %$features) {

	my $feature_filename =
	    "$feature_dir/$cluster_name.$fn.sentfeature";
	my $feature_script = $$features{$fn};

	unless (-e $feature_filename) {
	    my $feature_command = "echo $full_cluster_path | ";
	    $feature_command .= "$feature_script $docsent_dir > ";
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

    return \%combined_features;
}

sub classify_sentences {
    my $combined_features = shift;
    my $classifier_command_line = shift;

    my $classreader = new FileHandle;
    my $classwriter = new FileHandle;

    open2($classreader, $classwriter, $classifier_command_line);

    write_sentfeature($combined_features, $classwriter);
    $classwriter->close();

    my %sentjudge = read_sentjudge($classreader);
    
    return \%sentjudge;
}

sub write_sentfeatures_and_scores {
    my $sentfeatures = shift;
    my $sentjudge = shift;

    # get the feature names to print.
    my @dids = keys %$sentfeatures;
    my $did1 = $dids[0];
    my $sentref = $$sentfeatures{$did1}[1];
    my @feature_names = keys %$sentref;

    # get the names of the judges.
    @dids = keys %$sentjudge;
    $did1 = $dids[0];
    $sentref = $$sentjudge{$did1}[1];
    my @real_judge_names = keys %$sentref;
    my @print_judge_names = ();

    # if there is only one judge named, call
    # that judge "Score";
    if (@real_judge_names == 1) {
        @print_judge_names = qw(Score);
    } else {
        @print_judge_names = @real_judge_names;
    }

    # compute the DID format string.
    my $longest = 0;
    foreach my $did (@dids) {
        if (length($did) > $longest) {
            $longest = length($did);
	}
    }
    $longest += 5;
    
    my $did_format = '%-' . "$longest.$longest" . 's';

    # print the feature names and judge names.
    printf $did_format, 'DID';
    printf "SNO   ";

    foreach my $fn (@feature_names) {
        printf " %11.11s", $fn;
    }
    foreach my $jn (@print_judge_names) {
        printf " %11.11s", $jn;
    }
    print "\n";

    foreach my $did (keys %$sentfeatures) {

        my $fdocref = $$sentfeatures{$did};
        my $jdocref = $$sentjudge{$did};
        
        for (my $sno = 1; $sno < @$fdocref; $sno++) {

	    my $fsentref = $$fdocref[$sno];
	    my $jsentref = $$jdocref[$sno];

	    printf $did_format, $did;
            printf "%-6.6s", $sno;

            foreach my $fn (@feature_names) {
                printf " %11.6f", $$fsentref{$fn};
	    }

            foreach my $jn (@real_judge_names) {
                printf " %11.6f", $$jsentref{$jn};
	    }

            print "\n";
	}
    }
}

#
# returns  (<cluster_name>, <cluster_dir>, <docsent_dir>, <feature_dir>)
# dies if can't properly locate the cluster.
#
# If the cluster_dir is given, either as a command line argument or
# in a .meardc file, we look for something like cluster_arg.cluster
# in the given cluster_dir.
#
# Else, we search each element of data_path for 
# data_path_element/cluster_name/cluster_name.cluster.
#
sub get_cluster_specs {

    my $cluster_arg = shift;

    # remove a possible trailing slash.
    $cluster_arg =~ s/\/^//;

    # the $cluster_name is the last directory.
    my @dirs = File::Spec->splitdir($cluster_arg);
    $cluster_name = pop @dirs;

    # using rel2abs instead of catdir will just check 
    # absolute cluster_arg's several times, which is okay.
    unless ($cluster_dir) {
	foreach my $dir (@data_path) {
	    my $pot_cluster_dir = 
	      File::Spec->rel2abs($cluster_arg, $dir);
	    
	    # there must be a directory.
	    next unless -d $pot_cluster_dir;
	    
	    my $pot_cluster_file = 
	      File::Spec->catfile($pot_cluster_dir, "$cluster_name.cluster");

	    # the cluster file must also exist.
	    next unless -e $pot_cluster_file;
	    
	    $cluster_dir = $pot_cluster_dir;
	}
    }

    unless ($cluster_dir) {
	die "Failed to locate cluster '$cluster_name'\n";
    }

    $cluster_dir = File::Spec->rel2abs($cluster_dir);
    unless (-d $cluster_dir) {
	die "Failed to find cluster '$cluster_name' in data path\n"; 
    }

    my $cluster_file = 
      File::Spec->catfile($cluster_dir, "$cluster_name.cluster");
    unless (-e $cluster_file) {
	die "Couldn't find cluster file '$cluster_file' in cluster dir.\n";
    }

    $docsent_dir = "$cluster_dir/$docsent_subdir" unless $docsent_dir;
    $docsent_dir = File::Spec->rel2abs($docsent_dir);
    unless (-d $docsent_dir) {
	die "The docsent directory doesn't exist: '$docsent_dir'\n";
    }

    # build the feature_dir and mkdir it if necessary.
    $feature_dir = "$cluster_dir/$feature_subdir" unless $feature_dir;
    $feature_dir = File::Spec->rel2abs($feature_dir);
    if (! (-d $feature_dir)) {
	print STDERR "Creating feature directory: $feature_dir\n";
	mkdir $feature_dir or 
	    die "Unable to create feature directory: $feature_dir\n";
    } 
}

sub get_system_meadrc {
    
    $system_rcfile = File::Spec->catfile($MEADDIR, ".meadrc");

    if (-e $system_rcfile) {
	print STDERR "Using system rc-file: $system_rcfile\n";
    } else {
	print STDERR "Warning: Can't find system rc-file\n";
    }

    %system_meadrc = read_meadrc($system_rcfile);

}

sub get_user_meadrc {

    unless ($user_rcfile) {
	my $user_uid = $<;
	my @user_info = getpwuid($user_uid);

	$user_dir = $user_info[7];
	$user_rcfile = File::Spec->catfile($user_dir, ".meadrc");
    }

    if (-e $user_rcfile) {
	print STDERR "Using user rc-file: $user_rcfile\n";
    } else {
	print STDERR "Warning: Can't find user rc-file\n";
    }

    %user_meadrc = read_meadrc($user_rcfile);

}


#
# Combines all the options provided in the 
#
sub resolve_options {

    #
    # data_path:
    #
    # the current directory is checked first.
    # anything defined in the user's rc file is checked next,
    # anything in the system's rc file is checked next,
    # then the user's home directory, 
    # the system data directory, 
    #
    unshift @data_path, $DATADIR;
    unshift @data_path, File::Spec->catdir($user_dir, "mead/data");
    
    if ($system_meadrc{'data_path'}) {
	my @dirs = split /:/, $system_meadrc{'data_path'};
	unshift @data_path, @dirs;
    }

    if ($user_meadrc{'data_path'}) {
	my @dirs = split /:/, $user_meadrc{'data_path'};
	unshift @data_path, @dirs;
    }

    unshift @data_path, ".";

    #
    # obviously, target, cluster_dir, docsent_dir, and feature_dir
    # can differ between cluster.  So we do these for each cluster
    # in "get cluster specs".
    #
    # Also, lang is cluster-dependant, but since we only do English
    # anyway (at least for the most part), this is okay for now.
    
    # TODO: this is a hack.
    #       get the language from each cluster.
    resolve_option(\$lang, "lang", "ENG");

    # 
    # The user can provide docsent_dir and feature_dir 
    # arguments...
    #
    resolve_option(\$docsent_dir, "docsent_dir");
    resolve_option(\$feature_dir, "feature_dir");

    resolve_option(\$docsent_subdir, "docsent_subdir", "docsent");
    resolve_option(\$feature_subdir, "feature_subdir", "feature");

    #
    # System, Classifier, and Reranker.
    #
    resolve_option(\$system, "system");
    resolve_option(\$classifier, "classifier");
    resolve_option(\$reranker, "reranker");    

    #
    # Features.
    #
    if (ref $system_meadrc{'features'} eq "HASH") {
	my %rcfeatures = %{ $system_meadrc{'features'} };
	foreach my $fname (keys %rcfeatures) {
	    $features{$fname} = $rcfeatures{$fname};
	}
    }
    
    if (ref $user_meadrc{'features'} eq "HASH") {
	my %rcfeatures = %{ $user_meadrc{'features'} };
	foreach my $fname (keys %rcfeatures) {
	    $features{$fname} = $rcfeatures{$fname};
	}
    }

    #
    # Features to be recomputed.
    #
    if (ref $system_meadrc{'recompute'} eq "HASH") {
        %recompute = (%recompute, %{ $system_meadrc{'recompute'} });
    }
    if (ref $user_meadrc{'recompute'} eq "HASH") {
        %recompute = (%recompute, %{ $user_meadrc{'recompute'} });
    }

    #
    # Cache policy
    #
    resolve_option(\$feature_cache_policy, "feature_cache_policy", "keep");
    unless ($feature_cache_policy eq "delete" 
            || $feature_cache_policy eq "keep") {
	die "feature_cache_policy must be 'delete' or 'keep'";
    }
 

    #
    # System, revisited.
    #

    # give the system a name if nothing has been changes.
    unless ($system || keys %features || $classifier || $reranker) {
	$system = $MEADORIG;
    }

    # fill in the fields for the special systems.
    if ($system eq $RANDOM) {

	# TODO: get the length feature from the right spot.
	$features{'Length'} = $DEFAULT_LENGTH;
        
        $classifier = $RANDOM_CLASSIFIER;
        $reranker = $IDENTITY_RERANKER;
        
    } elsif ($system eq $LEADBASED) {
        
	$features{'Length'} = $DEFAULT_LENGTH;
        
        $classifier = $LEADBASED_CLASSIFIER;
        $reranker = $IDENTITY_RERANKER;
        
    } else {

	$features{'Length'} = $DEFAULT_LENGTH unless $features{'Length'};
	$features{'Position'} = $DEFAULT_POSITION unless $features{'Position'};
	$features{'Centroid'} = $DEFAULT_CENTROID unless $features{'Centroid'};

	$classifier = $DEFAULT_CLASSIFIER unless $classifier;
	$reranker = $DEFAULT_RERANKER unless $reranker;

    }

    #
    # Compression basis.
    #
    resolve_option(\$compression_basis, "compression_basis", "sentences");
    unless ($compression_basis eq "sentences" 
	    || $compression_basis eq "words") {
	die "Compression basis must be 'sentences' or 'words'";
    }

    #
    # Compression percent v. absolute is a bit trickier.
    #
    if ($compression_percent || $compression_absolute) {
	# we have one or the other...
    } elsif ($user_meadrc{'compression_percent'} ||
	     $user_meadrc{'compression_absolute'}) {
	$compression_percent = $user_meadrc{'compression_percent'};
	$compression_absolute = $user_meadrc{'compression_absolute'};
    } elsif ($system_meadrc{'compression_percent'} ||
	     $system_meadrc{'compression_absolute'}) {
        $compression_percent = $system_meadrc{'compression_percent'};
        $compression_absolute = $system_meadrc{'compression_absolute'};
    } else {
	$compression_percent = 20;
    }

    # by here, we're assured that one or the other is defined.
    if ($compression_absolute) {
	undef $compression_percent;
    } else {
	undef $compression_absolute;
    }

    #
    # The following options have nothing to do with the actual running
    # of MEAD.
    #

    # Output Mode: extract or summary.
    resolve_option(\$output_mode, "output_mode", "summary");
    unless( $output_mode eq "extract" ||
	    $output_mode eq "summary" ||
	    $output_mode eq "meadconfig" ||
	    $output_mode eq "centroid" ||
	    $output_mode eq "scores") {
	die "Output mode is not one of extract, summary, meadconfig, or centroid.\n";
    }

    # Output Location: file to write the output to.
    resolve_option(\$output_location, "output_location");
}

sub resolve_option {
    my ($var_ref, $var_name, $default) = @_;

    if ($$var_ref) {
	# fall through.
    } elsif ($user_meadrc{$var_name}) {
	$$var_ref = $user_meadrc{$var_name};
    } elsif ($system_meadrc{$var_name}) {
	$$var_ref = $system_meadrc{$var_name};
    } elsif ($default) {
	$$var_ref = $default;
    }
}

sub process_command_line {

    my @params = @_;
    my $p;

    while (1) {

	$p = shift @params;
	last unless $p =~ /^-/;

        if ($p =~ /^-v(erbose)?$/) {
	    $verbose = 2;
	} elsif ($p =~ /^-q(uiet)?$/) {
	    $verbose = 0;

        } elsif ($p =~ /^-l(ang)?$/) {
	    $lang = double_shift(\@params);

        } elsif ($p =~ /^-c(lassifier)?$/) {
	    $classifier = double_shift(\@params);
        } elsif ($p =~ /^-r(eranker)?$/) {
	    $reranker = double_shift(\@params);

        } elsif ($p =~ /^-system?$/) {
	    $system = double_shift(\@params);
        } elsif ($p =~ /^-RANDOM$/) {
	    $system = $RANDOM;
        } elsif ($p =~ /^-LEADBASED$/) {
	    $system = $LEADBASED;

        } elsif ($p =~ /^-f(eature)?$/) {
            my $name = double_shift(\@params);
            my $param;
            unless ($param = shift @params) { &show_help(); exit(1); }

            if ($param eq "-recompute") {
                $recompute{$name} = 1;
                $features{$name} = double_shift(\@params);
            } else {
                $features{$name} = $param;
            }

        } elsif ($p =~ /^-feature_cache_policy$/ or $p =~ /^-fcp$/) {
            $feature_cache_policy = double_shift(\@params);

	} elsif ($p =~ /^-(compression_)?b(asis)?$/) {
	    $compression_basis = double_shift(\@params);
        } elsif ($p =~ /^-w(ords)?$/) {
            $compression_basis = "words";
        } elsif ($p =~ /^-s(entences)?$/) {
            $compression_basis = "sentences";
       
        } elsif ($p =~ /^-(compression_)?p(ercent)?$/) {
            $compression_percent = double_shift(\@params);
        } elsif ($p =~ /^-(compression_)?a(bsolute)?$/) {
            $compression_absolute = double_shift(\@params);

	} elsif ($p =~ /^-data_path$/) {
	    my $path = double_shift(\@params);
	    my @dirs = split /:/, $path;
	    unshift @data_path, @dirs;

	} elsif ($p =~ /^-output_mode$/) {
	    $output_mode = double_shift(\@params);
        } elsif ($p =~ /^-summary$/) {
	    $output_mode = "summary";
        } elsif ($p =~ /^-extract$/) {
	    $output_mode = "extract";
	} elsif ($p =~ /^-meadconfig$/) {
	    $output_mode = "meadconfig";
	} elsif ($p =~ /^-centroid$/) {
	    $output_mode = "centroid";
	} elsif ($p =~ /^-scores$/) {
	    $output_mode = "scores";

	} elsif ($p =~ /^-cluster_dir$/) {
	    $cluster_dir = double_shift(\@params);
	
	} elsif ($p =~ /^-docsent_dir$/) {
	    $docsent_dir = double_shift(\@params);
	} elsif ($p =~ /^-docsent_subdir$/) {
	    $docsent_subdir = double_shift(\@params);

	} elsif ($p =~ /^-feature_dir$/) {
	    $feature_dir = double_shift(\@params);
	} elsif ($p =~ /^-feature_subdir$/) {
	    $feature_subdir = double_shift(\@params);

	} elsif ($p =~ /^-o(utput)?$/) {
	    $output_location = double_shift(\@params);

        # this is somewhat special, as the user can tell mead.pl 
	# where to look for a .rc file.
        } elsif ($p =~ /^-(mead)?rc$/) {
	    $user_rcfile = double_shift(\@params);

	} elsif ($p =~ /^-h(elp)?$/ || $p =~ /^-\?$/) {
	    &show_help();
	    exit(0);

	} else {
	    die "Unknown option given: $p\n";
	}
    }

    if (! defined($p) || length $p == 0) {
	die "Must provide a cluster or docsent argument.\n";
    }

    # save the cluster.
    $cluster = $p;

    # check that no additional arguments are given.
    if (@params) {
	die "Too many arguments given.\n";
    }

}

sub double_shift {
    my $array = $_[0];
    if (@$array == () ||  $$array[0] =~ /^-/) {
        show_help();
        exit(1);
    }
    return shift @$array;
}

sub show_help {

print <<EOHELP
Usage:

./mead.pl [options] <cluster_name>

Available options are:

 -summary
 -extract
 -meadconfig
 -centroid
 -scores
 -output_mode mode  (summary|extract|meadconfig|centroid|scores)
 -sentences, -s
 -words, -s
 -basis basis (words|sentences)
 -percent, -p
 -absolute, -a
 -system name  (including RANDOM and LEADBASED)
 -RANDOM
 -LEADBASED
 -feature name [-recompute] commandline
 -feature_cache_policy (keep|delete), -fcp (keep|delete)
 -classifier commandline
 -reranker commandline
 -lang     (ENG|CHIN)
 -data_path path
 -cluster_dir dir
 -docsent_dir dir
 -feature_dir dir
 -docsent_subdir subdir
 -feature_subdir subdir
 -meadrc file, -rc file
 -help

For the semantics and interpretation of these options, please
consult the MEAD documentation.

EOHELP
}











