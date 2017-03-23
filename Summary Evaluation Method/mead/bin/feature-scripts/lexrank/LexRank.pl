#!/usr/local/bin/perl -w

#########################################################################
#
# Usage:
#   cat cluster_file | ./LexRank [-bias path] [-debug] [-jump jump] \
#       [-newbias path] $datadir
#
#   datadir is appended by driver.pl upon invoking this feature script
#   bias points to a file in the format BIAS\tDID\tSID
#   debug leaves the byproduct files (instead of cleaning up when done)
#   jump is the LexRank jump probability, should be in [0,1], defaults to
#     0.15
#   newbias creates a template bias file for the user to fill out (instead
#     of actually running lexrank)
#
#########################################################################

use strict;
use FindBin;
use lib "$FindBin::Bin/../../../lib/", "$FindBin::Bin/../../../lib/arch/";
use MEAD::SentFeature;
use Getopt::Long;

my $feature_name = "LexRank";

my $bias = "";
my $newbias = "";
my $debug = 0;
my $jump = 0.15;
GetOptions ("bias:s"  => \$bias, 
            "debug" => \$debug, 
            "jump:f" => \$jump,
            "newbias:s" => \$newbias);

my $datadir = $ARGV[$#ARGV - 1];

my $bindir = "$FindBin::Bin/../..";
my $path = "$bindir/feature-scripts/lexrank";
my $outdir = "$datadir/../lexrank-data";

my $sentfile = "$outdir/sentences.txt";
my $cosfile = "$outdir/cosine.txt";
my $biasfile = "$outdir/bias.txt";
my $outfile = "$outdir/out.txt";

my $lexrank = "$path/prmain";

my $maxid;
my $max_score;
my $min_score;

my %idmap;
my @biaslines;
my %scores;

if (!(-e $outdir)) {
    mkdir($outdir) or die "Could not create output directory $outdir: $!";
}

# Generate the list of sentences
&make_sentences;

if ($newbias) {
    open BIASFILE, ">$newbias" or die "Could not create $newbias: $!";
    foreach my $line (@biaslines) {
        print BIASFILE "1\t$line\n";
    }
    close BIASFILE;
}

# Create cosines from sentences
`$path/getcos.pl $sentfile > $cosfile`;

my $command = "$lexrank -link $cosfile -maxid $maxid -out $outfile "
            . "-jump $jump 2>/dev/null ";

# Create a bias file if necessary
if ($bias) {
    &make_bias;
    $command = "$command -bias $biasfile";
}

# Run lexrank
`$command` or die "Could not run lexrank command '$command': $!";

# Get the scores
&load_scores;

# Get the max/min scores (used to normalize the scores)
$max_score = `cat $outfile | cut -f2 | sort -nr | head -1`;
$min_score = `cat $outfile | cut -f2 | sort -nr | tail -1`;

# Clean up
`rm -rf $outdir` unless ($debug);

# Do the extract
extract_sentfeatures($datadir, {'Cluster' => \&cluster,
                                'Document' => \&document,
                                'Sentence' => \&sentence});

sub cluster {}
sub document {}

sub sentence {
    my $feature_vector = shift;
    my $sentref = shift;
    my $did = $$sentref{'DID'};
    my $sno = $$sentref{'SNO'};

    my $score = $scores{"$did,$sno"};
    if (!$score) {
        $$feature_vector{$feature_name} = 0;
    } elsif ($max_score - $min_score == 0) {
        $$feature_vector{$feature_name} = 1;
    } else {
        # Normalize the score
        $$feature_vector{$feature_name} = 
            1.0 * ($score - $min_score) / ($max_score - $min_score);
    }
}


#############
# Helper subs
#############

sub make_sentences {

    # Taken from the old LexRank.pl

    my @docsents = glob("$datadir/*.docsent");
    open SENTS, ">$sentfile" or die "Cannot write to $sentfile!";
    my $i = 0;
    foreach my $docsent (@docsents) {
        # Extract DID from the docsent file name
        my @tmp = split /\//, $docsent;
        my $d = pop @tmp;
        @tmp = split /\.docsent/, $d;
        $d = shift @tmp;
        open DOCSENT, "<$docsent" or die "$docsent not found!";
        while(my $line = <DOCSENT>) {
            chomp $line;
            if($line =~ /<S.*SNO=.(\d+).*>(.*)<\/S>/) {
                print SENTS "$d\t$1\t$2\n";

                # Keep track of index 
                $idmap{"$d,$1"} = $i;

                # If we're making a bias file, keep track of the sentences
                if ($newbias) {
                    push @biaslines, "$d\t$1\t$2";
                }

                $maxid = $i;
                $i++;
            }
        }
        close DOCSENT;
    }
    close SENTS;

}

sub make_bias {
    open INBIAS, "<$bias" or die "could not read $bias: $!";
    open OUTBIAS, ">$biasfile" or die "could not write $biasfile: $!";
    while (my $line = <INBIAS>) {
        chomp $line;
        my @fields = split /\s+/, $line;
        my ($bias, $did, $sno) = ($fields[0], $fields[1], $fields[2]);
        my $id = $idmap{"$did,$sno"};
        print OUTBIAS "$id\t$bias\n";
    }
    close INBIAS;
    close OUTBIAS;
}

sub load_scores {
    my %idmap_inverse = reverse %idmap;
    open LEXRANK, "<$outfile" or die "could not read $outfile: $!";
    while (my $line = <LEXRANK>) {
        chomp $line;
        my ($id, $score) = split /\t/, $line;
        my ($did, $sno) = split /,/, $idmap_inverse{$id};
        $scores{"$did,$sno"} = $score;
    }
}
