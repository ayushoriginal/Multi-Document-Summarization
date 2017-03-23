package MEAD::MEAD_ADDONS_UTIL;

use HTML::Parser;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(
             split_sentences
	     extract_title_from_html
             extract_text_from_html
             get_docsent_header
	     get_docsent_tail
             get_cluster_header
             get_cluster_tail
	     sanitize
);

#my $DTD_DIR ="/clair7/projects/mead309/mead/dtd";
my $DTD_DIR ="/data0/projects/mead310/mead/dtd";



my %abbrevs = ();
&load_abbrevs;

#used by split_sentences
my $min_words = 1;
#my $sentends = '\?\.\!';
my $sentends = '';
#my $final_straw = "All Rights Reserved|contributed to this report";

#used by extract text from html
my $split_on = "span|option|hr|br|p|td|th";
my $html_or_body ="body";


#these are global variables used by extract_text_from_html and 
#its subroutines.
#When time permits, rewrite so they aren't necessary
my $doc = ();
my %inside = ();

#optionally: div|


sub extract_title_from_html {
    my $html = shift;
    $html =~/<title[^>]*?>(.*?)<\/title>/i;
    my $title = $1;
    return &sanitize($title);
  
}

sub extract_text_from_html {
    my $string = shift;
    $doc = "";
    %inside = ();
    my $html = ();
  
  if (length $html_or_body > 0) {
     $string =~/<$html_or_body[^>]*?>(.+)<\/$html_or_body>/i;
     if($1){$html = $1;}
     else {$html = $string;}
  }

    else {$html = $string;}

&first_parse($html);
$doc = &sanitize($doc);
$doc = &convert_returns($doc);
return $doc;
}
  
sub tag  {
   my($tag, $num) = @_; 
   $inside{$tag} += $num;
   if ($tag=~/^($split_on)$/){$doc .= "\n";}
   #note that \r is added in convert_returns
   #print "$tag $num\n";  # not for all tags 
  }

sub text {
    return if $inside{script} || $inside{style};
    my $text = $_[0];
    #print "text:>>$text<<\n";
    $doc .= " $text ";
}

sub first_parse {
  my $html = shift;

  my $p = HTML::Parser->new(api_version => 3,
                   handlers    => [start => [\&tag, "tagname, '+1'"],
                                   end   => [\&tag, "tagname, '-1'"],
                                   text  => [\&text, "dtext"],
                                   ],
                   marked_sections => 1,
                   );
   $p->parse($html);
   $p->eof();  
}


