# Copyright (c) 2004 Timothy Appnel
# http://www.timaoutloud.org/
# This code is released under the Artistic License.
#
# XML::Parser::Style::Elemental - A slightly more advanced object 
# tree style for XML::Parser.
# 

package XML::Parser::Style::Elemental;

use strict;
use vars qw($VERSION);
$VERSION = '0.41';

sub Init { 
    my $xp = shift;
    $xp->{Elemental} ||= {};
    my $e = $xp->{Elemental};
    $e->{Document} ? 
        eval "use $e->{Document};" : 
            compile_class($xp,'Document');
    $e->{Element} ? 
        eval "use $e->{Element};" : 
            compile_class($xp,'Element');
    $e->{Characters} ? 
        eval "use $e->{Characters};" : 
            compile_class($xp,'Characters');
    $xp->{__doc} = $e->{Document}->new();
    push( @{ $xp->{__stack} }, $xp->{__doc} );
    # $xp->{__NSMAP} = {} if ($xp->{NSMap}); 
}

sub Start {
    my $xp = shift;
    my $tag = shift;
    my $node = $xp->{Elemental}->{Element}->new();
    $node->name( ns_qualify($xp,$tag) );
    $node->parent( $xp->{__stack}->[-1] );
    if (@_) {
        $node->attributes({});        
        while (@_) { 
            my($key,$value) = (shift @_,shift @_);
            $node->attributes->{ns_qualify($xp,$key,$tag)} = $value 
        }
    }
    $node->parent->contents([]) unless $node->parent->contents; 
 	push( @{ $node->parent->contents }, $node);
	push( @{ $xp->{__stack} }, $node);
	#if ($xp->{NSMap} && $xp->new_ns_prefixes) {
	#    my %newns;
    #    map { $newns{$_} = $xp->expand_ns_prefix($_) }
    #        $xp->new_ns_prefixes;
    #    $xp->{__NSMAP}->{$node} = \%newns;
    #}
}

sub Char {
    my ($xp,$data)=@_;
    my $parent = $xp->{__stack}->[-1];
    $parent->contents([]) unless $parent->contents;
    my $contents = $parent->contents();
    my $class = $xp->{Elemental}->{Characters}; 
    unless ($contents && ref($contents->[-1]) eq $class) {
        return if ($xp->{Elemental}->{No_Whitespace} && $data!~/\S/);
        my $node = $class->new();
        $node->parent($parent);
        $node->data($data);
        push ( @{ $contents }, $node );
    } else {
        my $d = $contents->[-1]->data() || '';
        return if ( $xp->{Elemental}->{No_Whitespace} && $d!~/\S/ );
        $contents->[-1]->data("$d$data");
    }
}

sub End { pop( @{ $_[0]->{__stack} } ) }

sub Final {
    delete $_[0]->{__stack};
    $_[0]->{__doc}; # , $_[0]->{__NSMAP}; 
}

