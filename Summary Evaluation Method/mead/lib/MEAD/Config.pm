package MEAD::Config;

require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw(write_meadconfig

	     read_meadrc);

use strict;

use FindBin;

use MEAD::MEAD;

#
# TODO: AJW 9/17
# read_meadconfig
# write_meadrc
#

sub write_meadconfig {

    my %opts = @_;

    # Get the particular options.
    my $target = $opts{'target'};
    my $lang = $opts{'lang'};
    my $cluster_dir = $opts{'cluster_dir'};
    my $docsent_dir = $opts{'docsent_dir'};

    my $feature_dir = $opts{'feature_dir'};
    my %features;
    if ( $opts{'features'} ) {
	%features = %{ $opts{'features'} };
    }

    my %recompute;
    if ( $opts{'recompute'} ) {
        %recompute = %{ $opts{'recompute'} };
    }

    my $feature_cache_policy = $opts{'feature_cache_policy'};

    my $system = $opts{'system'};
    my $run = $opts{'run'};
    
    my $classifier = $opts{'classifier'};
    my $reranker = $opts{'reranker'};

    my $compression_basis = $opts{'compression_basis'};
    my $compression_absolute = $opts{'compression_absolute'};
    my $compression_percent = $opts{'compression_percent'};

    my $output = $opts{'OUTPUT'} || \*STDOUT;
    unless (ref $output) {
	open TEMP, ">$output" or
	    die "Unable to open '$output' for writing meadconfig.\n";
	$output = \*TEMP;
    }

    # Now write the XML.
    my $writer = new XML::Writer(DATA_MODE => 1, OUTPUT => $output);
    
    $writer->xmlDecl();

    my $dtd_path = "$FindBin::Bin/../dtd/mead-config.dtd";
    $writer->doctype("MEAD-CONFIG", undef, $dtd_path);
    
    $writer->startTag("MEAD-CONFIG", 
		      "LANG" => $lang, 
		      "TARGET" => $target,
		      "CLUSTER-PATH" => $cluster_dir,
		      "DOC-DIRECTORY" => $docsent_dir);
    
    $writer->startTag("FEATURE-SET", 
		      "BASE-DIRECTORY" => $feature_dir);
    
    foreach my $feature_name (keys %features) {
        my %attrs = ( "NAME" => $feature_name, 
                      "SCRIPT" => $features{$feature_name});
        if ($feature_cache_policy eq "delete" or $recompute{$feature_name}) {
            $attrs{"RECOMPUTE"} = "true";
        }
        $writer->emptyTag("FEATURE", %attrs);
    }
    
    $writer->endTag();
    
    $writer->emptyTag("CLASSIFIER", 
		      "COMMAND-LINE" => $classifier,
		      "SYSTEM" => $system,
		      "RUN" => $run);
    
    $writer->emptyTag("RERANKER", 
		      "COMMAND-LINE" => $reranker);
    
    if ($compression_absolute) {
	$writer->emptyTag("COMPRESSION",
			  "BASIS" => $compression_basis,
			  "ABSOLUTE" => $compression_absolute);
    } else {
	$writer->emptyTag("COMPRESSION",
			  "BASIS" => $compression_basis, 
			  "PERCENT" => $compression_percent);
    }
    
    $writer->endTag();
    
    $writer->end();
    
}

sub read_meadrc {

    my $rcfile = shift;

    my %rc = ();
    $rc{'features'} = {};
    
    $rc{'recompute'} = {};

    unless (open RC, $rcfile) {
	Debug("Unable to open $rcfile", 2, "MEAD::Config::read_meadrc");
	return undef;
    }

    my $l;
    while ($l = <RC>) {

	chomp $l;

	next if $l =~ /^#/;
	next if $l =~ /^\s*$/;

	# this is for features only.
	#if ($l =~ /^\s*feature\s+(\S+)\s+(.+)$/) {
	if ($l =~ /^\s*feature\s+(\S+)\s+(-recompute\s+)?(.+)$/) {

	    my $featuresref = $rc{'features'};
	    my $recomputeref = $rc{'recompute'};
	    #$$featuresref{$1} = $2;
	    $$featuresref{$1} = $3;

            if ($2) {
                # This feature should be on the recompute list
                $$recomputeref{$1} = 1;
            }

	# this is the general case.
	} elsif ($l =~ /^\s*(\w+)\s+(\S.*)$/) {
	    $rc{$1} = $2;
	}

    }

    return %rc;
}

