########################################################################
# test.pl - test script for XML::Writer module.
# $Id: test.pl,v 0.2 1999/04/25 13:46:44 david Exp $
########################################################################

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..43\n"; }
END {print "not ok 1\n" unless $loaded;}
use XML::Writer;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

use IO::File;
use strict;

my $output = IO::File->new_tmpfile
  || die "Cannot write to temporary file";
my $writer = new XML::Writer::Namespaces(OUTPUT => $output)
  || die "Cannot create XML writer";

#
# Reset the environment for an additional test.
#
sub resetEnv {
  $output->close();
  $output = IO::File->new_tmpfile;
  $writer = new XML::Writer::Namespaces(OUTPUT => $output);
}

#
# Check the results in the temporary output file.
#
# $number - the test number
# $expected - the exact output expected
#
sub checkResult {
  my ($number, $expected) = (@_);
  my $data = '';
  $output->seek(0,0);
  $output->read($data, 1024);
  if ($expected eq $data) {
    print "ok $number\n";
  } else {
    print "not ok $number\n";
    print STDERR "\t(Expected '$expected' but found '$data')\n";
  }
  resetEnv();
}

#
# Expect an error of some sort, and check that the message matches.
#
# $number - the test number
# $pattern - a regular expression that must match the error message
# $value - the return value from an eval{} block
#
sub expectError {
  my ($number, $pattern, $value) = (@_);
  if (defined($value)) {
    print STDERR "Expected error did not occur!\n";
    print "not ok $number\n";
  } elsif ($@ !~ $pattern) {
    print STDERR $@;
    print "not ok $number\n";
  } else {
    print "ok $number\n";
  }
  resetEnv();
}



# Test 2: Empty element tag.
TEST: {
  $writer->emptyTag("foo");
  $writer->end();
  checkResult(2, "<foo />\n");
};



# Test 3: Empty element tag with XML decl.
TEST: {
  $writer->xmlDecl();
  $writer->emptyTag("foo");
  $writer->end();
  checkResult(3, <<"EOS");
<?xml version="1.0" encoding="UTF-8"?>
<foo />
EOS
};



# Test 4: Start/end tag.
TEST: {
  $writer->startTag("foo");
  $writer->endTag("foo");
  $writer->end();
  checkResult(4, "<foo></foo>\n");
};



# Test 5: Attributes
TEST: {
  $writer->emptyTag("foo", "x" => "1>2");
  $writer->end();
  checkResult(5, "<foo x=\"1&gt;2\" />\n");
};



# Test 6: Character data
TEST: {
  $writer->startTag("foo");
  $writer->characters("<tag>&amp;</tag>");
  $writer->endTag("foo");
  $writer->end();
  checkResult(6, "<foo>&lt;tag&gt;&amp;amp;&lt;/tag&gt;</foo>\n");
};



# Test 7: Comment outside document element
TEST: {
  $writer->comment("comment");
  $writer->emptyTag("foo");
  $writer->end();
  checkResult(7, "<!-- comment -->\n<foo />\n");
};



# Test 8: Processing instruction without data (outside document element)
TEST: {
  $writer->pi("pi");
  $writer->emptyTag("foo");
  $writer->end();
  checkResult(8, "<?pi?>\n<foo />\n");
};


# Test 9: Processing instruction with data (outside document element)
TEST: {
  $writer->pi("pi", "data");
  $writer->emptyTag("foo");
  $writer->end();
  checkResult(9, "<?pi data?>\n<foo />\n");
};


# Test 10: comment inside document element
TEST: {
  $writer->startTag("foo");
  $writer->comment("comment");
  $writer->endTag("foo");
  $writer->end();
  checkResult(10, "<foo><!-- comment --></foo>\n");
};


# Test 11: processing instruction inside document element
TEST: {
  $writer->startTag("foo");
  $writer->pi("pi");
  $writer->endTag("foo");
  $writer->end();
  checkResult(11, "<foo><?pi?></foo>\n");
};


# Test 12: WFE for mismatched tags
TEST: {
  $writer->startTag("foo");
  expectError(12, "Attempt to end element \"foo\" with \"bar\" tag", eval {
    $writer->endTag("bar");
  });
};


# Test 13: WFE for unclosed elements
TEST: {
  $writer->startTag("foo");
  $writer->startTag("foo");
  $writer->endTag("foo");
  expectError(13, "Document ended with unmatched start tag\\(s\\)", eval {
    $writer->end();
  });
};


# Test 14: WFE for no document element
TEST: {
  $writer->xmlDecl();
  expectError(14, "Document cannot end without a document element", eval {
    $writer->end();
  });
};