sub ns_qualify { 
    return $_[1] unless $_[0]->{Namespaces}; 
    my $ns=$_[0]->namespace($_[1]) || 
            ( $_[2] ? $_[0]->namespace($_[2]) : return $_[1] );
    $ns=~m!(/|#)$! ? "$ns$_[1]" : "$ns/$_[1]";
}

#--- Dynamic Class Factory
{
    my $methods = {
            Document => [ qw(contents) ],
            Element => [ qw(name parent contents attributes) ],
            Characters => [ qw(parent data) ]
    };
    
    sub compile_class {    
        my $xp = shift;
        my $type = shift;
        my $class = "${$xp}{Pkg}::$type";
        no strict 'refs';
        *{"${class}::new"} = sub { bless { }, $class };
        foreach my $field ( @{$methods->{$type}} ) {
            *{"${class}::${field}"} = 
                sub { 
                    $_[0]->{$field} = $_[1] if defined $_[1];
                    $_[0]->{$field};
                }
        }
        $xp->{Elemental}->{$type} = $class;
    }
}

1;

__END__

=begin

=head1 NAME

XML::Parser::Style::Elemental - a slightly more advanced and flexible 
object tree style for XML::Parser

=head1 SYNOPSIS

 #!/usr/bin/perl -w
 use XML::Parser;
 use Data::Dumper;
 my $p = XML::Parser->new( Style => 'Elemental', Pkg => 'E' );
 my $doc = <<DOC;
 <foo>
   <bar key="value">The world is foo enough.</bar>
 </foo>
 DOC
 my ($e) = $p->parse($doc);
 print Data::Dumper->Dump( [$e] );

=head1 DESCRIPTION

This module is similar to the L<XML::Parser> Objects style, but 
slightly more advanced and flexible. Like the Objects style, an 
object is created for each element. Elemental uses a dynamic class 
factory to create objects with accessor methods or can use any 
supplied classes that support the same method signatures. This module
also provides full namespace support when the C<Namespace> option is in
use in addition to a C<No_Whitespace> option for stripping out 
extraneous non-markup characters that are commonly introduced 
when formatting XML to be human readable.

=head1 CLASS TYPES

Elemental style creates its parse tree with three class types --
Document, Element and Character. Developers have the option 
of using the built-in dynamic classes or registering their own. 
The following explains the purpose and method prototypes of each 
class type.

=item Document - The root of the tree.

=over 4

=item contents - An array reference of direct decendents.

=back

=item Element - The tags in the document. 

=over 4

=item name - The tag name. If the Namespace options is set to true, 
the extend name is stored.

=item parent - A reference to the parent object.

=item contents - An ordered array reference of direct 
descendents/children objects.

=item attributes - A hash reference of key-value pairs representing
the tags attributes.

=back

=item Characters - Non-markup text. 

=over 4

=item data - A string of non-markup characters.

=item parent - A reference to the parent object.

=back

=head1 OPTIONS

Elemental specific options are set in the L<XML::Parser> constructor
through a hash element with a key of 'Elemental', The value of 
Elemental is expected to be a hash reference with one of more of the
option keys detailed in the following sections.

=head2 USING DYNAMIC CLASS OBJECTS

When parsing a document, Elemental uses a dynamic class factory to 
create minimal lightweight objects with accessor methods. These 
classes implement the pattern detailed in L<CLASS TYPES> in addition 
to a parameterless constructor method of C<new>. Similar to the 
Objects style these classes are blessed into the package set with 
the C<Pkg> option. 

Here we create a parser that uses Elemental to create Document, Element
and Characters objects in the E package.

 my $p = XML::Parser->new( Style => 'Elemental', Pkg => 'E' );

=head2 REGISTERING CLASSES

If you require something more functional then the generated dynamic 
classes you can register your own with Elemental. Like the Elemental
class types, the option keys are C<Document>, C<Element> and 
C<Characters>. Here we register three classes and turn on the 
C<No_Whitespace> option.

 my $p = XML::Parser->new(  Style => 'Elemental',
                            Namespace => 1,
                            Elemental=>{
                                    Document=>'Foo::Doc',
                                    Element=>'Foo::El',
                                    Characters=>'Foo::Chars',
                                    No_Whitespace=>1
                            }
                         );

Note that, the same class can be registered for more then one class type as long 
as it supports all of the necessary method prototypes it is being 
registered to handle. See L<CLASS TYPES> for more detail.

=head2 NO_WHITESPACE

When set to true, C<No_Whitespace> causes Elemental to pass over character
strings of all whitespace instead of creating a new Character object. This
options is helpful in stripping out extraneous non-markup characters that 
are commonly introduced when formatting XML to be human readable.

=head1 SEE ALSO

L<XML::Parser::Style::Objects>

=head1 LICENSE

The software is released under the Artistic License. The terms of 
the Artistic License are described at 
L<http://www.perl.com/language/misc/Artistic.html>.

=head1 AUTHOR & COPYRIGHT

Except where otherwise noted, XML::Parser::Style::Elemental is 
Copyright 2004, Timothy Appnel, cpan@timaoutloud.org. All rights 
reserved.

=cut

=end