sub sanitize{

my $html = shift;

#these are necessary to convert files to xml

    $html =~s/&([^#])/\&amp\;$1/g; 
    $html =~s/</\&lt\;/g;  
    $html =~s/>/\&gt\;/g;  
    $html =~s/\&\#014[56]\;/'/g;
    $html =~s/\&\#014[78]\;/"/g;
    $html =~s/\&\#[\d]+\;//g;
    $html =~s/\256/\&copy\;/g;
    #$html =~s/é/e/;
    $html =~s/[^A-Za-z \:\/\\\~\'\-\.\!\?0-9\@\,\;\"\'\_\&\#\n\r]/ /g;    
    $html =~s/[\t ]+/ /g;
    $html =~s/ ?[\n]+ ?/\n/g;
   
return $html;
}

sub convert_returns{
my $string = shift;
$string =~s/[\n]+/\r\n/g;
return $string;

}

sub split_sentences {
    my $text = shift;

    if ($text !~/[ \n\r]/){return $text;}
    
    unless (%abbrevs) {
        &load_abbrevs;
    }

#    my @split = &Text::Sentence::split_sentences($text);
    $text =~s/([.!?]+["']*)[ ]+([^a-z])/$1\n$2/g; 
    my @split = split /\n/, $text; 
    my @final;
    my $temp;
        
    while (@split) {
    my $s = shift @split;

        if ($temp) {
            $temp .= " " . $s;
        } else {
            $temp = $s;
        }
    
        # get the last word (if the sentence ends in a period).
        $temp =~/([\w]+)\.\s*$/;#old
        my $lw = $1;

        if ($lw && $abbrevs{$lw} && $temp !~/\r/) {
            # do nothing. 
            #print "doing nothing with $lw\n";
        } elsif ($temp =~/[\w\d]+/) {
            push @final, $temp;
            $temp = "";
        }
    }
    
my @reallyfinal = ();

foreach $sent (@final)
 { 
    $sent =~s/\r//g;
    $sent =~s/[ ]+/ /g;
    $sent =~s/^ | $//g;
   my @words = split / /, $sent;
   #print "$sent: $#words\n";
   if ($final_straw && $sent =~/$final_straw/){last;}
   if ($#words >= ($min_words - 1) && $sent =~/[$sentends]["']?$/){
      push @reallyfinal, $sent;
    }
  } 

return @reallyfinal;  
}   



sub get_docsent_header{
my $filename = shift;

$filename =~s/\.docsent$//;

my $header =
"<?xml version='1.0'?>
<!DOCTYPE DOCSENT SYSTEM \"$DTD_DIR/docsent.dtd\">
 <DOCSENT DID='$filename'>
  <BODY>
   <TEXT>\n";

return $header;
}

sub get_docsent_tail {

$tail = "   </TEXT>
  </BODY>
</DOCSENT>";

return $tail;
}
             
sub get_cluster_header {
my $lang = shift;

unless ($lang =~/./){$lang = "ENG";}

my $header = "<?xml version='1.0'?>
<CLUSTER LANG=\"$lang\">\n";

return $header;

}

sub get_cluster_tail {

my $tail = "</CLUSTER>     \n";

return $tail;

}

sub load_abbrevs{

$abbrevs{A} = 1;
$abbrevs{a} = 1;
$abbrevs{Adm} = 1;
$abbrevs{al} = 1;
$abbrevs{Ala} = 1;
$abbrevs{Alta} = 1;
$abbrevs{'a.m'} = 1;
$abbrevs{Apr} = 1;
$abbrevs{Ariz} = 1;
$abbrevs{Ark} = 1;
$abbrevs{Assn} = 1;
$abbrevs{AST} = 1;
$abbrevs{Atty} = 1;
$abbrevs{Aug} = 1;
$abbrevs{Ave} = 1;
$abbrevs{B} = 1;
$abbrevs{Bancorp} = 1;
$abbrevs{Bankcorp} = 1;
$abbrevs{Bhd} = 1;
$abbrevs{bn} = 1;
$abbrevs{Bros} = 1;
$abbrevs{C} = 1;
$abbrevs{Calif} = 1;
$abbrevs{Capt} = 1;
$abbrevs{cent} = 1;
$abbrevs{Cia} = 1;
$abbrevs{Cie} = 1;
$abbrevs{Cmdr} = 1;
$abbrevs{co} = 1;
$abbrevs{Co} = 1;
$abbrevs{CO} = 1;
$abbrevs{Col} = 1;
$abbrevs{Colo} = 1;
$abbrevs{Conn} = 1;
$abbrevs{conv} = 1;
$abbrevs{Corp} = 1;
$abbrevs{CORP} = 1;
$abbrevs{Cos} = 1;
$abbrevs{D} = 1;
$abbrevs{Dec} = 1;
$abbrevs{Del} = 1;
$abbrevs{dept} = 1;
$abbrevs{Dept} = 1;
$abbrevs{Dist} = 1;
$abbrevs{Dr} = 1;
$abbrevs{Drs} = 1;
$abbrevs{E} = 1;
$abbrevs{ed} = 1;
$abbrevs{e} = 1;
$abbrevs{Elec} = 1;
$abbrevs{end} = 1;
$abbrevs{et} = 1;
$abbrevs{etc} = 1;
$abbrevs{Etc} = 1;
$abbrevs{F} = 1;
$abbrevs{Feb} = 1;
$abbrevs{Fla} = 1;
$abbrevs{Fri} = 1;
$abbrevs{G} = 1;
$abbrevs{g} = 1;
$abbrevs{Ga} = 1;
$abbrevs{Gen} = 1;
$abbrevs{Gov} = 1;
$abbrevs{H} = 1;
$abbrevs{hr} = 1;
$abbrevs{I} = 1;
$abbrevs{Ia} = 1;
$abbrevs{Ida} = 1;
$abbrevs{ie} = 1;
$abbrevs{Ill} = 1;
$abbrevs{in} = 1;
$abbrevs{inc} = 1;
$abbrevs{Inc} = 1;
$abbrevs{INC} = 1;
$abbrevs{Ind} = 1;
$abbrevs{J} = 1;
$abbrevs{Jan} = 1;
$abbrevs{Jr} = 1;
$abbrevs{Jul} = 1;
$abbrevs{Jun} = 1;
$abbrevs{K} = 1;
$abbrevs{Kans} = 1;
$abbrevs{Ken} = 1;
$abbrevs{Kft} = 1;
$abbrevs{km} = 1;
$abbrevs{L} = 1;
$abbrevs{La} = 1;
$abbrevs{lbs} = 1;
$abbrevs{Lt} = 1;
$abbrevs{Ltd} = 1;
$abbrevs{m} = 1;
$abbrevs{M} = 1;
$abbrevs{Maj} = 1;
$abbrevs{Mar} = 1;
$abbrevs{Mass} = 1;
$abbrevs{Md} = 1;
$abbrevs{Me} = 1;
$abbrevs{Mfg} = 1;
$abbrevs{mg} = 1;
$abbrevs{Mich} = 1;
$abbrevs{mill} = 1;
$abbrevs{min} = 1;
$abbrevs{Minn} = 1;
$abbrevs{Miss} = 1;
$abbrevs{Mo} = 1;
$abbrevs{Mon} = 1;
$abbrevs{Mont} = 1;
$abbrevs{mph} = 1;
$abbrevs{Mr} = 1;
$abbrevs{MR} = 1;
$abbrevs{Mrs} = 1;
$abbrevs{Ms} = 1;
$abbrevs{N} = 1;
$abbrevs{Nebr} = 1;
$abbrevs{Nev} = 1;
$abbrevs{Nfld} = 1;
$abbrevs{no} = 1;
$abbrevs{No} = 1;
$abbrevs{Nov} = 1;
$abbrevs{O} = 1;
$abbrevs{Oct} = 1;
$abbrevs{Ont} = 1;
$abbrevs{Ore} = 1;
$abbrevs{P} = 1;
$abbrevs{Pa} = 1;
$abbrevs{ParCorp} = 1;
$abbrevs{pct} = 1;
$abbrevs{Pct} = 1;
$abbrevs{pds} = 1;
$abbrevs{Penn} = 1;
$abbrevs{Pf} = 1;
$abbrevs{PLC} = 1;
$abbrevs{'p.m'} = 1;
$abbrevs{'P.M'} = 1;
$abbrevs{Prof} = 1;
$abbrevs{Pte} = 1;
$abbrevs{pts} = 1;
$abbrevs{Pty} = 1;
$abbrevs{Q} = 1;
$abbrevs{Que} = 1;
$abbrevs{R} = 1;
$abbrevs{rd} = 1;
$abbrevs{Rep} = 1;
$abbrevs{REP} = 1;
$abbrevs{Reps} = 1;
$abbrevs{Rev} = 1;
$abbrevs{"R-Wis"} = 1;
$abbrevs{s} = 1;
$abbrevs{S} = 1;
$abbrevs{SA} = 1;
$abbrevs{Sask} = 1;
$abbrevs{SCEcorp} = 1;
$abbrevs{Sen} = 1;
$abbrevs{Sep} = 1;
$abbrevs{Sept} = 1;
$abbrevs{Sgt} = 1;
$abbrevs{sq} = 1;
$abbrevs{Sr} = 1;
$abbrevs{SR} = 1;
$abbrevs{St} = 1;
$abbrevs{Sun} = 1;
$abbrevs{Supt} = 1;
$abbrevs{T} = 1;
$abbrevs{Tenn} = 1;
$abbrevs{Tex} = 1;
$abbrevs{th} = 1;
$abbrevs{Thu} = 1;
$abbrevs{Tue} = 1;
$abbrevs{U} = 1;
$abbrevs{Univ} = 1;
$abbrevs{Ur} = 1;
$abbrevs{v} = 1;
$abbrevs{V} = 1;
$abbrevs{Va} = 1;
$abbrevs{vol} = 1;
$abbrevs{Vol} = 1;
$abbrevs{vs} = 1;
$abbrevs{Vt} = 1;
$abbrevs{W} = 1;
$abbrevs{Wash} = 1;
$abbrevs{Wed} = 1;
$abbrevs{Wis} = 1;
$abbrevs{Wyo} = 1;
$abbrevs{X} = 1;
$abbrevs{Y} = 1;
$abbrevs{yr} = 1;
$abbrevs{Yr} = 1;
$abbrevs{Z} = 1;

}

1;
