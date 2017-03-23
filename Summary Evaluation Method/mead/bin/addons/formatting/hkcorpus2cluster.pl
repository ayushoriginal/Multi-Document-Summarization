#!/usr/bin/perl 

use MEAD_ADDONS_UTIL qw (get_docsent_header get_docsent_tail  
            get_cluster_header get_cluster_tail sanitize); 

my $inputfile = shift;
my $outputdir = shift;

unless ($outputdir =~/./){$outputdir = ".";}

print "OUTPUTDIR: $outputdir\n";

&main;

sub main{
  my $text = &open_file($inputfile); 
  while ($text =~/<DOC ([^>]+)>(.*?)<\/DOC>/g)
   {
    &text2cluster("$1", "$2");
   }  
}

sub text2cluster{
my $filename = shift;
my $text = shift;

$text =~s/<\/?TEXT>//g;
@sents = split /<s id=/, $text;

$filename =~s/id=(.*)/$1/;
unless (-d "$outputdir"){print `mkdir $outputdir`;}
unless (-d "$outputdir/$filename"){print `mkdir $outputdir/$filename`;} 
unless (-d "$outputdir/$filename/docsent"){ print `mkdir $outputdir/$filename/docsent`;}

$outfile = "$outputdir/$filename/docsent/$filename.docsent";

open (OUTFILE, ">$outfile") or die "can't open output file: $outfile\n";
print OUTFILE &get_docsent_header("$filename.docsent");

my $counter = 1;
foreach $s (@sents){
 if ($s =~/>.+/){
   $s=~/.*?\.([\d]+)\.([\d]+)>(.*)/;
   my $par_no = $1;
   my $rsnt = $2;
   my $string = $3;
   $string = &sanitize($string);

   print OUTFILE "   <S PAR='$par_no' RSNT='$rsnt' SNO='$counter'>$string</S>\n";
   $counter++;
 }
}

print OUTFILE &get_docsent_tail;
close OUTFILE;

&output_cluster_file($filename);
}

sub output_cluster_file{
my $filename = shift;

my $lang = "";

if ($filename =~/c$/){$lang = "CHIN";}

open (OUTFILE, ">$outputdir/$filename/$filename.cluster") || die "Can't open cluster file\n";
     
print OUTFILE &get_cluster_header($lang);

print OUTFILE "     <D DID=\"$filename\" \/>\n";

print OUTFILE &get_cluster_tail;

close OUTFILE;
}

sub open_file{

my $file = shift;
my $input = "";

open(INFILE, "$file") or die "can't find $file\n";

my @data = <INFILE>;
 
close INFILE;

foreach my $line (@data)
{
 $input .= $line;
}

$input =~s/[\n\r]/ /g;
return $input;

}

