#!/usr/local/bin/perl 

use MEAD_ADDONS_UTIL qw (split_sentences get_docsent_header get_docsent_tail  
            get_cluster_header get_cluster_tail sanitize); 

my $inputfile = shift;
my $SPLITTER = shift;


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
        &text2docsent_file("$inputfile/$file", "$inputfile/docsent/$file.docsent");
        print `mv $inputfile/$file $inputfile/orig/$file`;
      }
   }  

  &output_cluster_file("$inputfile", \@files);

}

elsif (-f $inputfile)
{
  &text2docsent_file("$inputfile", "$inputfile.docsent");
}


sub text2docsent_file{
my $infile = shift;
my $outfile = shift;
my $text = &open_file($infile);

my $filename = "";

if($infile =~/\/?([^\/]+)$/){$filename = $1.".docsent";}
else{$filename = "$infile.docsent";}

open (OUTFILE, ">$outfile") or die "can't open output file: $outfile\n";

print OUTFILE &get_docsent_header("$filename");
print OUTFILE &output_sents("$text");
print OUTFILE &get_docsent_tail;

close OUTFILE;
}

sub output_cluster_file{
my $dir = shift;
my $docs = shift;

$dir =~s/\/$//;

open (OUTFILE, ">$dir/$dir.cluster") || die "Can't open cluster file\n";
     
print OUTFILE &get_cluster_header;

  foreach $doc (@$docs)
   {
      unless (-d "$dir/$doc" || $doc =~/.cluster$/){
        print OUTFILE "     <D DID=\"$doc\" \/>\n";
        }
    }

print OUTFILE &get_cluster_tail;

close OUTFILE;
}

sub open_file{

my $file = shift;
my $input = "";

local( $/ ) = undef;
   
open(FILE, "$file") or die "can't find the file: $file. \n";
      
my $input = <FILE>;

close FILE;
 
$input =~s/[\n\r]/ /g;

return $input;

}


sub output_sents{
my $text = shift;
my $added = 0;
my $par_no = 1;
my $rsnt = 1;
my $sent_no = 1;
my $ret = "";

my @sents = ();

#print "SPLITTER IN OUTPUT_SENTS: <$SPLITTER>\n";

    if ($SPLITTER !~/./){@sents = &split_sentences("$text");}
    else {@sents = split /$SPLITTER/, $text;}

    $added = 0;
    $rsnt = 1;

    foreach $sent (@sents)
     { #print "SENT: $sent\n";
       $sent = &sanitize($sent);
       $ret .=  "   <S PAR='$par_no' RSNT='$rsnt' SNO='$sent_no'>$sent</S>\n";       
       $rsnt++;
       $sent_no++;
       $added = 1;
     }
   if ($added == 1){$par_no++;}

return $ret;
}


