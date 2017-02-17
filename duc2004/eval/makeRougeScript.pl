#!/usr/local/bin/perl

# This program creates a script for ROUGE

$task = $ARGV[0];
if ($task != 1 && $task != 2 && $task != 3 && $task != 4 &&  $task != 5)
{
    die "Invalid task number ($task)\n";
}

# primary models in edus
$modelDir =  "/home/barney1/duc/duc2004/eval/models";

# all peers
$peerDir =  "/home/barney1/duc/duc2004/eval/peers";

$manualCodes = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";

# Main program ------------------------------------------------------------

makeList($modelDir, $peerDir);

print "<ROUGE_EVAL version=\"1.0\">\n";

$evalId = 0;

foreach $key (sort keys %modelHash)
{

    $evalId++;
    print "<EVAL ID=\"$evalId\">\n";

    print "<PEER-ROOT>\n";
    print "/home/barney1/duc/duc2004/eval/peers\n";
    print "</PEER-ROOT>\n";

    print "<MODEL-ROOT>\n";
    print "/home/barney1/duc/duc2004/eval/models\n";
    print "</MODEL-ROOT>\n";

    print "<INPUT-FORMAT TYPE=\"SPL\">\n";
    print "</INPUT-FORMAT>\n";


    # Don't include manual peers here since other peers can be compared
    # to all manual models, but manual peers can't.

    print "<PEERS>\n";

    foreach $peer (@{$peerHash{$key}}) 
    {

	chomp $peer;

	if ($task == 3 || $task == 4)
	{
	    ($docset,$type,$size,$selector,$summarizer,$dA,$dB,$dC,$rest) 
	    = split /\./, $peer,9;
	    $target = "$docset.$type.$size.$selector.*.$dA.$dB.$dC\n";
	}
	else
	{
	    ($docset,$type,$size,$selector,$summarizer,$dA,$dB,$rest) 
		= split /\./, $peer,8;
	    $target = "$docset.$type.$size.$selector.*.$dA.$dB\n";
	}

	# Reparse if multi-doc summary so no docid present in file name
	if ($type eq "M")
	{
	    ($docset,$type,$size,$selector,$summarizer,$rest) 
		= split /\./, $peer,6;
	    $target = "$docset.$type.$size.$selector.*\n";
	}
	
	$i = index($manualCodes,$summarizer);
	#print "SUMMARIZER=$summarizer $i\n";
	
	if (index($manualCodes,$summarizer)<0) # filter out manual peers
	{
	    print "<P ID=\"$summarizer\">$peer</P>\n";
	}
    }

    print "</PEERS>\n";
    print "<MODELS>\n";

    foreach $model (@{$modelHash{$key}})
    {
	    ($docset,$type,$size,$selector,$summarizer,$dA,$dB,$rest) 
		= split /\./, $model,8;

	    # Reparse if multi-doc summary so no docid present in file name
	    if ($type eq "M")
	    {
		($docset,$type,$size,$selector,$summarizer,$rest) 
		    = split /\./, $model,6;
	    }
	    print "<M ID=\"$summarizer\">$model</M>\n";
    }

    print "</MODELS>\n";
    print "</EVAL>\n";

    # Do include manual peers here, making sure not to include corresponding
    # manual model among the models each is compared to

    foreach $peer (@{$peerHash{$key}}) 
    {

	chomp $peer;


	if ($task == 3 || $task == 4)
	{
	    ($docset,$type,$size,$selector,$summarizer,$dA,$dB,$dC,$rest) 
	    = split /\./, $peer,9;
	    $target = "$docset.$type.$size.$selector.*.$dA.$dB.$dC\n";
	}
	else
	{
	    ($docset,$type,$size,$selector,$summarizer,$dA,$dB,$rest) 
		= split /\./, $peer,8;
	    $target = "$docset.$type.$size.$selector.*.$dA.$dB\n";
	}


	# Reparse if multi-doc summary so no docid present in file name
	if ($type eq "M")
	{
	    ($docset,$type,$size,$selector,$summarizer,$rest) 
		= split /\./, $peer,6;
	    $target = "$docset.$type.$size.$selector.*\n";
	}

	if (index($manualCodes,$summarizer)>=0) # Include only manual peers
	{
	    $evalId++;

	    print "<EVAL ID=\"$evalId\">\n";
	    print "<PEER-ROOT>\n";
	    print "/home/barney1/duc/duc2004/eval/peers\n";
	    print "</PEER-ROOT>\n";

	    print "<MODEL-ROOT>\n";
	    print "/home/barney1/duc/duc2004/eval/models\n";
	    print "</MODEL-ROOT>\n";

	    print "<INPUT-FORMAT TYPE=\"SPL\">\n";
	    print "</INPUT-FORMAT>\n";

	    print "<PEERS>\n";
	    print "<P ID=\"$summarizer\">$peer</P>\n";
	    print "</PEERS>\n";
	    print "<MODELS>\n";

	    foreach $model (@{$modelHash{$key}}) 
	    {

		if ($peer !~ /$model/) # Filter out model same as manual peer
		{

		    if ($task == 3 || $task == 4)
		    {
			($docset,$type,$size,$selector,$summarizer,$dA,$dB,$dC,$rest) 
			    = split /\./, $model,9;
		    }
		    else
		    {
			($docset,$type,$size,$selector,$summarizer,$dA,$dB,$rest) 
			    = split /\./, $model,8;
		    }			

		    if ($type eq "M")
		    {
			($docset,$type,$size,$selector,$summarizer,$rest) 
			    = split /\./, $model,6;
		    }
		    print "<M ID=\"$summarizer\">$model</M>\n";
		}
	    }

	    print "</MODELS>\n";
	    print "</EVAL>\n";

	}
    }

}
print "</ROUGE_EVAL>\n";


