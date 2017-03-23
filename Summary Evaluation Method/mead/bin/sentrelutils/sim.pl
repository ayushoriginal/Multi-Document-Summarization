#!/usr/local/bin/perl -w

$| = 1;

use strict;

############################################################

# For SimRoutines.pm

use lib "/clair4/projects/mead307/stable/mead/lib";
use MEAD::SimRoutines;
# use MEAD::Evaluation;

# IDF file used for calculating lexical similarity
$idffile = '/clair4/projects/mead307/stable/mead/etc/enidf';

############################################################

# For XML parsing

#use lib "/n/nfs/svarog/winkela/perl5/lib/site_perl/5.6.0/";
use XML::TreeBuilder;
use XML::Element;

############################################################

use Getopt::Long;

use Algorithm::Diff qw(diff sdiff LCS traverse_sequences traverse_balanced);

############################################################

# Global vars

my (%SentHash, %RelHash, %StopWordHash, %SimSentHash);

###########################################################

# Main program


my $RelThres = 1;
my $SimThres = .2;
my $Weight = .1;
my $StopWordFileName;
my ($Cosine, $WordOverlap, $LCS, $BLEU, $JCN, $MIX, $Matrix) = 0;

my $SimVal;
my ($RelSim, $RelNotSim, $NoRelSim, $NoRelNotSim) = 0.0;

$RelSim = $RelNotSim = $NoRelSim = $NoRelNotSim = 0.0;

GetOptions (
	"rthres=i" => \$RelThres,
	"sthres=f" => \$SimThres,
	"weight=f" => \$Weight,
	"cosine"	 => \$Cosine,
	"wordoverlap" => \$WordOverlap,
	"lcs"      => \$LCS,
	"bleu"		=> \$BLEU,
	"jcn"		=> \$JCN,
	"mix" 		=> \$MIX,
	"matrix"   => \$Matrix,
	"stopword=s"  => \$StopWordFileName
           );

die "No similarity measure specified!" unless ($Cosine || $WordOverlap || 
$LCS || $BLEU || $JCN || $MIX);


my $ClusterFile = shift;
Cluster2SentHash($ClusterFile);

my $RelFile = shift;
if ($RelFile) {Rel2StrengthHash($RelFile);}


if ($StopWordFileName)
	{ InitializeStopWordHash($StopWordFileName);}


# Print header
if ($Matrix)
{
  print "Similarity Matrix: \n\n"; 
  print "\t"; 
  foreach my $key (keys(%SentHash)) 
  {
    print $key, "\t";
  }
  print "\n";
}

my $SimSentPair = 0;
my ($OutDocID, $OutSentID, $InDocID, $InSentID);

my $SentCount = 1;

my ($RelKey, $RevRelKey);

foreach my $OuterKey (keys(%SentHash))
{
  if ($Matrix) {print $OuterKey, "\t";}

  foreach my $InnerKey (keys(%SentHash))
  {

    my $sent1 = $SentHash{$OuterKey};
    my $sent2 = $SentHash{$InnerKey};


   if (scalar(keys(%StopWordHash)) > 0 )
   {
     foreach my $sw (keys(%StopWordHash))
	{
	  $sent1 =~ s/\s+$sw\s+/ /ig;
          $sent2 =~ s/\s+$sw\s+/ /ig;
	}
   }

   if (($sent1 eq '')||($sent1 =~ /^\s+$/)||($sent2 eq '')||($sent2 =~ /^\s+$/))
   {
     $SimVal = 0;
   }
   else
   {
    if ($Cosine) 
	{$SimVal = GetLexSim($sent1, $sent2);}
    elsif ($WordOverlap)
	{$SimVal = unigram_overlap($sent1, $sent2);}
    elsif ($LCS)
	{$SimVal = LCS_ratio($sent1, $sent2);}
    elsif ($BLEU)
        {$SimVal = Bleu($sent1, $sent2);}
    elsif ($JCN)
	{$SimVal = JiangConrathSim($sent1, $sent2);}
    elsif ($MIX)
	{$SimVal = $Weight*GetLexSim($sent1, $sent2)+(1.0-$Weight)*Bleu($sent1, $sent2);}

    if ($Matrix) {printf "%4.2f\t", $SimVal;}
   }

    next if ($OuterKey eq $InnerKey); # skip diagonal elements

    ($OutDocID, $OutSentID) = split(/-/,$OuterKey);
    ($InDocID, $InSentID) = split(/-/,$InnerKey);
    next if ($OutDocID eq $InDocID);  # skip intra-doc sentence pairs

    $RelKey = $OuterKey.":".$InnerKey;
    $RevRelKey = $InnerKey.":".$OuterKey;

    if ($RelFile)
    {
    if ( $SimVal >= $SimThres ) # && !exists($SimSentHash{$RevRelKey}) )
    {
        #$SimSentHash{$RelKey} = 1;
	$SimSentPair++;
	if ( !exists($RelHash{$RelKey}) && !exists($RelHash{$RevRelKey}) )
          { $NoRelSim++;}
        else 
	{
	  #print $RelKey, "\n";
	  $RelSim++;
	}
    }
    else
    {
        if ( !exists($RelHash{$RelKey})  && !exists($RelHash{$RevRelKey}) ) 
          { $NoRelNotSim++;}
        else 
	{
	  #print $RelKey, "\n";
	  $RelNotSim++;
	}
    }

  }
  else
  {
	$RevRelKey = $InnerKey.":".$OuterKey;
	if ( ($SimVal >= $SimThres) && !exists($SimSentHash{$RevRelKey}) )
	{
	  $SimSentHash{$RelKey} = 1;
	  $SimSentPair++;
	  #print $RelKey, "\n";
	  print "($SentCount)\n";

	  $sent1 =~ s/^(.+)\.com\s*[:-]//;
          $sent2 =~ s/^(.+)\.com\s*[:-]//;

	  print "$OuterKey: $sent1\n";
 	  print "$InnerKey: $sent2\n";
	  print "\nCST type:\t\tDirectionality:\n";
	  print "\n\n";
	  $SentCount++;
	}
  }
  }
  if ($Matrix) {print "\n";}
}

