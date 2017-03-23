package MEAD::SentJudge;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(open_from_file

             read_sentjudge
	     sentjudge_to_extract);

#
# TODO: AJW 9/17
# remove XML::TreeBuilder
# write_sentjudge
#

use strict;

use XML::TreeBuilder;
use XML::Parser;

use MEAD::Cluster;

## Crappy hashref SentJudge code.

my %sentjudge;
my $curr_did;
my $curr_sno;

sub read_sentjudge {
    my $source = shift || \*STDIN;

    %sentjudge = ();

    undef $curr_did;
    undef $curr_sno;

    my $xml_parser = new XML::Parser(Handlers =>
				     {Start =>
				     \&read_sentjudge_handle_start});

    # $source can be a Filehandle or a GLOB
    if (ref $source) {
        $xml_parser->parse($source);
    } else {
        $xml_parser->parsefile($source);
    }

    return %sentjudge;
}

sub read_sentjudge_handle_start {

    shift; #don't care about Expat
    my $element_name = shift;
    my %atts = @_;

    if ($element_name eq 'S') {

        $curr_did = $atts{'DID'};
        $curr_sno = $atts{'SNO'};

    } elsif ($element_name eq 'JUDGE') {

        my $name = $atts{'N'};
        my $util = $atts{'UTIL'};

        # if there's no document, we need to create one.
        unless ($sentjudge{$curr_did}) {
            $sentjudge{$curr_did} = [];
	}

	my $docref = $sentjudge{$curr_did};

        # if there's no sentence, we need to create one.
        unless ($$docref[$curr_sno]) {
            $$docref[$curr_sno] = {};
	}

        my $sentref = $$docref[$curr_sno];
        $$sentref{$name} = $util;

    }
}

sub sentjudge_to_extract {
    my $sentjudge = shift or die;
    my $size = shift or die;
    my @judges = @_;

    # flatten the sentjudge.
    my $flattened_sentjudge = flatten_cluster($sentjudge);

    if (@judges) {
	my $s0 = $$flattened_sentjudge[0];
	foreach my $j (@judges) {
	    unless (defined $$s0{$j}) {
		die "Judge '$j' does not exist.\n";
	    }
	}
    } else {
	my $s0 = $$flattened_sentjudge[0];
        my @skeys = keys %$s0;
       
        foreach my $key (@skeys) {
            next if ($key eq 'DID' || $key eq 'SNO');
            push @judges, $key;
        } 
    } 
     
    my @sents = ();
    foreach my $sentref (@$flattened_sentjudge) {
	my $s = {};
	$$s{'DID'} = $$sentref{'DID'};
	$$s{'SNO'} = $$sentref{'SNO'};
	foreach my $j (@judges) {
	    $$s{'Score'} += $$sentref{$j};
	}
	push @sents, $s;
    }

    @sents = sort { $$b{'Score'} <=> $$a{'Score'} } @sents;
    my @extract = @sents[0 .. ($size-1)];
    
    return \@extract;
}


##
## Below is the OO SentJudge code.
##


=head1 DESCRIPTION

=head1 METHODS

=over 2

=item $sj = MEAD::SentJudge->open_from_file($filename);

=cut

sub open_from_file {
    my ($class, $filename) = @_;

    my $self = {};
    bless $self, $class;
    
    $self->_really_open_me($filename);

    return $self;
}

#
# does all the work of opening the SentJudge from a string.
#
sub _really_open_me {
    my ($self, $filename) = @_;

    $self->{filename} = $filename;

    my $tree = XML::TreeBuilder->new;
    $tree->parsefile($filename);

    my $sj = $tree->look_down("_tag", "SENT-JUDGE");
    my @s_list = $sj->look_down("_tag", "S");

    my $num_sentences = 0;
    foreach my $s (@s_list) {
    my $did = $s->attr("DID");
    my $sno = $s->attr("SNO");
    
    $num_sentences++;
    my $skey = "$did#$sno";
    $self->{sentences}{$skey} = $num_sentences;
    $self->{DID_list}[$num_sentences] = $did;
    $self->{SNO_list}[$num_sentences] = $sno;


    my @judges = $s->look_down("_tag", "JUDGE");
    foreach my $j (@judges) {
        my $name = $j->attr("N");
        my $jnum = $self->_ensure_judge($name);
        my $util = $j->attr("UTIL");
        
        $self->{judgments}[$jnum][$num_sentences] = $util;
        $self->{judge_util_count}[$jnum][$util]++;
        push @{$self->{judge_util_list}[$jnum][$util]}, $num_sentences; 
    }
    }

    $tree->delete;
}

#
# make sure that judge $name has a number.
#
sub _ensure_judge {
    my ($self, $name) = @_;
    my $num = $self->get_judge_number($name);
    
    unless ($num) {
        $num = $self->get_num_judges + 1;
        $self->{judges}{$name} = $num;
    }
    
    return $num;
}

