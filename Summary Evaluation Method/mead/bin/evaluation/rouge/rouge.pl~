#!/usr/bin/perl

use strict;

my $ROUGE_HOME = "/clair8/tools/ROUGEeval-JK-1.2";

my $systemFile = shift;
my @models = @ARGV;

my @sentences = ();

`rm $ROUGE_HOME/systems/*`;
`rm $ROUGE_HOME/models/*`;
`rm $ROUGE_HOME/auto_temp.xml`;

open (SYSTEM, ">$ROUGE_HOME/systems/1.html");

print SYSTEM "<html>
<head>
<title>1.html</title>
</head>
<body bgcolor=\"white\">\n";
my $count = 1;

@sentences = &open_file($systemFile);

foreach my $i (0..$#sentences) {
	print SYSTEM "<a name=\"$count\">[$count]</a> <a href=\"#$count\" id=$count>";
	print SYSTEM $sentences[$i];
	print SYSTEM "</a>\n";
	$count++;
}
	print SYSTEM "</body>
</html>\n";
	close SYSTEM;

for my $i (0..$#models) {
	@sentences = &open_file($models[$i]);
	open (MODEL,">$ROUGE_HOME/models/$i.html");
	print MODEL "<html>
<head>
<title>$i.html</title>
</head>
<body bgcolor=\"white\">\n";
	$count = 1;
foreach my $j (0..$#sentences) {
        print MODEL "<a name=\"$count\">[$count]</a> <a href=\"#$count\" id=$count>";
        print MODEL $sentences[$j];
        print MODEL "</a>\n";
        $count++;
}
        print MODEL "</body>
</html>\n";
        close MODEL;
}


my $evalID = 1;

open (CONFIG, ">$ROUGE_HOME/auto_temp.xml");
print CONFIG "<EVAL ID=\"$evalID\">\n";
print CONFIG "<PEER-ROOT>\nsystems\n</PEER-ROOT>\n";
print CONFIG "<MODEL-ROOT>\nmodels\n</MODEL-ROOT>\n";
print CONFIG "<INPUT-FORMAT TYPE=\"SEE\">
</INPUT-FORMAT>
<PEERS>
<P ID=\"1\">1.html</P>
</PEERS>
<MODELS>\n";

for my $i (0..$#models) {
	print CONFIG "<M ID=\"$i\">$i.html</M>\n";
}

print CONFIG "</MODELS>
</EVAL>\n";

close CONFIG;

print `$ROUGE_HOME/runROUGE.sh`;


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

foreach my $s (@sents){
   $s =~s/^\[\d+\]\s+(.*)/$1/;
  }
}
return @sents;
}
