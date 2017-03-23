#!/apps/bin/perl -w

use lib "/n/nfs/svarog/winkela/perl5/lib/site_perl/5.6.0/";
use XML::TreeBuilder;

use Getopt::Long;

use strict;

#%RelTable=();


my $thres = 1;
my (@yeslist, @nolist);

GetOptions (
#            "delete" => \$delete,

#            "globalthres=i" => \$global_thres,
	    "thres=i" => \$thres,
#	    "yeslist=s" => \@yeslist,
#	    "nolist=s" => \@nolist
           );

@yeslist = split(/,/,join(',',@yeslist));
@nolist = split(/,/,join(',',@nolist));

my (%yeshash, %nohash);

if (@yeslist >= 1)
{
  my $i;
  for ($i=0; $i<=$#yeslist; $i++)
    {
      $yeshash{$yeslist[$i]}=1;
    }
};

if (@nolist >= 1)
{
  my $i;
  for ($i=0; $i<=$#yeslist; $i++)
    {
      $nohash{$nolist[$i]}=1;
    }
};

my $extract_file = shift;
my $relation_file = shift;

#print $extract_file, "\n";
#if (defined $global_thres) 
#{print $thres, "\n";}
#if (@yeslist >=1) {print $yeslist[0], "\n"} else {print "yeslist not defined\n"};

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
my (@sentence_pairs, @sentence_pairs_yes, @sentence_pairs_no);
my ($j, $jy, $jn) = 0;
foreach $R_node ($relation_tree->find_by_tag_name('R')){
  my $SDID=$R_node->attr('SDID');
  my $SSENT=$R_node->attr('SSENT');
  my $TDID=$R_node->attr('TDID');
  my $TSENT=$R_node->attr('TSENT');

  my $RELATION_node;
  my $yes_strength=0;
  my $no_strength=0;
  my $both_strength=0;
  foreach $RELATION_node ($R_node->find_by_tag_name('RELATION')){
    if (exists $yeshash{$RELATION_node->attr('TYPE')}) {$yes_strength++;}
    if (exists $nohash{$RELATION_node->attr('TYPE')}) {$no_strength++;}
    $both_strength++;
  }

  if ($both_strength >= $thres) {$sentence_pairs[$j++]=$SDID."-".$SSENT."-".$TDID."-".$TSENT;}
  if ($yes_strength >= $thres) {$sentence_pairs_yes[$jy++]=$SDID."-".$SSENT."-".$TDID."-".$TSENT;}
  if ($no_strength >= $thres) {$sentence_pairs_no[$jn++]=$SDID."-".$SSENT."-".$TDID."-".$TSENT;}
    #print $sentence_pairs[$j-1];
    #print "\n";
}

# calculate connectivity
my $k;
my ($sent_pair1, $sent_pair2);
my $connectivity=0;
my $yes_connectivity=0;
my $no_connectivity=0;
for ($i=0; $i<=$#extract_sentences; $i++)
  {
    for ($j=$i+1; $j<=$#extract_sentences; $j++)
      {
	$sent_pair1=$extract_sentences[$i]."-".$extract_sentences[$j];
	$sent_pair2=$extract_sentences[$j]."-".$extract_sentences[$i];
	for ($k=0; $k<=$#sentence_pairs; $k++)
	  {
	    if (($sent_pair1 eq $sentence_pairs[$k]) || ($sent_pair2 eq $sentence_pairs[$k]) )
	      {
		# print "yes\n";
		$connectivity++;
		last;
	      }
	  }
	for ($k=0; $k<=$#sentence_pairs_yes; $k++)
	  {
	    if (($sent_pair1 eq $sentence_pairs_yes[$k]) || ($sent_pair2 eq $sentence_pairs_yes[$k]) )
	      {
		# print "yes\n";
		$yes_connectivity++;
		last;
	      }
	  }
	for ($k=0; $k<=$#sentence_pairs_no; $k++)
	  {
	    if (($sent_pair1 eq $sentence_pairs_no[$k]) || ($sent_pair2 eq $sentence_pairs_no[$k]) )
	      {
		# print "yes\n";
		$no_connectivity++;
		last;
	      }
	  }


      }
  }

print "Connectivity: $connectivity\n";
#print "Yes Connectivity: $yes_connectivity\n";
#print "No Connectivity: $no_connectivity\n";
