package Essence::Text;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(split_words
	     trim
	     remove_whitespace);

#
# TODO: AJW 9/17
# split_sentences

#
# NOTE: AJW 9/19
# the big regex below was taken directly from earlier versions of MEAD.
# I'm not sure what it is, but it seems to work.
#
sub split_words {
    my $text = shift;
     
    my @words = split /\s|\,|\-|\(|\)|¡@|¡]|¡\^|¡A|¡B|¡C|¡u|¡m|¡n|¡F|¡þ|¡v|¡G|¡H|¡S|¡T|¡I|\?|\!|¡§|¡¨|¡y|¡z|\./, $text;

    my @ret = ();
  
    foreach my $w (@words) {
	next if $w =~ /^$/;
	push @ret, $w;
    }

    return @ret;
}

sub trim {
    my $text = shift;
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    return $text;
}

sub remove_whitespace {
    my $text = shift;
    $text =~ s/\s//g;
    return $text;
}