my ($Precision, $Recall) = 0.0;
$Precision = $Recall = 0.0;

if (($RelSim + $NoRelSim)>0) 
	{$Precision = $RelSim/($RelSim+$NoRelSim); }
if (($RelSim + $RelNotSim)>0) 
	{$Recall = $RelSim/($RelSim+$RelNotSim); }
my $TotalSentPair = (scalar(keys(%SentHash)))*(scalar(keys(%SentHash)));

if ($RelFile) { $SimSentPair = $SimSentPair/2;}

#if ($RelFile)
#{
	print "\n\nMatching statistics:\n\n";
	print "TotalSentPairs\t$TotalSentPair\n";
	print "SimilarSentPairs\t$SimSentPair\n";
	print "Precision\t$Precision\n";
	print "Recall\t$Recall\n";
#}
#else
#{
#        print "TotalSentPairs\t$TotalSentPair\n";
#        print "SimilarSentPairs\t$SimSentPair\n";
#}

###########################################################

# Subroutines


sub CalSim  # Not used any more
{
  my ($Text1, $Text2, $nSim);
  $Text1 = shift;
  $Text2 = shift;

  $nSim = GetLexSim($Text1, $Text2);

  return $nSim;

}


sub Cluster2SentHash
{
  my $ClusterFile = shift;

  my $ClusterTree = XML::TreeBuilder->new;
  $ClusterTree->parsefile($ClusterFile);

  my $D_node;
  my $DID;

  foreach $D_node ($ClusterTree->find_by_tag_name('D'))
  {
    $DID = $D_node->attr('DID');

    my $DocTree = XML::TreeBuilder->new;
    $DocTree->parsefile($DID.'.docsent');

    my $S_node;

    foreach $S_node ($DocTree->find_by_tag_name('S'))
    {
      my $SNO=$S_node->attr('SNO');
      my $SentText = ($S_node->content_list)[0];


      next if ( ($SentText eq '') || ($SentText =~ /^\s+$/) );

      my $key = $DID."-".$SNO;

      $SentHash{$key} = $SentText;

#      print $key, "\t", $SentText, "\n";

    }
  }

}


sub Rel2StrengthHash
{
  my $RelationFile = shift;

  my $RelationTree = XML::TreeBuilder->new;
  $RelationTree->parsefile($RelationFile);

  my $R_node;

  foreach $R_node ($RelationTree->find_by_tag_name('R'))
  {
    my $SDID=$R_node->attr('SDID');
    my $SSENT=$R_node->attr('SSENT');
    my $TDID=$R_node->attr('TDID');
    my $TSENT=$R_node->attr('TSENT');
    
    my $key = $SDID."-".$SSENT.":".$TDID."-".$TSENT;

    my @Rel = $R_node->find_by_tag_name('RELATION');
    my $RelStrength = $#Rel+1;

    $RelHash{$key} = $RelStrength;

#    print $key, "\t", $RelStrength, "\n";
  }

}


##################################################################

# Subroutines for computing word overlap