# Test 15: WFE for multiple document elements (non-empty)
TEST: {
  $writer->startTag('foo');
  $writer->endTag('foo');
  expectError(15, "Attempt to insert start tag after close of", eval {
    $writer->startTag('foo');
  });
};


# Test 16: WFE for multiple document elements (empty)
TEST: {
  $writer->emptyTag('foo');
  expectError(16, "Attempt to insert empty tag after close of", eval {
    $writer->emptyTag('foo');
  });
};


# Test 17: DOCTYPE mismatch with empty tag
TEST: {
  $writer->doctype('foo');
  expectError(17, "Document element is \"bar\", but DOCTYPE is \"foo\"", eval {
    $writer->emptyTag('bar');
  });
};


# Test 18: DOCTYPE mismatch with start tag
TEST: {
  $writer->doctype('foo');
  expectError(18, "Document element is \"bar\", but DOCTYPE is \"foo\"", eval {
    $writer->startTag('bar');
  });
};


# Test 19: Multiple DOCTYPE declarations
TEST: {
  $writer->doctype('foo');
  expectError(19, "Attempt to insert second DOCTYPE", eval {
    $writer->doctype('bar');
  });
};


# Test 20: Misplaced DOCTYPE declaration
TEST: {
  $writer->startTag('foo');
  expectError(20, "The DOCTYPE declaration must come before", eval {
    $writer->doctype('foo');
  });
};


# Test 21: Multiple XML declarations
TEST: {
  $writer->xmlDecl();
  expectError(21, "The XML declaration is not the first thing", eval {
    $writer->xmlDecl();
  });
};


# Test 22: Misplaced XML declaration
TEST: {
  $writer->comment();
  expectError(22, "The XML declaration is not the first thing", eval {
    $writer->xmlDecl();
  });
};


# Test 23: Implied end-tag name.
TEST: {
  $writer->startTag('foo');
  $writer->endTag();
  $writer->end();
  checkResult(23, "<foo></foo>\n");
};


# Test 24: in_element query
TEST: {
  $writer->startTag('foo');
  $writer->startTag('bar');
  if ($writer->in_element('bar')) {
    print "ok 24\n";
  } else {
    print "not ok 24\n";
  }
  resetEnv();
};


# Test 25: within_element query
TEST: {
  $writer->startTag('foo');
  $writer->startTag('bar');
  if ($writer->within_element('foo') && $writer->within_element('bar')) {
    print "ok 25\n";
  } else {
    print "not ok 25\n";
  }
  resetEnv();
};


# Test 26: current_element query
TEST: {
  $writer->startTag('foo');
  $writer->startTag('bar');
  if ($writer->current_element() eq 'bar') {
    print "ok 26\n";
  } else {
    print "not ok 26\n";
  }
  resetEnv();
};


# Test 27: ancestor query
TEST: {
  $writer->startTag('foo');
  $writer->startTag('bar');
  if ($writer->ancestor(0) eq 'bar' && $writer->ancestor(1) eq 'foo') {
    print "ok 27\n";
  } else {
    print "not ok 27\n";
  }
  resetEnv();
};


# Test 28: basic namespace processing with empty element
TEST: {
  my $ns = 'http://www.foo.com/';
  $writer->addPrefix($ns, 'foo');
  $writer->emptyTag([$ns, 'doc']);
  $writer->end();
  checkResult(28, "<foo:doc xmlns:foo=\"$ns\" />\n");
};


# Test 29: basic namespace processing with start/end tags
TEST: {
  my $ns = 'http://www.foo.com/';
  $writer->addPrefix($ns, 'foo');
  $writer->startTag([$ns, 'doc']);
  $writer->endTag([$ns, 'doc']);
  $writer->end();
  checkResult(29, "<foo:doc xmlns:foo=\"$ns\"></foo:doc>\n");
};


# Test 30: basic namespace processing with generated prefix
TEST: {
  my $ns = 'http://www.foo.com/';
  $writer->startTag([$ns, 'doc']);
  $writer->endTag([$ns, 'doc']);
  $writer->end();
  checkResult(30, "<__NS1:doc xmlns:__NS1=\"$ns\"></__NS1:doc>\n");
};


# Test 31: basic namespace processing with attributes and empty tag.
TEST: {
  my $ns = 'http://www.foo.com/';
  $writer->addPrefix($ns, 'foo');
  $writer->emptyTag([$ns, 'doc'], [$ns, 'id'] => 'x');
  $writer->end();
  checkResult(31, "<foo:doc foo:id=\"x\" xmlns:foo=\"$ns\" />\n");
};


