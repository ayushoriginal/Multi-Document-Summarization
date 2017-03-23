#!/usr/bin/perl
# mead_lite - bidirectional mead forking client

#use strict;
use IO::Socket;
my ($host, $port, $kidpid, $handle, $line, $infile, $element, $format_html, $format_text, @file_list, $input_directory, $info);

######
#THESE are to help with cacheing and with the communication protocol between the client and
#the server
######
$path = "/clair6/projects/meadserver";
$unique_request_counter = 0;
$request_type = "";
$info = "<REQUEST>\n";
$cache_file_hash = "$path/.mead_lite/request.hash";
$rcfile;
%cache_hash;
####
#End of globals
####

#$infile = shift(@ARGV);

my $cache_dir = &make_cache_dir();
my $files_in_cache = `ls $path/.mead_lite`;
my @seperate_files = split(/\n/, $files_in_cache);
foreach (@seperate_files){
    $unique_request_counter++;
}

my %arguments = &process_command_line(@ARGV);

#This sets up the request hash
open (cache_file, "<$cache_file_hash") or die "FAILED TO OPEN FILE $cache_file_hash\n";
my @fileRay = <cache_file>;
close(cache_file);
foreach (@fileRay){
    (my $key, my $value) = split(/, /, $_);
    chomp($value);
    $classifier_hash{$key} = $value;
}

if( !($classifier_hash{$request_type} eq "") ){
    print STDERR "[Connected to $host:$port]\n";
    print `cat $classifier_hash{$request_type}`;
    exit(0);
}

$info .= "<POLICY>\n".$rcfile."</POLICY>\n";

$input_directory = "";
$format_html = 0;                                         
$format_text = 0;                                                       
      