# Subroutines -------------------------------------------------------------



sub makeList {
my($modelDir,$peerDir) = @_;

open PEERS, "ls -1 $peerDir/$task/ |" or 
    die "Can't open pipe from ls on peers: $!\n";

# For every peer file
while ($peerline = <PEERS>)
{
    chomp $peerline;
    
    #print "PEERLINE:$peerline\n";

    # Create a wildcard version of the model/peer summary file name that
    # matches regardless of summary source. Call it $target.
    # Use it as a key for two hashs - one to keep the list of associated
    # peers, one to keep the list of associated models
    
    if ($task == 3 || $task == 4)
    { 
	($docset,$type,$size,$selector,$summarizer,$dA,$dB,$dC,$rest) 
	    = split /\./, $peerline,9;
	$target = "$docset.$type.$size.$selector.*.$dA.$dB.$dC\n";	
    }
    else
    {
	($docset,$type,$size,$selector,$summarizer,$dA,$dB,$rest) 
	    = split /\./, $peerline,8;
	$target = "$docset.$type.$size.$selector.*.$dA.$dB\n";
    }


    # Reparse if multi-doc summary so no docid present in file name
    if ($type eq "M")
    {
	($docset,$type,$size,$selector,$summarizer,$rest) 
	    = split /\./, $peerline,6;
	$target = "$docset.$type.$size.$selector.*\n";
    }

    # Add the current peer to the hash for the current target
    #print "PEERHASHENTRY:$task/$peerline\n";
    push @{ $peerHash{$target} }, "$task/$peerline";

    # If the target is not already in the hash of associated models,
    # collect all the associated models and add them to the hash of
    # models for the current target
    if ($modelHash{$target} == "")
    {

	#print "ls $modelDir/$target |\n";
	open MODELS, "ls $modelDir/$task/$target |" or 
	    die "Can't open pipe from ls on models: $!\n";

	while($modelline = <MODELS>)
	{
	    # In any case add the model name to the list of models assciated with
	    # the target

	    chomp $modelline;
	    $lastSlashIndex = rindex($modelline,"/");
	    $modelline = substr($modelline,$lastSlashIndex+1);
	    push @{ $modelHash{$target} }, "$task/$modelline"; 
	    #print "PUSH MODEL:$modelline\n";	

	}

	close MODELS;
    }

}

close PEERS;
return;
}
