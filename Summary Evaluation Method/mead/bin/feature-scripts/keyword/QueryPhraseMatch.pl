#!/usr/bin/perl -w

#########################################################################
#
# usage:
#   echo cluster_filename | ./QueryPhraseMatch\
#        [-q option] query_filename datadir
#
# option: specify which part of query is used to compute word overlap
#    -q: "t", "title", "n", "narrative", "d", "description", "a", "all"
#
#########################################################################

use strict;

use Getopt::Long;

use FindBin;
use lib "$FindBin::Bin/../../../lib/", "$FindBin::Bin/../../../lib/arch/";

use MEAD::Query;
use MEAD::SentFeature;
use MEAD::Evaluation;

use Essence::IDF;
use Essence::Text;

use Lingua::Stem;

# get the option
my $q;
GetOptions ("q=s"  => \$q);

my $option = "all";
if ($q) {
    $q =~ tr/[A-Z]/[a-z]/;
    if (($q eq "t") or ($q eq "title")) {
	$option = "title";
    } elsif (($q eq "n") or ($q eq "narrative")) {
	$option = "narrative";
    } elsif (($q eq "k") or ($q eq "keywords")) {
	$option = "keywords";
    } elsif (($q eq "d") or ($q eq "description")) {
	$option = "description";
    } elsif (($q ne "a") and ($q ne "all")) {
	die "-q can only take t/title, n/narrative, d/description.\n";
    }
}

my $query_filename = shift;
my $datadir = shift;

unless ($query_filename && $datadir) {
    die "Must provide both query_filename and datadir.\n";
}

my $query = read_query($query_filename);
my $query_title = $$query{'TITLE'};
my $query_narrative = $$query{'NARRATIVE'};
my $query_description = $$query{'DESCRIPTION'};
my $query_keywords = $$query{'KEYWORDS'};

my $ENG_IDF = "enidf";
my $CHIN_IDF = "cnidf";

extract_sentfeatures($datadir, {'Cluster' => \&cluster, 
				'Document' => \&document,
				'Sentence' => \&sentence});

sub cluster {
    my $cluster = shift;

    # open the appropriate IDF file based on language...
    if ($$cluster{'LANG'} && $$cluster{'LANG'} eq "CHIN") {
	open_nidf($CHIN_IDF);
    } else {
	open_nidf($ENG_IDF);
    }
}

my %allsents = ();

sub document {
    my $docref = shift;
    my $did = shift;

    foreach my $sentref (@$docref) {
	my $text;
	my $sentno;
	if (exists $$sentref{'TEXT'}) {
	  $text = $$sentref{'TEXT'};
	  $sentno = $$sentref{'SNO'};
	}
	else {next; }
	chomp $text;
	my @words = split (/\s+/,$text);
	my $stemmer = Lingua::Stem->new(-locale => 'EN-US');
	$stemmer->stem_caching({ -level => 2 });
        # Stem the sentence
	my @stemmed_words = $stemmer->stem(@words);
	my $stemmed_sentence = '';
	foreach my $word (@words) {
		$stemmed_sentence .= "$word ";
	}
	$allsents{$did}{$sentno} = "$stemmed_sentence";
    }
}

sub sentence {
    my $feature_vector = shift;
    my $sentref = shift;
    my $sno = $$sentref{'SNO'};
    my $did = $$sentref{'DID'};
    my $sentence_text = $$sentref{'TEXT'};

    if (($option eq "all" or $option eq "keywords") and $query_keywords) {
	$$feature_vector{'QueryPhraseMatch'} = 
	    phrase_match($query_keywords, $sentence_text, $sno, $did);
    }

}

my @phrases = ();
sub phrase_match {
    my ($q_keywords, $stext, $sno, $did) = @_;
    chomp $q_keywords; chomp $stext; chomp $sno;
    my $score = 0;
    my $k; my $w;

    # do not stem the key phrases
    if(!@phrases) {
	my @list = split /\;/, $q_keywords;
	while(($k = shift @list) && ($w = shift @list)) {
	    chomp $k; chomp $w;
	    push @phrases, $k;
	    push @phrases, $w;
	}
    }

    my $stemmed = $allsents{$did}{$sno};

    for(my $i = 0; $i < $#phrases; $i += 2) {
	$k = $phrases[$i];
	$w = $phrases[$i+1];
	# Match the stemmed phrase against the text ignoring case
	if ($stext =~ /$k/i || $stemmed =~ /$k/i) {
		$score += $w;
	}
    }
#    close DEBUG;
    return $score;
}