sub unigram_overlap {
    my ($text1, $text2) = @_;

    # better way to split?  Maybe get rid of some punctuation???
    my @tokens1 = split(/ /, $text1);
    my @tokens2 = split(/ /, $text2);
  
#   if (scalar(keys(%StopWordHash)) > 0 )
#        {
#          @tokens1 = RemoveStopWords(@tokens1);
#          @tokens2 = RemoveStopWords(@tokens2);
#        }
 
    my %set1 = ();
    my %set2 = ();

    foreach my $token (@tokens1) {
    $set1{$token}++;
    }
 
    foreach my $token (@tokens2) {
        $set2{$token}++;
    }

    my $overlap = _set_overlap(\%set1,\%set2);
    my $normalized = $overlap /
    ( scalar(keys(%set1)) + scalar(keys(%set2)) - $overlap);

    return $normalized;
}


sub _set_overlap {
    my ($s1, $s2) = @_;

    my %s1 = %$s1;
    my %s2 = %$s2;
    my $overlap = 0;

    foreach my $key (keys %s1) {
        if ($s2{$key}) {
            $overlap++;
        }
    }

    return $overlap;
}


##################################################################

# Subroutines for computing LCS

sub LCS_ratio {

    my ($text1, $text2) = @_;

    # better way to split?  Maybe get rid of some punctuation???
    my @tokens1 = split(/ /, $text1);
    my @tokens2 = split(/ /, $text2);

#    if (scalar(keys(%StopWordHash)) > 0 )
#        {
#	  @tokens1 = RemoveStopWords(@tokens1);
#          @tokens2 = RemoveStopWords(@tokens2);
#        }

    my @lcs = LCS(\@tokens1, \@tokens2);
    my $normalized = scalar(@lcs)/(scalar(@tokens1)+scalar(@tokens2)-scalar(@lcs));
    #my $normalized = $overlap /
    #( scalar(keys(%set1)) + scalar(keys(%set2)) - $overlap);

    return $normalized;
}


#####################################################################


sub InitializeStopWordHash
{
  my $FileName = shift;

  open(TEXT, "<$FileName") or die "Can't open $FileName : $!";

  while (<TEXT>) 
  { 
    chomp;
    $StopWordHash{$_} = 1;
  }

}


sub RemoveStopWords
{
  my @After = ();

  foreach my $Token (@_)
  {
	if( exists($StopWordHash{$Token}) ) {}
	else { $After[$#After+1] = $Token;}
  }
  
  return @After;
}

#################################################################

# Subroutine for computing Bleu

sub Bleu {

    my ($text1, $text2) = @_;

    open (REF, ">my\.ref");
    print REF "\<DOC doc_ID=\"1\" sys_ID=\"orig\"\>\n";
    print REF "\<segment\>\n";
    print REF "$text1\n";
    print REF "\<\/segment\>\n";
    print REF "\<\/DOC\>";
    close REF;


    open (TST, ">my\.tst");
    print TST "\<DOC doc_ID=\"1\" sys_ID=\"test1\"\>\n";
    print TST "\<segment\>\n";
    print TST "$text2\n";
    print TST "\<\/segment\>\n";
    print TST "\<\/DOC\>";
    close TST;

    my @ResultLines = `perl /clair4/tools/bleu/bleu-1.pl -r my.ref -t my.tst 2>null`;

    my $score = 0;
    if ( $ResultLines[scalar(@ResultLines)-1] =~ /^BLEU,(.*)/g ) {$score = $1;}
#    if ( $ResultLines[scalar(@ResultLines)-6] =~ /^2-gPrec,(.*)/g ) {$score = $1;}

    return $score;

}


#############################################################


sub JiangConrathSim {

    my ($text1, $text2) = @_;
    my ($TokenIn1, $TokenIn2);
    my $Sim = 0.0;
    my $jcn;

    # better way to split?  Maybe get rid of some punctuation???
    my @tokens1 = split(/ /, $text1);
    my @tokens2 = split(/ /, $text2);


    open (TXT, ">/clair4/tools/distance-0.11/test.txt");

    foreach $TokenIn1 (@tokens1)
    {
	foreach $TokenIn2 (@tokens2)
	{
          print TXT "$TokenIn1 $TokenIn2\n";
	
	}
    }
   
    close TXT;

    chdir '/clair4/tools/distance-0.11';
    my @ResultLines=`./distance.pl --type jcn --file test.txt`;
    my $ResultLine;
    #print @ResultLines;

    foreach $ResultLine (@ResultLines)
    {
          if ( $ResultLine =~ /^(.+)\s+(.+)\s+(.+)/g )
            {$jcn = $3;}
          else
            {$jcn = 0;}

	  #my @t = split;
	  #$jcn = $t[2];

          $Sim += $jcn;
    }
    
    $Sim /= (scalar(@tokens1)*scalar(@tokens2));

    return $Sim;
}
