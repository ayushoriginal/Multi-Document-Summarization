use strict;

use FindBin;
use IPC::Open3;
use FileHandle;

#
# This script will installs and configures MEAD.
#

#
# Constants used in the installation.
# 

my $MEAD_VERSION = "3.10";

#
# NOTE: AJW 9/6
# This is so that I don't mistakenly overwrite the source.
#

if ($FindBin::Bin =~ /source/) {
    die "Cannot run Install.PL in a source directory.\n";
}

#
# BEGIN
#

{

    # make sure that the required modules are 
    # installed.

    my $has_XML_Parser = has_module("XML::Parser");
    my $has_XML_Writer = has_module("XML::Writer");
    my $has_XML_TreeBuilder = has_module("XML::TreeBuilder");
    my $has_Text_Iconv = has_module("Text::Iconv");
    my $has_HTML_Tree = has_module("HTML::Tree");

    # TODO: XML::TreeBuilder.
    unless ($has_XML_Parser && $has_XML_Writer && 
	    $has_XML_TreeBuilder && $has_Text_Iconv && $has_HTML_Tree) {

	my $msg = "MEAD requires the following Perl modules:\n";
	$msg .= "  XML::Parser\n";
	$msg .= "  XML::Writer\n";
	$msg .= "  XML::TreeBuilder\n";
	$msg .= "  Text::Iconv\n\n";
	$msg .= "  HTML::Tree\n\n";
	message($msg);

	&install_XML_Parser() unless $has_XML_Parser;
	&install_XML_Writer() unless $has_XML_Writer;
	&install_XML_TreeBuilder() unless $has_XML_TreeBuilder;
	&install_Text_Iconv() unless $has_Text_Iconv;
	&install_HTML_Tree() unless $has_HTML_Tree;

    } else {

	message("All required modules installed.\n\n\n");

    }
    
    # replace the perl directive in just about all scripts.
    &replace_perl_directives();

    # change some other things around.
    # TODO: the only thing we have to do is to 
    # change the directory in MEAD::MEAD.
    &replace_MEADDIR();

    &build_IDF_DBMs();

    &install_LexRank();

    &install_tf2gen();
    
    # tell the user everything went okay.
    message("MEAD Installation successful.");
    exit(0);

}

sub has_module {
    my $module_name = shift;

    my $writer = new FileHandle;
    my $reader = new FileHandle;
    my $error = new FileHandle;

    my $command = "perl -e \"use lib 'lib', 'lib/arch'; use $module_name;\"";

    open3($writer, $reader, $error, $command);

    my $error_msg = <$error>;

    return length($error_msg) == 0;
}

sub install_XML_Parser {
    message("XML::Parser is not installed on this machine.");
    message("******** Installing XML::Parser ********\n\n");

    chdir "external";
    system "gzip -cd expat-1.95.2.tar.gz | tar xvf -";

    chdir "expat-1.95.2";
    system "./configure --prefix=\"$FindBin::Bin/lib/expat\"";
    system "make";
    system "make install";

    chdir "$FindBin::Bin/external"; 
    system "gzip -cd XML-Parser.2.30.tar.gz | tar xvf -";

    chdir "XML-Parser-2.30";
    my $makefile_command = "perl Makefile.PL";
    $makefile_command .= " EXPATLIBPATH=$FindBin::Bin/lib/expat/lib";
    $makefile_command .= " EXPATINCPATH=$FindBin::Bin/lib/expat/include";
    system $makefile_command;
    system "perl -pi -e 's/-fno-strict-aliasing//' Makefile";
    system "make";

    chdir $FindBin::Bin;

    system "cp -r external/XML-Parser-2.30/blib/lib/* lib";
    system "cp -r external/XML-Parser-2.30/blib/arch/* lib/arch";

    message("******** Done Installing XML::Parser ********\n\n");
}

sub install_HTML_Tree {
    message("HTML::Tree is not installed on this machine.");
    message("******** Installing HTML::Tree ********\n\n");

    chdir "external";
    system "gzip -cd HTML-Tree-3.20.tar.gz | tar xvf -";
    chdir "HTML-Tree-3.20";
    system "perl Makefile.PL";
    system "make";
    chdir "../../";

    system "cp -r external/HTML-Tree-3.20/blib/lib/* lib";
    system "cp -r external/HTML-Tree-3.20/blib/arch/* lib/arch";

    message("******** Done Installing HTML::Tree ********\n\n");
}

