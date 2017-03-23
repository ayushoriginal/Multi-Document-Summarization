#!/usr/local/bin/perl -w

use strict;
use XML::TreeBuilder;
use HTML::TreeBuilder;
use XML::Element;
use XML::Writer;
use IO;

die "USAGE: $0 [task] [cluster]\n  example: ./MUsentjudge.pl 2 d30003t\n"
	 if $#ARGV < 1;

my %idf = ();
dbmopen %idf, "/clair3/projects/nsir/trec2002/lib/NSIR/nidf", 0666
  or die "Can't read idf: $!\n";

my $task = shift;
my $cluster = shift;

#### For DUC 2002 ####
#my $docsentDir = "/clair4/projects/duc03/clusters/duc02/alltypes/$cluster/docsent";
#my $modelunitDir = "/clair4/projects/duc03/duc2002-results/SEEmodels/SEE.edited.abstracts.in.edus";
#my $MUsentjudgeDir = "/clair4/projects/duc03/hong/MUsentjudge";

#### For DUC 2003 ####
##/clair4/projects/duc03/clusters/duc03/task2/docs/d30003t/docsent
my $docsentDir = "/clair4/projects/duc03/clusters/duc03/task$task/docs/$cluster/docsent";
my $modelunitDir = "/clair4/projects/duc03/duc2003.manual.abstracts";
my $MUsentjudgeDir = "/clair4/projects/duc03/hong/MUsentjudge-2003";

my $clusterFile = "/clair4/projects/duc03/clusters/duc03/task$task/docs/$cluster/$cluster.cluster";

`mkdir $MUsentjudgeDir` unless (-d "$MUsentjudgeDir");

print "processing $cluster...\n";

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
	 $MUcluster =~ s/d?(\d+)[a-z]?/D$1/;
	 
	 opendir(MU, "$modelunitDir") || die "cannot open dir $modelunitDir\n";
	 my @MUfiles = grep { /$MUcluster.M/ } readdir(MU);
	 closedir (MU);

	 my %modelunits = ();

	 foreach my $MUfile (@MUfiles) {

		  my $judge = $MUfile;
		  
		  #naming: D100.M.100.A.H
		  $judge =~ s/^.*?\.M\.100\..\.(.)$/$1/;

		  #my $tree = HTML::TreeBuilder->new();
		  #$tree->parse_file("$modelunitDir/$MUfile");

		  #foreach my $sent ( $tree->look_down( 
			#												"_tag", "a",
			#												sub { defined($_[0]->attr('id')) } 
			#												) ) {

		  open (MU, "$modelunitDir/$MUfile") || die "cannot open $modelunitDir/$MUfile\n";
		  while (<MU>) {
				chomp;
				my @words = split(/\W+/);

				foreach my $word (@words) {
					 my $lcword = lc($word);
					 $modelunits{$judge}{$lcword}{idf} = $idf{$lcword} || 5
						  unless (exists $modelunits{$judge}{$lcword});
					 
					 $modelunits{$judge}{$lcword}{freq}++;
				}
				
		  }
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