foreach $element(keys %arguments){
    if($element =~ /dir/){
	$input_directory = $arguments{$element};
    }
    elsif($element =~ /files/){
#        $files = $arguments{$element};
	@file_list = split(/\#\#\#/, $arguments{$element});
    }
    elsif($element =~ /html/){
        $format_html = 1;
    }
    elsif($element =~ /text/){
        $format_text = 1;
    }
}

# create a tcp connection to the specified host and port
$handle = IO::Socket::INET->new(Proto     => "tcp",
                                PeerAddr  => $host,
                                PeerPort  => $port)
       or die "can't connect to port $port on $host: $!";

$handle->autoflush(1);              # so output gets there right away
print STDERR "[Connected to $host:$port]\n";

# split the program into two processes, identical twins
die "can't fork: $!" unless defined($kidpid = fork());

if ($kidpid) {                      
    # parent copies the socket to standard output
    my $chachedFile_name = "$path/.mead_lite/"."REQUEST".$unique_request_counter;
    open (cachedFile, ">$chachedFile_name") or die "FAILED TO MAKE FILE $chachedFile_name\n";
    while (defined ($line = <$handle>)) {
	last if ($line eq "</SUMMARY>\n");        
	if( !($line eq "<SUMMARY>\n") ){ 
	    print STDOUT $line;
	    print cachedFile $line;
        }
    }
    close(cachedFile);
    open (cache_file, ">>$cache_file_hash") or die "FAILED TO OPEN FILE $cache_file_hash\n";
    print cache_file "$request_type, $chachedFile_name\n";
    $handle->shutdown(2); 
#    print "DONE - process1!\n";
    kill("TERM" => $kidpid);        # send SIGTERM to child
}
else {                              
    # child copies standard input to the socket
#    while (defined ($line = <STDIN>)) {
#        print $handle $line;
#    }
    
    #do all of the pre-packageing stuff
    $infile = "";
    if( $input_directory ){
	chdir("$input_directory");
	my $files = `ls`;
	my @filearray = split( /\n/, $files );
	print $handle $info;

	foreach (@filearray ) {
	    
	    open (INPUT, "<$_") || die "could not open filehandle $_";
	    my @file_contents = <INPUT>;
	    close(INPUT);

	    print $handle "<DOCUMENT>\n";
	   
	    foreach my $file_line (@file_contents){
	       print $handle $file_line;
	   }
	    print $handle "\n";
	    print $handle "</DOCUMENT>\n";

	}
	print $handle "</REQUEST>\n";
    }

}
exit;


sub make_cache_dir
{
    $already_there = `ls -A | grep ".mead_lite"`;
    chomp($already_there);
    if($already_there eq ".mead_lite"){
    }
    else{
	`mkdir .mead_lite`;
	`touch $cache_file_hash`;
    }
    return ".mead_lite";
}

sub process_command_line
{
     my @params = @_;
     my $p;
     my %retVals;

     my $directory = "";
     my $output_type = ""; 
     my $compression_type = ""; 
     my $compression_percent = 20;
     my $compression_absolute = 20;
     my $feature = "";
     my $absolute_classifier = "";
     my $absolute_query = "";
     my $system = "";
     my $files_in_dir = "";
     
     while (1) {
         $p = shift @params;
         last unless $p =~ /^-/;
	 
	 #NOTE: I am not error checking on the last value ie I should check if they have a flag set that itsn't followed by a an appropriate filenam\
	 
	 if ($p =~ /^-d(irectory)?$/) {
	     $retVals{dir} = double_shift(\@params);
	     my $temp_dir = $retVals{dir}; 
	     my $dir_files = `ls $temp_dir`;
	     my @files = split(/\n/, $dir_files);
	     foreach (@files){
		 $files_in_dir .= $_;
	     }
	 }elsif ($p =~ /^-f(iles)?$/) {
	     $retVals{files} = " ";
	     foreach my $file_Name(@params){
		 $retVals{files} .= $file_Name."###";
		 
	     }
	 }elsif ($p =~ /^-h(elp)?$/) {
	     &show_help();
	     exit(0);
	 }elsif ($p =~ /^-html?$/) {
	     $retVals{html} = 0;
	 }elsif ($p =~ /^-t(ext)?$/) {
	     $retVals{text} = 0;
	 }elsif ($p =~ /^-summary?$/) {
	     $output_type = "summary";
	     $rcfile .= "output_mode\tsummary\n";
	 }elsif ($p =~ /^-extract?$/) {
	     $output_type = "extract";
	     $rcfile .= "output_mode\textract\n";
	 }elsif ($p =~ /^-s(entences)?$/) {
	     $rcfile .= "compression_basis\tsentences\n";
	     $compression_type = "sentences";
	 }elsif($p =~ /^-server?$/) {
	     $host = double_shift(\@params);
	 }elsif($p =~ /^-host?$/) {
	     $host = double_shift(\@params);
	 }elsif($p =~ /^-port?$/) {
	     $port = double_shift(\@params);
	 }elsif ($p =~ /^-w(ords)?$/) {
	     $rcfile .= "compression_basis\twords\n";
	     $compression_type = "words";
   	 }elsif ($p =~ /^-(compression_)?p(ercent)?$/) {
	     $rcfile .= "compression_percent\t";
	     $compression_percent = double_shift(\@params);
	     $rcfile .= "$compression_percent\n";
	 } elsif ($p =~ /^-(compression_)?a(bsolute)?$/) {
	     $rcfile .= "compression_absolute\t";
	     $compression_absolute = double_shift(\@params);
	     $rcfile .= "$compression_absolute\n";
	 } elsif ($p =~ /^-system?$/) {
	     $system = double_shift(\@params);
	     $rcfile .= "system\t$system\n";
	 } elsif ($p =~ /^-RANDOM$/) {
	     $rcfile .= "system\tRANDOM\n";
	     $system = "RANDOM";
	 } elsif ($p =~ /^-LEADBASED$/) {
	     $rcfile .= "system\tLEADBASED\n";
	     $system = "LEADBASED";
	 } elsif ($p =~ /^-f(eature)?$/) {
	     my $name = double_shift(\@params);
	     $feature = $name;
	     $rcfile .= "feature $name\n";
	 } elsif ($p =~ /^-c(lassifier)?$/) {
	     my $classifier = "";
	     while(defined(my $attributes = shift @params)){
		 my $array = $params[0];
		 my $classifier_end = 0;
		 if (defined ($array) ){
		     if ( $array =~ /^-/ ){
			 $classifier_end = 1;
		     }
		 }
		 $absolute_classifier .= $attributes;
		 $classifier .= " ".$attributes;
		 last if  ($classifier_end == 1);
	     }
	     $rcfile .= "classifier$classifier\n";
	 } elsif ($p  =~ /^-q(uery)?$/) {
	     my $query = "";
	     while(defined(my $attributes = shift @params)){
		 my $array = $params[0];
		 my $classifier_end = 0;
		 if (defined ($array) ){
		     if ( $array =~ /^-/ ){
			 $classifier_end = 1; 
		     }
                 }  
		 $absolute_query .= $attributes;
		 $query .= $attributes." ";
		 last if  ($classifier_end == 1);    
	     }  
	     $rcfile .= "<NUTCHQ>\n<QUERY>\n<TITLE>$query</TITLE>\n<NARRATIVE>$query</NARRATIVE>\n<DESCRIPTION>$query</DESCRIPTION>\n</QUERY>\n</NUTCHQ>\n";
	 }
	 else{
	     print "Unrecognized flag $p exiting try -h for help\n";
	     exit(0);
	 }
     }

     $request_type = $directory.$output_type.$compression_type.$compression_percent.$compression_absolute.$feature.$absolute_classifier.$absolute_query.$system.$host.$port.$files_in_dir;

     %retVals;
 }


sub double_shift {
    my $array = $_[0];
    if (@$array == () ||  $$array[0] =~ /^-/) {
        show_help();
        exit(1);
    }
    return shift @$array;
}


sub show_help {
                                                                                                                                                             
print <<EOHELP
Usage:
                                                                                                                                                             
./mead_lite.pl [options]
                                                                                                                                                             
Available options are:
                                                                                                                                                             
 -d (for the text directory to summarize)   
 -server
 -port
 -summary
 -extract
 -output_mode mode  (summary|extract)
 -sentences, -s
 -words, -s
 -basis basis (words|sentences)
 -percent, -p
 -absolute, -a
 -system name  (including RANDOM and LEADBASED)
 -RANDOM
 -LEADBASED
 -feature name commandline
 -classifier commandline
 -reranker commandline
 -d directory name
 -help
                                                                                                                                                             
For the semantics and interpretation of these options, please
consult the mead_lite README.
                                                                                                                                                             
EOHELP
}