sub install_XML_Writer {

    message("XML::Writer is not installed on this machine.");
    message("******** Installing XML::Writer ********\n\n");

    chdir "external";
    system "gzip -cd XML-Writer-0.4.tar.gz | tar xf -";

    chdir "XML-Writer-0.4";
    system "perl Makefile.PL";
    message("\n\n");

    system "make";

    chdir $FindBin::Bin;

    system "cp -r external/XML-Writer-0.4/blib/lib/* lib";
    system "cp -r external/XML-Writer-0.4/blib/arch/* lib/arch";

    message("******** Done Installing XML::Writer ********\n\n");
}

sub install_XML_TreeBuilder {
    message("XML::TreeBuilder is not installed on this machine.");
    message("******** Installing XML::TreeBuilder ********");

    chdir "external";
    system "gzip -cd XML-TreeBuilder-3.08.tar.gz | tar xf -";

    chdir "XML-TreeBuilder-3.08";
    system "perl Makefile.PL";
    message("\n\n");

    system "make";

    chdir $FindBin::Bin;

    system "cp -r external/XML-TreeBuilder-3.08/blib/lib/* lib";
    system "cp -r external/XML-TreeBuilder-3.08/blib/arch/* lib/arch";

    message("******** Done Installing XML::TreeBuilder ********\n\n");
}

sub install_Text_Iconv {

    message("Text::Iconv is not installed on this machine.\n");
    message("******** Installing Text::Iconv ********\n\n");

    chdir "external";
    system "gzip -cd Text-Iconv-1.4.tar.gz | tar xf -";

    chdir "Text-Iconv-1.4";
    system "perl Makefile.PL";
    message("\n\n");

    system "perl -pi -e \'s/-fno-strict-aliasing//\' Makefile";
    message("\n\n");

    system "make";

    chdir $FindBin::Bin;

    system "cp -r external/Text-Iconv-1.4/blib/lib/* lib";
    system "cp -r external/Text-Iconv-1.4/blib/arch/* lib/arch";

    message("******** Done Installing Text::Iconv ********\n\n");

}

sub install_LexRank {
    message("******** Compiling LexRank ********\n");
    chdir "$FindBin::Bin/bin/feature-scripts/lexrank/src";
    system "g++ -c prank.cpp";
    system "g++ prmain.cpp prank.o -o prmain";
    system "cp prmain ../";
    chdir "$FindBin::Bin";
}

sub install_tf2gen {
     message("******** Compiling tf2gen ********\n");
     chdir "$FindBin::Bin/bin/feature-scripts/";
     system "g++ -g -Wall -Wno-sign-compare -o tf2gen tf2gen.cpp";
#    system "g++ prmain.cpp prank.o -o prmain";
#     system "cp tf2gen ../";
     chdir "$FindBin::Bin";
}

#
# Update the #! line in all executables to point to the
# perl binary.  Using fixin causes junk to be appended to 
# the beginning of the file.
#
sub replace_perl_directives {

    my $perl_path = `which perl`;
    chomp $perl_path;

    message("Fixing perl directives:");

    my @files = `ls bin/*.pl bin/feature-scripts/*.pl`;

    foreach my $file (@files) {
	chomp $file;
	message("  $file");
	my $substr = 's|\#\![^\n]*?perl|\#\!' . $perl_path . '|';
	system "perl -pi -e '$substr' $file";
    }

    message("\n");
}

sub replace_MEADDIR {

    message("Fixing \$MEADDIR in MEAD::MEAD\n\n");

    my $meaddir = $FindBin::Bin;
    my $meadpm = "$meaddir/lib/MEAD/MEAD.pm";

    my $substr = 's|\$MEADDIR\s*=[^\n]*|\$MEADDIR = "' . $meaddir . '"\;|m';
    system "perl -pi -e '$substr' $meadpm";

}

sub build_IDF_DBMs {

    message("\nBuilding English IDF DBM:\n");
    system "bin/write-idf.pl etc/enidf etc/enidf.txt";
    message("\n\nBuilding Chinese IDF DBM:\n");
    system "bin/write-idf.pl etc/cnidf etc/cnidf.txt";
    message("\n\n");

}


#
# Prints the specified message to STDOUT, ensuring that it ends in a 
# newline character.
#
sub message {
    my $message_string = shift;
    unless ($message_string =~ /\n$/) {
	$message_string .= "\n";
    }
    print $message_string;
}
