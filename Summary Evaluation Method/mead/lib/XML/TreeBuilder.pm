
require 5;
package XML::TreeBuilder;
#Time-stamp: "2000-11-03 17:14:16 MST"
use strict;
use XML::Element ();
use XML::Parser ();
use vars qw(@ISA $VERSION);

$VERSION = '3.08';
@ISA = ('XML::Element');

#==========================================================================
sub new {
  my $class = ref($_[0]) || $_[0];
  # that's the only parameter it knows
  
  my $self = XML::Element->new('NIL');
  bless $self, $class; # and rebless
  $self->{'_element_class'} = 'XML::Element';
  $self->{'_store_comments'}     = 0;
  $self->{'_store_pis'}          = 0;
  $self->{'_store_declarations'} = 0;
  
  my @stack;
  # Compare the simplicity of this to the sheer nastiness of HTML::TreeBuilder!
  
  $self->{'_xml_parser'} = XML::Parser->new( 'Handlers' => {
    'Start' => sub {
      shift;
      if(@stack) {
         push @stack, $self->{'_element_class'}->new(@_);
         $stack[-2]->push_content( $stack[-1] );
       } else {
         $self->tag(shift);
         while(@_) { $self->attr(splice(@_,0,2)) };
         push @stack, $self;
       }
    },
    
    'End'  => sub { pop @stack; return },
    
    'Char' => sub { $stack[-1]->push_content($_[1]) },
    
    'Comment' => sub {
       return unless $self->{'_store_comments'};
       (
        @stack ? $stack[-1] : $self
       )->push_content(
         $self->{'_element_class'}->new('~comment', 'text' => $_[1])
       );
       return;
    },
    
    'Proc' => sub {
       return unless $self->{'_store_pis'};
       (
        @stack ? $stack[-1] : $self
       )->push_content(
         $self->{'_element_class'}->new('~pi', 'text' => "$_[1] $_[2]")
       );
       return;
    },
    
    # And now, declarations:
    
    'Attlist' => sub {
       return unless $self->{'_store_declarations'};
       shift;
       (
        @stack ? $stack[-1] : $self
       )->push_content(
         $self->{'_element_class'}->new('~declaration',
          'text' => join ' ', 'ATTLIST', @_
         )
       );
       return;
    },
    
    'Element' => sub {
       return unless $self->{'_store_declarations'};
       shift;
       (
        @stack ? $stack[-1] : $self
       )->push_content(
         $self->{'_element_class'}->new('~declaration',
          'text' => join ' ', 'ELEMENT', @_
         )
       );
       return;
    },
    
    'Doctype' => sub {
       return unless $self->{'_store_declarations'};
       shift;
       (
        @stack ? $stack[-1] : $self
       )->push_content(
         $self->{'_element_class'}->new('~declaration',
          'text' => join ' ', 'DOCTYPE', @_
         )
       );
       return;
    },
    
  });
  
  return $self;
}
#==========================================================================
sub _elem # universal accessor...
{
  my($self, $elem, $val) = @_;
  my $old = $self->{$elem};
  $self->{$elem} = $val if defined $val;
  return $old;
}

sub store_comments { shift->_elem('_store_comments', @_); }
sub store_declarations { shift->_elem('_store_declarations', @_); }
sub store_pis      { shift->_elem('_store_pis', @_); }

#==========================================================================

sub parse {
  shift->{'_xml_parser'}->parse(@_);
}

sub parse_file { shift->parsefile(@_) } # alias

sub parsefile {
  shift->{'_xml_parser'}->parsefile(@_);
}

sub eof {
  delete shift->{'_xml_parser'}; # sure, why not?
}

#==========================================================================
1;

__END__


=head1 NAME

XML::TreeBuilder - Parser that builds a tree of XML::Element objects

=head1 SYNOPSIS

  foreach my $file_name (@ARGV) {
    my $tree = XML::TreeBuilder->new; # empty tree
    $tree->parse_file($file_name);
    print "Hey, here's a dump of the parse tree of $file_name:\n";
    $tree->dump; # a method we inherit from XML::Element
    print "And here it is, bizarrely rerendered as XML:\n",
      $tree->as_XML, "\n";
    
    # Now that we're done with it, we must destroy it.
    $tree = $tree->delete;
  }

=head1 DESCRIPTION

This module uses XML::Parser to make XML document trees constructed of
XML::Element objects (and XML::Element is a subclass of HTML::Element
adapted for XML).  XML::TreeBuilder is meant particularly for people
who are used to the HTML::TreeBuilder / HTML::Element interface to
document trees, and who don't want to learn some other document
interface like XML::Twig or XML::DOM.

The way to use this class is to:

1. start a new (empty) XML::TreeBuilder object.

2. set any of the "store" options you want.

3. then parse the document from a source by calling
C<$x-E<gt>parsefile(...)>
or
C<$x-E<gt>parse(...)> (See L<XML::Parser> docs for the options
that these two methods take)

4. do whatever you need to do with the syntax tree, presumably
involving traversing it looking for some bit of information in it,

5. and finally, when you're done with the tree, call $tree->delete to
erase the contents of the tree from memory.  This kind of thing
usually isn't necessary with most Perl objects, but it's necessary for
TreeBuilder objects.  See L<HTML::Element> for a more verbose
explanation of why this is the case.

=head1 METHODS AND ATTRIBUTES

XML::TreeBuilder is a subclass of XML::Element, which in turn is a subclass
of HTML:Element.  You should read and understand the documentation for
those two modules.

An XML::TreeBuilder object is just a special XML::Element object that
allows you to call these additional methods:

=over

=item $root = XML::TreeBuilder->new()

Construct a new XML::TreeBuilder object.

=item $root->parse(...options...)

Uses XML::Parser's C<parse> method to parse XML from the source(s?)
specified by the options.  See L<XML::Parse>

=item $root->parsefile(...options...)

Uses XML::Parser's C<parsefile> method to parse XML from the source(s?)
specified by the options.  See L<XML::Parse>

=item $root->parse_file(...options...)

Simply an alias for C<parsefile>.

=item $root->store_comments(value)

This determines whether TreeBuilder will normally store comments found
while parsing content into C<$root>.  Currently, this is off by default.

=item $root->store_declarations(value)

This determines whether TreeBuilder will normally store markup
declarations found while parsing content into C<$root>.  Currently,
this is off by default.

=item $root->store_pis(value)

This determines whether TreeBuilder will normally store processing
instructions found while parsing content into C<$root>.
Currently, this is off (false) by default.

=back

=head1 SEE ALSO

L<XML::Parser>, L<XML::Element>, L<HTML::TreeBuilder>, L<HTML::DOMbo>.

And for alternate XML document interfaces, L<XML::DOM> and L<XML::Twig>.

=head1 COPYRIGHT

Copyright 2000 Sean M. Burke.

=head1 AUTHOR

Sean M. Burke, E<lt>sburke@cpan.orgE<gt>

=cut

