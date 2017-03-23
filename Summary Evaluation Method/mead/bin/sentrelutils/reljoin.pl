#!/apps/bin/perl -w

use lib "/n/nfs/svarog/winkela/perl5/lib/site_perl/5.6.0/";
use XML::TreeBuilder;
use XML::Element;
use Getopt::Long;
use strict;


my (%relhash1, %relhash2);



#my $extract_file = shift;
my $relation_file1 = shift;
my $relation_file2 = shift;

#my $extract_tree = XML::TreeBuilder->new;
#$extract_tree->parsefile($extract_file);
#my $extract_node = $extract_tree->find_by_tag_name("EXTRACT");

my $relation_tree1 = XML::TreeBuilder->new;
$relation_tree1 ->parsefile($relation_file1);

my $relation_tree2 = XML::TreeBuilder->new;
$relation_tree2 ->parsefile($relation_file2);


# extract info
#my $i=0;
#my @extract_sentences=();
#my $S_node;
#foreach $S_node ($extract_node->find_by_tag_name('S'))
#{
#  my $DID = $S_node->attr("DID");
#  my $SNO = $S_node->attr("SNO");
  
 

#  $extract_sentences[$i++]=$DID."-".$SNO;
#  #print $extract_sentences[$i-1], "\n";
#}

# relation info
my $R_node;

foreach $R_node ($relation_tree1 ->find_by_tag_name('R')){
  my $SDID=$R_node->attr('SDID');
  my $SSENT=$R_node->attr('SSENT');
  my $TDID=$R_node->attr('TDID');
  my $TSENT=$R_node->attr('TSENT');
  my $key = $SDID."-".$SSENT."-".$TDID."-".$TSENT;

  my @Rel = $R_node->find_by_tag_name('RELATION');
  my $RELATION_node;
  my $hashVal = $Rel[0]->attr('TYPE').':'.$Rel[0]->attr('JUDGE');

  my $i; 
  for ($i =1; $i< scalar(@Rel); $i++)
  {
	$RELATION_node = $Rel[$i];
	$hashVal .= ('-'.$RELATION_node->attr('TYPE').':'.$RELATION_node->attr('JUDGE'));
  }

  $relhash1{$key} = $hashVal;

#  print $key, "\t", $hashVal, "\n";

}


foreach $R_node ($relation_tree2 ->find_by_tag_name('R')){
  my $SDID=$R_node->attr('SDID');
  my $SSENT=$R_node->attr('SSENT');
  my $TDID=$R_node->attr('TDID');
  my $TSENT=$R_node->attr('TSENT');
  my $key = $SDID."-".$SSENT."-".$TDID."-".$TSENT;

  my @Rel = $R_node->find_by_tag_name('RELATION');
  my $RELATION_node;
  my $hashVal = $Rel[0]->attr('TYPE').':'.$Rel[0]->attr('JUDGE');

  my $i;
  for ($i =1; $i< scalar(@Rel); $i++)
  {
        $RELATION_node = $Rel[$i];
        $hashVal .= ('-'.$RELATION_node->attr('TYPE').':'.$RELATION_node->attr('JUDGE') );
  }

  $relhash2{$key} = $hashVal;

#  print $key, "\t", $hashVal, "\n";

}


my $Key;
foreach $Key (keys(%relhash2))
{
	if (exists($relhash1{$Key}))
            {
              $relhash1{$Key}.= ('-'.$relhash2{$Key});
            }
	else
            {
              $relhash1{$Key} = $relhash2{$Key};
            }

}




print "<!DOCTYPE TABLE SYSTEM \"/clair4/projects/cst/gulfair/judgement/sentrel.dtd\">\n";

print "<TABLE>\n";

foreach my $key (keys %relhash1)
{
    my @header=split(/\-/,$key);
    my $SourceDoc=$header[0];
    my $SourceSent=$header[1];
    my $TargetDoc=$header[2];
    my $TargetSent=$header[3];

    print "<R SDID=\"",$SourceDoc,"\" ","SSENT=\"",$SourceSent,"\" ","TDID=\"",$TargetDoc,"\" ","TSENT=\"",$TargetSent,"\">\n";

    my @content=split(/\-/,$relhash1{$key});
    for (my $i=0; $i<=$#content; $i++)
      {
        my @SubContent=split(/\:/,$content[$i]);
        my $RelType=$SubContent[0];
        my $judge=$SubContent[1];

        print "<RELATION TYPE=\"",$RelType,"\" ","JUDGE=\"",$judge,"\"/>\n";


      }

    print "</R>\n";
}
print "</TABLE>\n";
