#!/usr/bin/perl -w

# testing all measures

use Measures;
#use Extracting;
use Edit;


my %docpos_table;
my $bleu_DIR = "/clair4/tools/bleu";

$extract1 = shift;
$extract2 = shift;

($simple,$cosine1,$token_overlap,$bi_overlap,$norm_lcs, $bleu) = test_measures($extract1,$extract2,"-w","ALL");


print "a) Simple Cosine: $simple\n";
print "b) Cosine       : $cosine1\n";
print "c) Token Overlap: $token_overlap\n";
print "d) Big.  Overlap: $bi_overlap\n";
print "e) Norm. LCS    : $norm_lcs\n";
print "f) Bleu         : $bleu\n";

sub my_bleu{
#this subroutine is taken from Zhu Zhang's sim.pl

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
    
    my @ResultLines = `perl $bleu_DIR/bleu-1.pl -r my.ref -t my.tst 2>null`;

    my $score = 0;
    if ( $ResultLines[scalar(@ResultLines)-1] =~ /^BLEU,(.*)/g ) {$score = $1;}
#    if ( $ResultLines[scalar(@ResultLines)-6] =~ /^2-gPrec,(.*)/g ) {$score = $1;}
    
    return $score;



}

sub test_measures {

my $summary1 = shift;
my $summary2 = shift;
my $option = shift;
my $type = shift;
my @sentences1 = ();
my @sentences2 = ();

@sentences1 = &open_file($summary1);
@sentences2 = &open_file($summary2);

my $text1 = "";
my $count1 = 0;

foreach $sent (@sentences1) {
    $sent =~ s/^\s+//;
    $sent =~ s/\s+$//;
#    print "SENT1: $sent\n";
    $text1 = $text1.$sent." ";
    $count1++
}

my $length1 = length($text1);

my $text2 = "";




my $count2 = 0;

foreach $sent (@sentences2) {
    $sent =~ s/^\s+//;
    $sent =~ s/\s+$//;
#    print "SENT2: $sent\n";
    $text2 = $text2.$sent." ";
    $count2++;
}

my $length2=length($text2);

#print "TEXT1: $text1\n";

#print "TEXT2: $text2\n";



my $cosine1 = my_cosine($option,$text1,$text2);

my $simple = my_simple_cosine($text1,$text2);

my $token_overlap = my_token_overlap($text1,$text2);

my $bi_overlap = my_bigram_overlap($text1,$text2);

my $bleu = my_bleu($text1,$text2);

# lcs


for($s1=0;$s1<$count1;$s1++) { $max1[$s1] = 0;}
for($s2=0;$s2<$count2;$s2++) { $max2[$s2] = 0;}

for($s1=0;$s1<$count1;$s1++) {
     for($s2=0;$s2<$count2;$s2++) {
	 $lcs = my_lcs($sentences1[$s1],$sentences2[$s2]);
#	 print "S1: $s1, S2: $s2, LCS: $lcs\n";
	 if($lcs>$max1[$s1]) { $max1[$s1] = $lcs; }
	 if($lcs>$max2[$s2]) { $max2[$s2] = $lcs; }
     }
}

my $total1 = 0 ;

my $total2 = 0;

for($s1=0;$s1<$count1;$s1++) { $total1=$total1+$max1[$s1];}
for($s2=0;$s2<$count2;$s2++) { $total2=$total2+$max2[$s2];}

@tokens1 = split(/ /,$text1);
@tokens2 = split(/ /,$text2);
$l1 = $#tokens1+1;
$l2 = $#tokens2+1;

#print "TOTAL1: $total1, L1: $l1\n";
#print "TOTAL2: $total2, L2: $l2\n";


my $norm_lcs = ($total1+$total2)/($l1+$l2);




    return ($simple,$cosine1,$token_overlap,$bi_overlap,$norm_lcs,$bleu);

}



sub open_file{
my $file = shift;

my @sents = ();

local( $/ ) = undef;

open(FILE, "$file") or die "can't find the file: $file. \n";

my $input = <FILE>;

close FILE;

if ($input =~/DOCTYPE DOCUMENT SYSTEM/){
   my $text = "";
   $input =~/<TEXT>(.*)<\/TEXT>/s;
   $text = $1;
   @sents = split /[\n\r]/, $text;
}

else {

@sents = split /[\n\r]/, $input;

foreach $s (@sents){
   $s =~s/^\[\d+\]\s+(.*)/$1/;
  }
}
return @sents;
}

