#!/usr/local/bin/perl -w

package Essence::Centroid;
require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw( compute_centroid
	     write_centroid);

use strict;

use Essence::IDF;
use Essence::Text;

=head1 NAME

Essence::Centroid

=head1 SYNOPSIS

    use Essence::Centroid;

=head1 DESCRIPTION

This class is used to compute a (string) cluster centroid from a cluster.

=head1 METHODS

=cut

### Stupid hashref-based centroid methods

sub compute_centroid {
    my $cluster = shift;

    my $centroid = Essence::Centroid->new();

    foreach my $docref (values %$cluster) {
	my $doctext = "";
	foreach my $sentref (@$docref) {
	    my $text = $$sentref{'TEXT'};
	    $doctext .= " " . $text;
	}
	$centroid->add_document($doctext);
    }

    return $centroid;
}

# writes word/tdidf pairs in descending order.
sub write_centroid {
    my $self = shift;
    my %args = @_;

    my $output = $args{'OUTPUT'} || \*STDOUT;
    unless (ref $output) {
        open TEMP, ">$output" or
            die "Unable to open '$output' for printing extract.\n";
        $output = \*TEMP;
    }

    unless ($self->{valid}) {
        $self->_build_centroid();
    }

    foreach my $word (sort { $self->{tfidf}{$b} <=> $self->{tfidf}{$a} }
                      keys %{$self->{tfidf}}) {
        printf $output "%-16.16s", $word;
        printf $output " %15.10f", $self->{tf}{$word};
        printf $output " %15.10f", $self->{idf}{$word};
        printf $output " %15.10f", $self->{tfidf}{$word};
        print $output "\n";
    }
}

### OO based centroid

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;

    $self->{valid} = 0;

    return $self;
}

# can take either a Essence::WebDocument or a string.
sub add_document {
    my ($self, $doc) = @_;
    $self->add_documents($doc);
}

# takes a list, each element of which can be an Essence::WebDocument or a string.
sub add_documents {
    my ($self, @docs) = @_;
    $self->{valid} = 0;
    push @{$self->{documents}}, @docs;
}

sub _build_centroid {
    my $self = shift;

    # CONSTANTS.
    # TODO: put them someplace more appropriate.
    my $MIN_TFIDF = 3;
    my $MIN_CENTROID_SIZE = 8 * scalar @{$self->{documents}};

    # compute $self->{tf}{$word} = tf (total in all docs).
    foreach my $doc (@{$self->{documents}}) {

	my $text;
	if (ref($doc) eq "Essence::WebDocument") {
	    $text = $doc->get_text();
	} elsif (! ref($doc)) { # this is a scalar.  treat it as a string.
	    $text = $doc;
	}

	my @words = split_words($text);

	foreach my $word (@words) {
	    $self->{tf}{$word}++;
	}
    }

    # vars.
    my $word;
    my $tf;

    my $numdocs = scalar @{$self->{documents}};

    # make $self->{tf}{$word} the AVERAGE occurrences per doc.
    # THIS DOESN'T REALLY MATTER!!!!
    while (($word, $tf) = each %{$self->{tf}}) {
	$self->{tf}{$word} = $tf / $numdocs;
    }

    # fill in $self->{tfidf}{$word}
    while (($word, $tf) = each %{$self->{tf}}) {
        my $idf = get_nidf($word);
        $self->{idf}{$word} = $idf;
	$self->{tfidf}{$word} = $tf * $idf;

    }

    # fill in $self->{centroid}{$word}
    my $count = 0;
    foreach my $word (sort { $self->{tfidf}{$b} <=> $self->{tfidf}{$a} } 
		      keys %{$self->{tfidf}}) {
	

	if ( $self->{tfidf}{$word} > $MIN_TFIDF || 
	     $count < $MIN_CENTROID_SIZE ) {

	    $count++;
	    $self->{centroid}{$word} = $self->{tfidf}{$word};

	}  # else {  }
	    
    }

    # our stuff is now valid.
    $self->{valid} = 1;

    return 1;
}



sub _print {
    my $self = shift;

    unless ($self->{valid}) {
	$self->_build_centroid();
    }

    my $word;
    foreach my $word (sort { $self->{tfidf}{$b} <=> $self->{tfidf}{$a} }
		      keys %{$self->{tfidf}}) {
	#while (($word, $tf) = each %{$self->{tf}}) {

	printf "%-16.16s %10.2f", $word, $self->{tf}{$word};
	printf " %15.10f", $self->{tfidf}{$word}; 
	printf " %15.10f", $self->{centroid}{$word};
	print "\n";
    }

}

sub centroid_score {
    my ($self, $text) = @_;

    unless ($self->{valid}) {
	$self->_build_centroid();
    }

    my @words = split_words($text);

    my $score = 0;
    foreach my $word (@words) {
	$score += $self->{centroid}{$word};
    }

    return $score;
}
