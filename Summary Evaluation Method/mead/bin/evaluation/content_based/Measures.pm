# Similiarity Measures for Comparing Texts 

use Essence::IDF;


my $eng_idf_word = "enidf";
#my $eng_idf_lemma = "cnidf";

sub my_simple_cosine {

my $text1 = shift;

my $text2 = shift;



# store the tokens in hash tables, the key is the token, the value is the number of
# times the token appears in the text

my @tokens1 = split(/ /,$text1);
my @tokens2 = split(/ /,$text2);

my %set1 = ();
my %set2 = ();

my $set1_count = 0;
my $tokens1_count = 0;
my $set2_count = 0;
my $tokens2_count = 0;

foreach $token (@tokens1) {
    $tokens1_count++;

    if(exists($set1{$token})) {

	$set1{$token} = $set1{$token}+1;
    } else {$set1{$token} =1; $set1_count++ }
} 




foreach $token (@tokens2) {
    $tokens2_count++;
    if(exists($set2{$token})) {

	$set2{$token} = $set2{$token}+1;
    } else {$set2{$token} =1; $set2_count++ }
} 



my $result2 = simple_cosine(\%set1,\%set2);

return $result2;

}




sub my_cosine {


my $option = shift;

die "Lemmas or Words???\n" unless (($option eq "-l") || ($option eq "-w"));

my $idf_file = ($option eq "-l") ? $eng_idf_lemma : $eng_idf_word; 

my $text1 = shift;

my $text2 = shift;

open_nidf($idf_file);

# store the tokens in hash tables, the key is the token, the value is the number of
# times the token appears in the text

my @tokens1 = split(/ /,$text1);
my @tokens2 = split(/ /,$text2);

my %set1 = ();
my %set2 = ();

my $set1_count = 0;
my $tokens1_count = 0;
my $set2_count = 0;
my $tokens2_count = 0;

foreach $token (@tokens1) {
    $tokens1_count++;

    if(exists($set1{$token})) {

	$set1{$token} = $set1{$token}+1;
    } else {$set1{$token} =1; $set1_count++ }
} 

foreach $key (keys %set1) {
    $idf = get_nidf("$key");
    # print "KEY: $key, VALUE: $idf\n";
    $set1{$key}=$set1{$key}*$idf;
}


foreach $token (@tokens2) {
    $tokens2_count++;
    if(exists($set2{$token})) {

	$set2{$token} = $set2{$token}+1;
    } else {$set2{$token} =1; $set2_count++ }
} 

foreach $key (keys %set2) {
    $idf = get_nidf("$key");
    # print "KEY: $key, VALUE: $idf\n";
    $set2{$key}=$set2{$key}*$idf;
}



my $result2 = complete_cosine(\%set1,\%set2);

return $result2;

}

sub simple_cosine {
    my $s1 = shift;
    my $s2 = shift;
   
 
    my $cos=0;

    foreach $key (keys %$s1) {

	if(exists($$s2{$key})) {
	    $cos++;
	}
    }
    
    
 

    $cos = $cos/(sqrt((scalar keys %$s1)*(scalar keys %$s2)));
    return $cos;

}



sub show_tokens {
# I will use the @_ array  
    # print "TOKENS: $_[0]\n";
    # print "DIFFERENTS: $_[1]\n";
    shift @_;
    shift @_;
    my %table = @_;
    foreach $key (keys %table) {
	# print "$key\n";
	
    }
    

}

sub complete_cosine {

    my $s1 = shift;
    my $s2 = shift;
    my $cos = 0;
    my $norm1 = 0;
    my $norm2 = 0;

    foreach $key (keys %$s1) {
	
	$val = $$s1{$key};
	# print "==> $key , $val\n";
	$norm1 = $norm1 + $val*$val;

	if(exists($$s2{$key})) {
	   $cos = $cos + ($val)*($$s2{$key}); 
	}
    }

    foreach $key (keys %$s2) {
	
	$val = $$s2{$key};
	# print "++> $key, $val\n";
	$norm2 = $norm2 + $val*$val;
    }
    if($cos==0) {return $cos;}
#    # print "COS: $cos, NORM1: $norm1, NORM2: $norm2\n";
    $cos = $cos/sqrt($norm1*$norm2);
    return $cos;
    
}



# computes overlap between two units 

sub set_overlap {
    my $s1 = shift;
    my $s2 = shift;
    my $overlap = 0;
 
    foreach $key (keys %$s1) {

	if(exists($$s2{$key})) {
	    $overlap++;
	}
    }

    return $overlap;

}