# Test 32: same as above, but with default namespace.
TEST: {
  my $ns = 'http://www.foo.com/';
  $writer->addPrefix($ns, '');
  $writer->emptyTag([$ns, 'doc'], [$ns, 'id'] => 'x');
  $writer->end();
  checkResult(32, "<doc __NS1:id=\"x\" xmlns=\"$ns\" xmlns:__NS1=\"$ns\" />\n");
};


# Test 33: test that autogenerated prefixes avoid collision.
TEST: {
  my $ns = 'http://www.foo.com/';
  $writer->addPrefix('http://www.bar.com/', '__NS1');
  $writer->emptyTag([$ns, 'doc']);
  $writer->end();
  checkResult(33, "<__NS2:doc xmlns:__NS2=\"$ns\" />\n");
};


# Test 34: check for proper declaration nesting with subtrees.
TEST: {
  my $ns = 'http://www.foo.com/';
  $writer->addPrefix($ns, 'foo');
  $writer->startTag('doc');
  $writer->characters("\n");
  $writer->emptyTag([$ns, 'ptr1']);
  $writer->characters("\n");
  $writer->emptyTag([$ns, 'ptr2']);
  $writer->characters("\n");
  $writer->endTag('doc');
  $writer->end();
  checkResult(34, <<"EOS");
<doc>
<foo:ptr1 xmlns:foo="$ns" />
<foo:ptr2 xmlns:foo="$ns" />
</doc>
EOS
};


# Test 35: check for proper declaration nesting with top level.
TEST: {
  my $ns = 'http://www.foo.com/';
  $writer->addPrefix($ns, 'foo');
  $writer->startTag([$ns, 'doc']);
  $writer->characters("\n");
  $writer->emptyTag([$ns, 'ptr1']);
  $writer->characters("\n");
  $writer->emptyTag([$ns, 'ptr2']);
  $writer->characters("\n");
  $writer->endTag([$ns, 'doc']);
  $writer->end();
  checkResult(35, <<"EOS");
<foo:doc xmlns:foo="$ns">
<foo:ptr1 />
<foo:ptr2 />
</foo:doc>
EOS
};


# Test 36: check for proper default declaration nesting with subtrees.
TEST: {
  my $ns = 'http://www.foo.com/';
  $writer->addPrefix($ns, '');
  $writer->startTag('doc');
  $writer->characters("\n");
  $writer->emptyTag([$ns, 'ptr1']);
  $writer->characters("\n");
  $writer->emptyTag([$ns, 'ptr2']);
  $writer->characters("\n");
  $writer->endTag('doc');
  $writer->end();
  checkResult(36, <<"EOS");
<doc>
<ptr1 xmlns="$ns" />
<ptr2 xmlns="$ns" />
</doc>
EOS
};


# Test 37: check for proper default declaration nesting with top level.
TEST: {
  my $ns = 'http://www.foo.com/';
  $writer->addPrefix($ns, '');
  $writer->startTag([$ns, 'doc']);
  $writer->characters("\n");
  $writer->emptyTag([$ns, 'ptr1']);
  $writer->characters("\n");
  $writer->emptyTag([$ns, 'ptr2']);
  $writer->characters("\n");
  $writer->endTag([$ns, 'doc']);
  $writer->end();
  checkResult(37, <<"EOS");
<doc xmlns="$ns">
<ptr1 />
<ptr2 />
</doc>
EOS
};


# Test 38: Namespace error: attribute name beginning 'xmlns'
TEST: {
  expectError(38, "Attribute name.*begins with 'xmlns'", eval {
    $writer->emptyTag('foo', 'xmlnsxxx' => 'x');
  });
};


# Test 39: Namespace error: Detect an illegal colon in a PI target.
TEST: {
  expectError(39, "PI target.*contains a colon", eval {
    $writer->pi('foo:foo');
  });
};


# Test 40: Namespace error: Detect an illegal colon in an element name.
TEST: {
  expectError(40, "Element name.*contains a colon", eval {
    $writer->emptyTag('foo:foo');
  });
};


# Test 41: Namespace error: Detect an illegal colon in local part of
# an element name.
TEST: {
  expectError(41, "Local part of element name.*contains a colon", eval {
    my $ns = 'http://www.foo.com/';
    $writer->emptyTag([$ns, 'foo:foo']);
  });
};


# Test 42: Namespace error: attribute name containing ':'.
TEST: {
  expectError(42, "Attribute name.*contains ':'", eval {
    $writer->emptyTag('foo', 'foo:bar' => 'x');
  });
};


# Test 43: Namespace error: Detect a colon in the local part of an att name.
TEST: {
  expectError(43, "Local part of attribute name.*contains a colon.", eval {
    my $ns = "http://www.foo.com/";
    $writer->emptyTag('foo', [$ns, 'foo:bar']);
  });
};

1;

__END__
