#!/usr/local/bin/perl 

use HTML::TreeBuilder;
use MEAD_ADDONS_UTIL qw (extract_title_from_html extract_text_from_html 
            split_sentences get_docsent_header get_docsent_tail
            get_cluster_header get_cluster_tail);

my $inputfile = shift;

my $final_straw = "all rights reserved";#if a sentence contains this,
                                        #don't print it or any of the
                                        #following sentences


#here follows the main program

if (-d $inputfile)
{
   opendir(DIR, "$inputfile") or die 'cannot open directory: $inputfile';
   my @files = readdir(DIR);
   closedir(DIR);
   
   unless (-d "$inputfile/docsent")
   {
     print `mkdir $inputfile/docsent`;
   }

   unless (-d "$inputfile/orig")
   {
     print `mkdir $inputfile/orig`;
   }

   foreach my $file (@files){
      unless (-d "$inputfile/$file" || $file =~/cluster$/){
        my $sents = &html2text("$inputfile/$file");
        &text2docsent_file($sents, "$inputfile/docsent/$file.docsent");
      }
   }
  
   foreach my $file (@files){
       unless (-d "$inputfile/$file" || $file =~/cluster$/){
          print `mv $inputfile/$file $inputfile/orig/$file`;
       }
   }  

  &output_cluster_file("$inputfile");
}

#else if a file was passed to this script
elsif (-f $inputfile)
{
  my $sents = &html2text("$inputfile");
  &text2docsent_file($sents, "$inputfile.docsent");
}


sub text2docsent_file{
my $sents = shift;
my $outfile = shift;

#remove the .html tag
$outfile =~s/\.htm[l]?\.docsent/\.docsent/;
my $filename = "";
if($outfile =~/\/([^\/]+)$/){$filename = $1;}
else{$filename = $outfile;}


open (OUTFILE, ">$outfile") or die "can't open $outfile\n";

print OUTFILE &get_docsent_header("$filename");
print OUTFILE &output_sents($sents);
print OUTFILE &get_docsent_tail;

close OUTFILE;
}


sub html2text{

my $file = shift;
my $html = &open_file("$file");
my $title =  &extract_title_from_html("$html");
my $text = &extract_text_from_html("$html");
my @sents = &split_sentences("$text");

if ($title){unshift @sents, $title;}
return(\@sents);
}

sub output{
my $file = shift;
my $title = shift;
my $sents = shift;

print "$title\n\n";

foreach $sent(@$sents){

  if ($sent =~/$final_straw/i){last;}
  my @words = split / /, $sent;

  print "$sent \n\n";

}

}

sub output_sents{
my $sents = shift;
my $par_no = 1;
my $rsnt = 1;
my $sent_no = 1;
my $ret = "";


 foreach $sent (@$sents)
 {
    if ($sent =~/$final_straw/i){last;}
 
     $ret .=  "   <S PAR='$par_no' RSNT='$rsnt' SNO='$sent_no'>$sent</S>\n";
       $par_no++;
       $sent_no++;
  }

return $ret;
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
$input =~s/[ ]+/ /g;

return $input;
}

sub output_cluster_file{
my $dir = shift;

$dir =~s/\/$//;

opendir(DIR, "$dir/docsent") or die 'cannot open directory: $inputfile';
   my @docs = readdir(DIR);
   closedir(DIR);

open (OUTFILE, ">$dir/$dir.cluster") || die "Can't open cluster file\n";
     
print OUTFILE &get_cluster_header;

  foreach $doc (@docs)
   {
      $doc =~s/\.docsent$//;
      unless (-d "$dir/$doc" || $doc =~/.cluster$/){
        print OUTFILE "     <D DID=\"$doc\" \/>\n";
        }
    }

print OUTFILE &get_cluster_tail;

close OUTFILE;
}



