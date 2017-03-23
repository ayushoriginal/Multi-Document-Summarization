package DUC::Extract;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(open_from_file
         parse_from_string);

use strict;
use XML::TreeBuilder;

=head1 DESCRIPTION

This class opens extracts, both from files and from strings, 
so that the user will be able to get extract information quickly
and easily.

MEAD::Extract should do much the same stuff as this class.

=head1 METHODS

=over 2

=item $extract = DUC::Extract->open_from_file($filename);

Opens an extract from the specified file.

=cut

sub open_from_file {
    my ($class, $filename) = @_;
    my $self = {};

    bless $self, $class;

    open EXTRACT, $filename;
    
    my $extract_string;
    while (<EXTRACT>) {
	$extract_string .= $_;
    }
    close EXTRACT;

    $self->_really_open_me($extract_string);
    
    return $self;
}


=item $extract = DUC::Extract->parse_from_string($extract_string);

Opens and returns an extract from the argument string, which is an 
extract in XML format.

=cut

sub parse_from_string {
    my ($class, $extract_string) = @_;
    my $self = {};
    
    bless $self, $class;

    $self->_really_open_me($extract_string);

    return $self;
}

#
# does all the work of opening an extract from the $extract_string argument.
#
# TODO: catch errors in parsing the string, and "die" ourselves if there
# are problems.
#
sub _really_open_me {
    my ($self, $extract_string) = @_;

    $self->{extract_string} = $extract_string;

    my $extract_tree = XML::TreeBuilder->new;
    $extract_tree->parse($extract_string);
    my $extract_node = $extract_tree->find_by_tag_name("multi-e");

    my $node;
    my $i = 0;
    my @nodes = $extract_node->look_down("_tag", "s");
    foreach my $node (@nodes) {
	$i++;

	# document ID's can be called either of these names...
        my $DID = $node->attr("docref");
	unless ($DID) {
	    $DID = $node->attr("docid");
	}

        my $SNO = $node->attr("num");


        my $WCNT = $node->attr("wdcount");

	# TODO: AJW 8/28
	# get the wordcount somehow, possibly splitting the words...

        #die unless ($DID and $SNO and $WCNT);
	unless ($DID && $SNO) {
	    die "Couldn't find (at least one of) 'docid' or 'num' " .
		"in the $i-th sentence node";
	}

	$self->{DID_list}[$i] = $DID;
	$self->{SNO_list}[$i] = $SNO;
	$self->{WCNT_list}[$i] = $WCNT;
    }

    #cleanup.
    $extract_tree->delete;
}


=item $num = $extract->get_num_sentences();

Returns the number of sentences in this Extract.  
Sentences are numbered from 1 to $num.
Calling any of the remaining methods with an argument less than 1 or
greater than the value returned by this method will result in unpredictable
behavior.

=cut

sub get_num_sentences {
    my $self = shift;
    return scalar(@{$self->{DID_list}}) - 1;
}


=item $docid = $extract->get_DOCID_for_sentence($sentence_index);

Returns the document ID (docid/DOCID) for the specified sentence in the extract.
This ID is the ID for the document from which the specified sentence was extracted.

=cut

sub get_DOCID_for_sentence {
    my ($self, $sentence) = @_;
    return $self->{DID_list}[$sentence];
}


=item $did = $extract->get_DID_for_sentence($sentence_index);

An alias for get_DOCID_for_sentence($sentence_index).

=cut

sub get_DID_for_sentence {
    my ($self, $sentence) = @_;
    return $self->get_DOCID_for_sentence($sentence);
}


=item $sno = $extract->get_SNO_for_sentence($sentence_index);

Returns the sentence number of the specified sentence IN THE CORRESPONDING SOURCE DOCUMENT.

=cut

sub get_SNO_for_sentence {
    my ($self, $sentence) = @_;
    return $self->{SNO_list}[$sentence];
}


=item $wcnt = $extract->get_WCNT_for_sentence($sentence_index);

Returns the number of words of the specified sentence in the extract.

=cut

sub get_WCNT_for_sentence {
    my ($self, $sentence) = @_;
    return $self->{WCNT_list}[$sentence];
}


=item $text = $extract->get_text();

Returns the text of the extract, with two spaces spaces between sentences.

=cut

sub get_text {
    my $self = shift;
    unless ($self->{text}) {
    $self->{text} = $self->{extract_string};
    $self->{text} =~ s/\<.+?\>//g;
    $self->{text} =~ s/\n+/  /g;
    }
    return $self->{text};
}
