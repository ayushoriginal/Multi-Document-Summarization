#!/usr/local/bin/perl 

use HTML::TreeBuilder;
use MEAD_ADDONS_UTIL qw (extract_title_from_html extract_text_from_html 
            split_sentences);

my $file = shift;

my $final_straw = "all rights reserved";#if a sentence contains this,
                                        #don't print it or any of the
                                        #following sentences


my $html = &open_file("$file");
my $title =  &extract_title_from_html("$html");
my $text = &extract_text_from_html("$html");

my @sents = &split_sentences("$text");

&output;

sub output{

print "$title\n\n";

foreach $sent(@sents){

  if ($sent =~/$final_straw/i){last;}

  print "$sent \n\n";

}

}

sub open_file{
my $file = shift;
my $input = "";

if (! -f $file){die "$file isn't a file\n";}
open(INFILE, "$file") or die "can't find $file\n";
   
my @data = <INFILE>;

close INFILE;

foreach my $line (@data)
{
 $input .= $line;
}

$input =~s/[\r\n]/ /g;
return $input;
}
