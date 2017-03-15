# convert rouge results to csv. 
#
# -------------------------------------------------------------------------------------------------
#  Copyright 2010 Kavita Ganesan
# --------------------------------------------------------------------------------------------------
# Licensed under the Apache License, Version 2.0 (the "License");  may not use this file except in compliance with the License. 
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0 
# Unless required by applicable law or agreed to in writing, software distributed under the 
# License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
# See the License for the specific language governing permissions and limitations under the License. 
#----------------------------------------------------------------------------------------------------------------------------

if($#ARGV < 1){
	print "\nUsage: perl rouge2csv.pl <results file>  <csv filename prefix>\n";
} else {

	my $entry=0;
	my %results_p;
	my %results_f;
	my %results_r;
	my %counter;


# Supposing the first arg passed in is my filename:
	my $filename = $ARGV[0];
	my $prefix = uc $ARGV[1];
	my $key="";
	my @value;
	my $rougeid="";

	open(INPUT_FILE, $filename)
		or die "Couldn't open rouge file, $filename for reading";
	while (<INPUT_FILE>) {
		my $line = $_;
		#if new line then new entry
		if($line=~ m/(----------)/ig)
		{
			if(length $key > 0){
				
		   # there was a previous entry, lets write i
		    
			
			if (exists($results_r{$key}) ) {
				$results_r {$key}=$results_r{$key}+$value[0];
				$results_p{$key}=$results_p{$key}+$value[1];
				$results_f {$key}=$results_f{$key}+$value[2];
				$counter{$key}=$counter{$key}+1;	
			}
			else{
				$counter{$key}=1;
				$results_r {$key}=$value[0];
				$results_p{$key}=$value[1];
				$results_f {$key}=$value[2];
			}
				#print "\nThe key is : $key\t\t".$counter{$key} ;
			}

			#print "\n".$key."_".$rougeid."  ::  " . $counter{$key."_".$rougeid}."\n";
			
			#&writeToFile($allVal,$key,$rougeid,$prefix);
		    $allVall="";
			$key="";
			$entry=0;
			$rougeid="";

		}else{
			

			my @tokens=split(" ", $line);

			my $runid=$tokens[0];
			my $rouge=$tokens[1];
			my $measure=$tokens[2];
			@value[$entry]=$tokens[3];

			

			
			if($entry == 1){
				$allVal=$value;
			}else{
				$allVal="$allVal,$value";
			}
			$key=$runid."_".$rouge;
			$rougeid=$rouge;
			$entry++;
		}
	}
	close(INPUT_FILE);

if(length $key > 0){
	if (exists($results_r{$key}) ) {
				$results_r {$key}=$results_r{$key}+$value[0];
				$results_p{$key}=$results_p{$key}+$value[1];
				$results_f {$key}=$results_f{$key}+$value[2];
				$counter{$key}=$counter{$key}+1;	
	}
	else{
			$counter{$key}=1;
			$results_r {$key}=$value[0];
			$results_p{$key}=$value[1];
			$results_f {$key}=$value[2];
	}
}
	my $cnt=1;
	foreach $j (sort(keys %counter)) 
	{
		
		my $avg_r=eval($results_r {$j}/$counter{$j});
		my $avg_p=eval($results_p {$j}/$counter{$j});
		my $avg_f=eval($results_f {$j}/$counter{$j});


		

	#print "$j\n\n";
#	print $cnt++."\n";
#	print $j."rec:".$avg_r."\n";
#	print $j."prec:".$avg_p."\n";
#	print $j."fscore:".$avg_f."\n\n\n";

		
		my @vals = split('.*_.*ROUGE', $j);
		$filename = $prefix."_ROUGE"."$vals[1]".".csv";
		$filename =~ tr/\*/X/;

		
		
		if (-e $filename) {
			open(FILE, ">>$filename") or die "can't find the file: $file. \n";
		}else{
			print $filename."\n";
			open(FILE, ">$filename") or die "can't find the file: $file. \n";
			print FILE "runid,recall,precision,f-score\n";
		}
		
		print FILE "$j,$avg_r,$avg_p,$avg_f\n";
		close(FILE);
	}

		print "Done...Check current working directory for output.\nIf you reused an old prefix, the results have been appended to that file.";	

}




sub writeToFile{
 my ($value,$run,$rougeid,$pfx)=@_;
	
	if(length $run > 0){
		$filename = $pfx."_"."$rougeid".".csv";
		$filename =~ tr/\*/X/;
		
		
		if (-e $filename) {
			open(FILE, ">>$filename") or die "can't find the file: $file. \n";
		}else{
			print $filename."\n";
			open(FILE, ">$filename") or die "can't find the file: $file. \n";
			print FILE "runid,recall,precision,f-score\n";
		}
		
		print FILE "$run,$value\n";
		close(FILE);
   }
}
