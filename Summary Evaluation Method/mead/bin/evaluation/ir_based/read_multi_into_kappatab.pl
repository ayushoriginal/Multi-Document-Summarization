#!/usr/bin/perl

$mode = shift;
$cluster = shift;
$length = shift;

     
if ( $cluster eq "1014" || $cluster eq "199" ||  $cluster eq "551" || $cluster eq "112"  
|| $cluster eq "241" || $cluster eq "883" || $cluster eq "1197" || $cluster eq "323" 
|| $cluster eq "125" ||$cluster eq "398" ){    
$type = "training";
}
else{   
    $type = "testing";
}
        
$mandir = "/clair6/projects/ldc/data/manual/manual_extracts/multi_document";
    
#$mandir = "/export/ws01summ/data/summaries/manual_extract_multidocument";
#$mandir = "/export/ws01summ/data/summaries/manual_extract";
$autodir = "/export/ws01summ/tmp/John/summaries/english/multidoc/GENERC/$length";
        
%decision = ();

    # GET HUMAN EXTRACT FILES

    $clusterstring = $cluster;
    if ($cluster =~ /^[0-9]$/){
        $clusterstring .= "___";
    }
    elsif ($cluster =~ /^[0-9][0-9]$/){
        $clusterstring .= "__";
    }
    elsif ($cluster =~ /^[0-9][0-9][0-9]$/){
        $clusterstring .= "_";
    }
    if ($length eq "50"){
        $length = "050";
    }
    
    $dir1 = "$mandir/$cluster/M-E-C_$clusterstring-$length-LDC_J000/extract/Group_$cluster.e.extract";
    $dir2 = "$mandir/$cluster/M-E-C_$clusterstring-$length-LDC_J001/extract/Group_$cluster.e.extract";
    $dir3 = "$mandir/$cluster/M-E-C_$clusterstring-$length-LDC_J002/extract/Group_$cluster.e.extract";

    # POSSIBLY GET AUTO EXTRACT

    if ($mode !~ /^H/){
        $dir4 = "$autodir/Group_$cluster.extract";
    }

    # GET FILES IN CLUSTER


    # OPEN Files

    ($total_sent1, $decision_1) = &read_j_file(J1, "$dir1") or die "damn $dir1";
    ($total_sent2, $decision_2) = &read_j_file(J2, "$dir2") or die "damn $dir2";
    ($total_sent3, $decision_3) = &read_j_file(J3, "$dir3") or die "damn $dir3";
 
    if ($dir4){
        ($total_sent4, $decision_4) =&read_j_file(J4, $dir4);
    }

&sanity_checks;       
&fill_zeroes;
&print_out;


sub print_out{

    open (KAPPAFILE, ">kappatab.$mode.$cluster.$length") or die;
    if ($dir4){
        print KAPPAFILE "\t\t\tJ1\tJ2\tJ3\tJ4\n";
    }
    else{
        print KAPPAFILE "\t\t\tJ1\tJ2\tJ3\n";
    }
    foreach $id (sort keys %decision){
        print KAPPAFILE "$id\t";
        foreach $judge (sort keys %{$decision{$id}}){
            print KAPPAFILE "$decision{$id}{$judge}\t";
        }
        print KAPPAFILE "\n";
    }
    close KAPPAFILE;
}

sub fill_zeroes{


foreach $id (sort keys %decision){
            unless ($decision{ "$id" }{"J1"} eq "1"){
                $decision{ "$id" }{"J1"} = "0";
            }
            #else{print "J1 sometimes has sth\n";}
            unless ($decision{ "$id" }{"J2"} eq "1"){
                $decision{ "$id" }{"J2"} = "0";
            }
            unless ($decision{ "$id" }{"J3"} eq "1"){
                $decision{ "$id" }{"J3"} = "0";
            }
            if ($dir4){
                unless ($decision{ "$id" }{"J4"} eq "1"){
                    $decision{ "$id" }{"J4"} = "0";
                    }
             }      
}


my $sents_covered = keys %decision;
$sents_covered++;

#print "sents covered: $sents_covered\n";
for ($i = $sents_covered; $i <= $total_sent1; $i++){

    $decision{"anyfile_$i"}{"J1"} = 0;
    $decision{"anyfile_$i"}{"J2"} = 0;
    $decision{"anyfile_$i"}{"J3"} = 0;
    if ($dir4){$decision{"anyfile_$i"}{"J4"} = 0;}

}

}



sub sanity_checks{
     # sanity check 1
        unless (($total_sent1 eq $total_sent2) && ($total_sent3 eq $total_sent2)){
            print STDERR "     WARNING: File $file ($total_sent1 sents vs. $total_sent2 
vs $total_sent3) sents -- $filestring)\n";
        }
        if ($dir4){
            unless ($total_sent4 eq $total_sent3){
                print STDERR "     Warning: system vs. humans not the same total sents 
(sytem$total_sent4 vs. human$total_sent3 -- $dir4/$filestring.extract vs. 
$dir3/$filestring.extract)\n";
            }
        }

        # sanity check 2
        print "d1: $decision_1 d2: $decision_2, d3: $decision_3\n";
        unless (($decision_1 eq $decision_2) && ($decision_3 eq $decision_2)){
            print STDERR "WARNING: Judges don't pick same no of sentences -- 
*$decision_1* *$decision_2* *$decision_3* -- $dir1$filestring.extract, 
$dir2$filestring.extract, $dir3$filestring.extract\n";
        }
        if ($dir4){
            unless ($decision_2 eq $decision_4){
                print STDERR "WARNING: Human judges ($decision_2) and machine 
($decision_4) don't pick same no of sentences --  $filestring Machine: 
$dir4$filestring.extract HUMAN: $dir1$filestring.extract\n";
            }
        }

        $filestring =~ s/^.*\/D?-?//;
        $file = $filestring;
}

sub read_j_file{
my $judge = shift;
my $file = shift;
my $decision_num = 0;
my $total_sent;

open ($judge, $file) or die "damn $judge:$file\n";

   while (<$judge>){
        my $id = "";
        my $file = "";

        if (/<EXTRACT.*SENTS_TOTAL=[\'\"]([0-9]+)[\"\'].*>/){
            $total_sent = $1;
        }
        if (/DID=[\"\']D?-?([^\"\']*)[\'\"]/){
            $file = $1;
        }
        if (/<S.*SNO=[\'\"]([0-9]+)[\'\"]/){
            $id = $1;
        }
        if ( $file && $id ){
            #print "Recording $judge F:$file S:$id\n";
            $decision{$file."_".$id }{"$judge"} = "1";
            $decision_num++;
            if ($decision_num > $total_sent){
                print STDERR "***$judge ($file) has invalid index $decision_num:$total_sent\n";
            }
        }
    }
    close $judge;

return ($total_sent, $decision_num);
}
