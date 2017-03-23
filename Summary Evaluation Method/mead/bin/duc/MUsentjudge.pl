#!/usr/local/bin/perl -w

use strict;
use XML::TreeBuilder;
use HTML::TreeBuilder;
use XML::Element;
use XML::Writer;
use IO;

die "USAGE: $0 [cluster]\n  example: ./MUsentjudge.pl d061j\n"
	 if $#ARGV < 0;

my %idf = ();
dbmopen %idf, "/clair3/projects/nsir/trec2002/lib/NSIR/nidf", 0666
  or die "Can't read idf: $!\n";

my $cluster = shift;
my $docsentDir = "/clair4/projects/duc03/clusters/duc02/alltypes/$cluster/docsent";
my $modelunitDir = "/clair4/projects/duc03/duc2002-results/SEEmodels/SEE.edited.abstracts.in.edus";
my $MUsentjudgeDir = "/clair4/projects/duc03/hong/MUsentjudge";

my $clusterFile = "/clair4/projects/duc03/clusters/duc02/alltypes/$cluster/$cluster.cluster";

`mkdir $MUsentjudgeDir` unless (-d "$MUsentjudgeDir");

print "processing $cluster...\n";

#`mkdir $MUsentjudgeDir/$cluster` unless (-d "$MUsentjudgeDir/$cluster");

my $output = new IO::File(">$MUsentjudgeDir/$cluster.sentjudge");
	 

my $writer = new XML::Writer(DATA_MODE => 1, DATA_INDENT => 2, OUTPUT => $output);
$writer->xmlDecl('UTF-8');
$writer->doctype("SENT-JUDGE", "", "/clair4/projects/mead307/stable/mead/dtd/sentjudge.dtd");
$writer->startTag("SENT-JUDGE",
						"QID" => $cluster);


my $clustertree = XML::TreeBuilder->new();
$clustertree->parse_file("$clusterFile");

my $docID;

foreach my $doc ($clustertree->find_by_tag_name("D")) {
	 $docID = $doc->attr_get_i('DID');
	 my $docsent = $docID.".docsent";

	 my $MUcluster = $cluster;
	 $MUcluster =~ s/d(\d\d\d)./D$1/;
	 
	 opendir(MU, "$modelunitDir") || die "cannot open dir $modelunitDir\n";
	 my @MUfiles = grep { /$MUcluster.*$docID/ } readdir(MU);
	 closedir (MU);

	 my %modelunits = ();

	 foreach my $MUfile (@MUfiles) {

		  my $judge = $MUfile;
		  
		  #naming: D120.P.100.I.J.LA122190-0149.html
		  $judge =~ s/^.*?\..\..*?\..\.(.*?)\..*$/$1/;

		  my $tree = HTML::TreeBuilder->new();
		  $tree->parse_file("$modelunitDir/$MUfile");

		  foreach my $sent ( $tree->look_down( 
															"_tag", "a",
															sub { defined($_[0]->attr('id')) } 
															) ) {

				my @sentContent = $sent->content_list;
				
				my @words = split(/\W+/, $sentContent[0]);


				foreach my $word (@words) {
					 
					 my $lcword = lc($word);
					 $modelunits{$judge}{$lcword}{idf} = $idf{$lcword} || 5
						  unless (exists $modelunits{$judge}{$lcword});
					 
					 $modelunits{$judge}{$lcword}{freq}++;
				}
				
		  }
		  
		  $tree->delete;
		  
	 }

	 my $tree = XML::TreeBuilder->new();
	 $tree->parse_file("$docsentDir/$docsent");


	 foreach my $sent ($tree->find_by_tag_name("S")) {
		  my $SNO = $sent->attr_get_i('SNO');
		  my $PAR = $sent->attr_get_i('PAR');
		  my $RSNT = $sent->attr_get_i('RSNT');

		  $writer->startTag("S",
								  "DID" => $docID,
								  "SNO" => $SNO,
								  "PAR" => $PAR,
								  "RSNT" => $RSNT);
		  
		  my @sentContent = $sent->content_list;
		  
		  my @words = split (/\W+/, $sentContent[0]);
		  
		  
		  foreach my $judge (keys %modelunits) {
				
				my $util = compute_util($judge, \@words, \%modelunits);

				
				$writer->emptyTag("JUDGE",
										"N" => $judge,
										"UTIL" => $util);

		  }

		  $writer->endTag("S");
	 }

	 $tree->delete;

}

	 $writer->endTag();
	 $writer->end();




sub compute_util{
	 my $judge = shift;
	 my $ref_words = shift;
	 my $ref_modelunits = shift;


	 ##  @words against $modelunits{$judge}

	 my $numerator = 0;
	 my $denominator = 0;
	 
	 foreach my $word (@{$ref_words}) {

		  my $lcword = lc($word);
		  if (exists $$ref_modelunits{$judge}{$lcword}) {
				$numerator += $$ref_modelunits{$judge}{$lcword}{idf} * log($$ref_modelunits{$judge}{$lcword}{freq});
				$denominator += $$ref_modelunits{$judge}{$lcword}{idf} * log($$ref_modelunits{$judge}{$lcword}{freq});
		  } else {
				$denominator += $idf{$lcword} || 5;
		  }
	 }

	 $denominator = 1 if $denominator==0;

	 my $util = $numerator/$denominator*10;

	 return $util;
	 
}
