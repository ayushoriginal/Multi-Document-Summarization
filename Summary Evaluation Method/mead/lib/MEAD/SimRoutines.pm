package MEAD::SimRoutines;
use strict;
use Exporter;
our (@EXPORT, @ISA);
@ISA = qw(Exporter);
@EXPORT = qw( GetLexSim cosine uniq %sim_routines $lang );
use Essence::IDF;

use vars '%sim_routines';
use vars '$lang';

$sim_routines{'MEAD-cosine'}=\&GetLexSim;

sub GetLexSim{

    my $seed_text = shift;
    my $seed_text2 = shift;

    my %count1 = ();

	#(John, 07/05/01)
	my @words = split (/\s|\,|¡@|¡]|¡\^|¡A|¡B|¡C|¡u|¡m|¡n|¡F|¡þ|¡v|¡G|¡H|¡S|¡T|¡I|\?|\!|¡§|¡¨|¡y|¡z/,$seed_text);
	
    if (!$lang){$lang = "ENG";}

    for (@words) {
	    next if /^$/;
            ##only make things lowercase if we're dealing with English
	    if ($lang eq 'CHIN'){$count1{$_}++;}
	    elsif ($lang eq 'ENG'){$count1{lc($_)}++;}
	    else{ die("LANG: $lang not recognized");}
	}

	my %count2 = ();

	#(John, 07/05/01)
	@words = split (/\s|\,|¡@|¡]|¡\^|¡A|¡B|¡C|¡u|¡m|¡n|¡F|¡þ|¡v|¡G|¡H|¡S|¡T|¡I|\?|\!|¡§|¡¨|¡y|¡z/,$seed_text2);

    for (@words) {
	next if /^$/;
        ##only make things lowercase if we're dealing with English
        if ($lang eq 'CHIN'){$count2{$_}++;}
        elsif ($lang eq 'ENG'){$count2{lc($_)}++;}
        else{ die("LANG: $lang not recognized");}
    }

	my $ref1 = \%count1;
	my $ref2 = \%count2;

	my $sim = &cosine ($ref1,$ref2);
	return $sim;
}

sub cosine {

    my $ref1 = shift;
    my $ref2 = shift;

    my %count1 = %$ref1;
    my %count2 = %$ref2;
	#hash which maps a term to its importance in the lexsim comp
    my %countC = ();

    my @words = &uniq (sort ((keys %count1), (keys %count2)));

    my $rs1 = 0;
    my $rs2 = 0;
    my $c = 0;

    my $c1 = 0; my $c2 = 0; my $idf = 0;

    foreach my $wd (@words) {

        $c1 = $count1{$wd} || 0;
        $c2 = $count2{$wd} || 0;

        $idf = get_nidf($wd) || 1;

        $c1 = $c1 * $idf;
        $c2 = $c2 * $idf;

        $c += $c1 * $c2;

	$countC{$wd} = $c1 * $c2;

        $rs1 += $c1 * $c1;
        $rs2 += $c2 * $c2;

    }

    #compute a list of which words are having the greatest effect
    my @keys = sort{$countC{$b} <=> $countC{$a}} (keys %countC);

    my $key_no = 0;
    my $val = 0;

    foreach my $key (@keys)    
    {   
    	$val = $countC{$key};
    	$c1 = $count1{$key} || 0;
    	$c2 = $count2{$key} || 0;
    	$idf = get_nidf($key) || 1;
    }

    my $r = sqrt ($rs1 * $rs2);


	if ($r == 0)
	{
		return (0);
	}
	else
	{
		return $c/$r;
	}   
}

sub uniq {

    my $old = "";
    my @out = ();

    for (@_) {
	push (@out, $_) unless $_ eq $old;
	$old = $_;
    }

    return @out;

}
