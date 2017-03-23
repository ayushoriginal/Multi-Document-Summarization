#!/apps/bin/perl -w

use lib "/n/nfs/svarog/winkela/perl5/lib/site_perl/5.6.0/";
use XML::TreeBuilder;
use XML::Element;
use Getopt::Long;
use strict;

# %RelTable=();

my $thres = 1;
#my (@yeslist, @nolist);
my @rellist;

GetOptions (
#            "delete" => \$delete,

#            "globalthres=i" => \$global_thres,
	    "thres=i" => \$thres,
	    "rellist=s" => \@rellist,
#	    "nolist=s" => \@nolist
           );

@rellist = split(/,/,join(',',@rellist));
#@nolist = split(/,/,join(',',@nolist));

#my (%yeshash, %nohash);
my %relhash;

if (@rellist >= 1)
{
  my $i;
  for ($i=0; $i<=$#rellist; $i++)
    {
      $relhash{$rellist[$i]}=1;
    }
};


my $extract_file = shift;
my $relation_file = shift;

my $extract_tree = XML::TreeBuilder->new;
$extract_tree->parsefile($extract_file);
my $extract_node = $extract_tree->find_by_tag_name("EXTRACT");

my $relation_tree = XML::TreeBuilder->new;
$relation_tree->parsefile($relation_file);


# extract info
my $i=0;
my @extract_sentences=();
my $S_node;
foreach $S_node ($extract_node->find_by_tag_name('S'))
{
  my $DID = $S_node->attr("DID");
  my $SNO = $S_node->attr("SNO");
  
 

  $extract_sentences[$i++]=$DID."-".$SNO;
  #print $extract_sentences[$i-1], "\n";
}

# relation info
my $R_node;
my @sentence_pairs=();
my $j=0;

my $counter =0;
foreach $R_node ($relation_tree->find_by_tag_name('R')){
  my $SDID=$R_node->attr('SDID');
  my $SSENT=$R_node->attr('SSENT');
  my $TDID=$R_node->attr('TDID');
  my $TSENT=$R_node->attr('TSENT');

  my $sent1=$SDID."-".$SSENT;
  my $sent2=$TDID."-".$TSENT;

  my $include = 0;
  for ($i=0; $i<=$#extract_sentences; $i++)
    {
      if ( ($extract_sentences[$i] eq $sent1) || ($extract_sentences[$i] eq $sent2) )
	{$include=1; last;}
    }

  {
  my $RELATION_node;
  my $rel_strength=0;
  my $all_strength=0;
  foreach $RELATION_node ($R_node->find_by_tag_name('RELATION')){
    if (exists $relhash{$RELATION_node->attr('TYPE')}) {$rel_strength++;}
    $all_strength++;
  }
  if (@rellist>=1)    
    {if ($rel_strength < $thres) {$include = 0;}}
  else 
    {if ($all_strength < $thres) {$include = 0;}}
  } 

  if (!$include) {$R_node->delete;} else {$counter++;}
  #$sentence_pairs[$j++]=$SDID."-".$SSENT."-".$TDID."-".$TSENT;

    #print $sentence_pairs[$j-1];
    #print "\n";
}

# calculate connectivity
#my $k;
#my ($sent_pair1, $sent_pair2);
#my $connectivity=0;
#for ($i=0; $i<=$#extract_sentences; $i++)
#  {
#    for ($j=$i+1; $j<=$#extract_sentences; $j++)
#      {
#	$sent_pair1=$extract_sentences[$i]."-".$extract_sentences[$j];
#	$sent_pair2=$extract_sentences[$j]."-".$extract_sentences[$i];
#	for ($k=0; $k<=$#sentence_pairs; $k++)
#	  {
#	    if (($sent_pair1 eq $sentence_pairs[$k]) || ($sent_pair2 eq $sentence_pairs[$k]) )
#	      {
		# print "yes\n";
#		$connectivity++;
#		last;
#	      }
#	  }
#      }
#  }

#print "Connectivity: ";
#print $connectivity;
#print "\n";

print "<?xml version='1.0'?>\n";
print "<!DOCTYPE TABLE SYSTEM \"/clair/projects/cst/gulfair/judgement/table.dtd\" >\n";
print $relation_tree->as_XML();
#print $counter;