=item $num = $sj->get_num_sentences();

=cut

sub get_num_sentences {
    my $self = shift;
    return scalar(@{$self->{DID_list}}) - 1;
}


=item $s = $sj->get_sentence_number($did, $sno);

=cut

sub get_sentence_number {
    my ($self, $did, $sno) = @_;
    return $self->{sentences}{"$did#$sno"};
}


=item $judgment = $sj->get_judgment_by_number($judge_num, $sentence_num);

=cut

sub get_judgment_by_number {
    my ($self, $jnum, $snum) = @_;
    return $self->{judgments}[$jnum][$snum];
}


=item $judgment = $sj->get_judgment($judge_num, $did, $sno);

=cut

sub get_judgment {
    my ($self, $jnum, $did, $sno) = @_;
    unless (defined $sno) {
        die "Not enough arguments to get_judgment: 3 required\n";
    }
    my $snum = $self->get_sentence_number($did, $sno);
    return $self->{judgments}[$jnum][$snum];
}

=item $judgement = $sj->get_judgement($judge_num, $did, $sno);

Alias to get_judgment($jnum, $did, $sno)

=cut

sub get_judgement {
    my ($self, $jnum, $did, $sno) = @_;
    return $self->get_judgment($jnum, $did, $sno);
}



sub get_num_judges {
    my $self = shift;
    return scalar(keys(%{$self->{judges}}));
}


# size is number of sentences.
sub get_judge_utility_for_extract_size {
    my ($self, $jnum, $size) = @_;

    my $cum_util = 0;
    my $util_val = 10;
    while ($size && $util_val) {
    my $num_for_util = $self->{judge_util_count}[$jnum][$util_val];
    if ($num_for_util > $size) {
        $num_for_util = $size;
    }
       
    $cum_util += $num_for_util * $util_val;
    
    $size -= $num_for_util;
    $util_val--;
    }
    
    return $cum_util;
}




sub get_total_judge_utility {
    my ($self, $jnum) = @_;

    my $total_util = 0;
    foreach my $util_val (1..10) {
    $total_util += 
        $self->{judge_util_count}[$jnum][$util_val] * $util_val;
    }

    return $total_util;
}




# 
# utility of judge1's $num-sentence extract based on
# judge2's utility judgments.
#
sub interjudge_utility {
    my ($self, $j1, $j2, $num) = @_;

    # is this a reasonable thing to do?
    if ($num < 0) {
    return 0;
    }

    my @selected = $self->judge_select($j1, $num);
    
    my $util = 0;
    foreach my $s (@selected) {
	$util += $self->get_judgment_by_number($j2, $s);
    }

    my $normalized = 
    $util / $self->get_judge_utility_for_extract_size($j2, $num);
    return $normalized;
}




sub judge_performance {
    my ($self, $jnum, $size) = @_;

    my $num_judges = $self->get_num_judges;
    my $perf = 0;
    foreach my $j2 (1..$num_judges) {
    next if ($jnum == $j2); # don't compare to ourselves.
    $perf += $self->interjudge_utility($jnum, $j2, $size);
    }

    my $avg = $perf / ($num_judges - 1);
    return $avg;
}




sub average_judge_performance {
    my ($self, $size) = @_;

    my $num_judges = $self->get_num_judges;
    my $perf = 0;
    foreach my $jnum (1..$num_judges) {
    $perf += $self->judge_performance($jnum, $size);
    }

    my $avg = $perf / $num_judges;
    return $avg;
}



sub expected_random_performance {
    my ($self, $size) = @_;

    my $num_judges = $self->get_num_judges;
    my $total_util = 0;
    foreach my $jnum (1..$num_judges) {
    $total_util += 
        $self->get_total_judge_utility($jnum) /
        $self->get_judge_utility_for_extract_size($jnum, $size);
    }


    my $rand = $size * $total_util / $self->get_num_sentences / $num_judges;
    return $rand;
}



sub judge_select {
    my ($self, $jnum, $size) = @_;

    my @list;
    my $util_val = 10;
    while ($size && $util_val) {
        my $num_for_util = $self->{judge_util_count}[$jnum][$util_val];
        if ($num_for_util > $size) {
            $num_for_util = $size;
        }

    for my $i (0..($num_for_util-1)) {
        push @list, $self->{judge_util_list}[$jnum][$util_val][$i];
    }

        $size -= $num_for_util;
        $util_val--;
    }

    return @list;
}


=item $num = $sj->get_judge_number($judge_name);

1 to num_judges

=cut

sub get_judge_number {
    my ($self, $name) = @_;
    return $self->{judges}{$name};
}


=item @names = $sj->get_judge_names();

Returns the names of the judges.

=cut

sub get_judge_names {
    my $self = shift;
    return keys %{$self->{judges}};
}

1;