sub my_bigram_overlap {

my $text1 = shift;

my $text2 = shift;



# store the tokens in hash tables, the key is the token, the value is the number of
# times the token appears in the text

my @tokens1 = split(/ /,$text1);
my @tokens2 = split(/ /,$text2);
my $last1 = $#tokens1;
my $last2 = $#tokens2;

my %set1 = ();
my %set2 = ();

my $set1_count = 0;
my $tokens1_count = 0;
my $set2_count = 0;
my $tokens2_count = 0;


for($i=0;$i<$last1;$i++) {
   
    if($tokens1[$i] le $tokens1[$i+1]) {
	$bigram1=$tokens1[$i]."#".$tokens1[$i+1];
    } else {$bigram1="$tokens1[$i+1]#$tokens1[$i]";}
   # # print "$bigram1\n";
    if(exists($set1{$bigram1})) {

	$set1{$bigram1} = $set1{$bigram1}+1;
    } else {$set1{$bigram1} =1; $set1_count++ }
}

#show_bigrams(%set1);

for($i=0;$i<$last2;$i++) {
   
    if($tokens2[$i] le $tokens2[$i+1]) {
	$bigram2=$tokens2[$i]."#".$tokens2[$i+1];
    } else {$bigram2="$tokens2[$i+1]#$tokens2[$i]";}

   # # print "$bigram2\n";
    if(exists($set2{$bigram2})) {

	$set2{$bigram2} = $set2{$bigram2}+1;
    } else {$set2{$bigram2} =1; $set2_count++ }
}


#show_bigrams(%set2);


my $overlap = set_overlap(\%set1,\%set2);

my $normalized = $overlap/($set1_count+$set2_count-$overlap);


## print "OVERLAP: $overlap\n";

## print "NORMALIZED: $normalized\n";

return $normalized;

}


sub my_token_overlap {


my $text1 = shift;

my $text2 = shift;



# store the tokens in hash tables, the key is the token, the value is the number of
# times the token appears in the text

my @tokens1 = split(/ /,$text1);
my @tokens2 = split(/ /,$text2);

my %set1 = ();
my %set2 = ();

my $set1_count = 0;
my $tokens1_count = 0;
my $set2_count = 0;
my $tokens2_count = 0;

foreach $token (@tokens1) {
    $tokens1_count++;

    if(exists($set1{$token})) {

	$set1{$token} = $set1{$token}+1;
    } else {$set1{$token} =1; $set1_count++ }
} 


foreach $token (@tokens2) {
    $tokens2_count++;
    if(exists($set2{$token})) {

	$set2{$token} = $set2{$token}+1;
    } else {$set2{$token} =1; $set2_count++ }
} 


my $overlap = set_overlap(\%set1,\%set2);

my $normalized = $overlap/($set1_count+$set2_count-$overlap);


## print "OVERLAP: $overlap\n";

## print "NORMALIZED: $normalized\n";

return $normalized;

}


sub my_token_overlap_ch {


    my $tokens1 = shift;
    my $tokens2 = shift;



# store the tokens in hash tables, the key is the token, the value is the number of
# times the token appears in the text



my %set1 = ();
my %set2 = ();

my $set1_count = 0;
my $tokens1_count = 0;
my $set2_count = 0;
my $tokens2_count = 0;

foreach $token (@$tokens1) {
    $tokens1_count++;

    if(exists($set1{$token})) {

	$set1{$token} = $set1{$token}+1;
    } else {$set1{$token} =1; $set1_count++ }
} 


foreach $token (@$tokens2) {
    $tokens2_count++;
    if(exists($set2{$token})) {

	$set2{$token} = $set2{$token}+1;
    } else {$set2{$token} =1; $set2_count++ }
} 


my $overlap = set_overlap(\%set1,\%set2);

my $normalized = $overlap/($set1_count+$set2_count-$overlap);


## print "OVERLAP: $overlap\n";

## print "NORMALIZED: $normalized\n";

return $normalized;

}

sub my_edit_distance {

# This program computes the edit distance between two strings 
# when we consider that they are sequences of tokens
# i.e., XXX YYY ZZZ is a 3-token string



# computes the EDIT matrix

my $string1 = shift;

die "Where is the string?\n" unless defined($string1);


my $string2 = shift;

die "Where is the second string?\n" unless defined($string2);
 

# print edit($string1,$string2);

}




return (5);
