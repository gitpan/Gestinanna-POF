package Gestinanna::POF;

use base (Class::Factory);

use Gestinanna::POF::Iterator;
use Carp;
use strict;

our $VERSION = '0.07';

our $REVISION = substr(q$Revision: 1.14 $, 10);

sub new {
    my $self = shift;

    if($_[0] eq '_factory') {
        shift;
        $self = bless { %{(ref($self) ? $self : {})}, @_ } => (ref $self || $self);
        $self -> {_factory} = $self;
        return $self;
    }

    return $self -> SUPER::new(@_) unless ref $self;

    my($type, @params) = @_;

    return $self -> SUPER::new($type, $self -> _params($type), @params);

    #if($class && $class -> isa('Class::Container')) {
        # we need to find out all the allowed arguments
    #    my @allowed = keys(%{ $class -> allowed_params() });
#
#        return $self -> SUPER::new($type, 
#            (map { $_ => $self->{$_} } grep { exists $self -> {$_} } @allowed),
#            @params
#        );
#    }
#    else {
#        return $self -> SUPER::new($type, @params);
#    }
}

#%Gestinanna::POF::RESOURCES;

sub set_resources {
    my($class, $type, $resources) = @_;

    $class = ref $class || $class;

    $Gestinanna::POF::RESOURCES{$class}{$type} = \%{$resources};
}

sub _params {
    my($self, $type) = @_;

    my $class = $self -> get_factory_class($type);
    my $self_class = ref $self || $self;

    return ( ) unless $class && $class -> isa('Class::Container');

    my @allowed = keys(%{ $class -> allowed_params() });
    return (
        map {
            my $resource;
            my $resource_id;
            my $source;
            if($resource_id = $Gestinanna::POF::RESOURCES{$self_class}{$type}{$_}) {
                $source = $self -> {_resources} -> {$resource_id};
            }
            if(!defined $source) {
                $source = $self -> {$_};
            }
            if(UNIVERSAL::isa($source, 'ResourcePool') || UNIVERSAL::isa($source, 'ResourcePool::LoadBalancer')) {
                #$resource = $source -> get();
                if($resource_id) {
                    $resource = $self -> {_resources} -> {_fetched} -> {$resource_id} ||= $source -> get;
                }
                else {
                    $resource = $self -> {_fetched} -> {$_} ||= $source -> get;
                }
            }
            else {
                $resource = $source;
            }
            (defined $resource ? ($_ => $resource) : ( ) );
        }
        @allowed
    );
}

sub DESTROY {
    my $self = shift;

    foreach my $r ($self, $self -> {_resources}) {
        foreach my $k ( keys %{$r -> {_fetched} || {}} ) {
            $r -> {$k} -> free($r -> {_fetched} -> {$k});
        }
    }
}

sub find {
    my $self = shift;

    return unless ref $self; # need the %params stuff

    my($type, %params) = @_;

    my $class = $self -> get_factory_class($type);

    if($class) {
        my $cursor;

        eval {
            $cursor = $class -> find($self -> _params($type), %params, _factory => $self -> {_factory});
        };
        my $e = $@;
        if(chomp($e)) {
            $e =~ s{\sat\s.*?\sline\s\d+\.?$}{};
        }
        croak $e if $e;
        return $cursor;
    }

    return Gestinanna::POF::Iterator -> new(
        list => [ ],
    );
}

sub init {
    my($self, %params) = @_;

    %$self = %params;
    return $self;
}

my %OBJECT_TYPES = ( );

# not optimized, but we'll see what profiling shows later
sub get_object_type {
    my($self, $obclass) = @_;

    $self = ref $self || $self;
    $obclass = ref $obclass || $obclass;

    return $OBJECT_TYPES{$self}{$obclass} if exists $OBJECT_TYPES{$self}{$obclass};

    my @classes = grep { $self -> get_factory_class($_) eq $obclass }
                       ($self -> get_loaded_types, $self -> get_registered_types);

    return($OBJECT_TYPES{$self}{$obclass} = $classes[0]) if @classes;

    return;
}

1;

__END__

=head1 NAME

Gestinanna::POF - Gestinanna Persistant Object Framework

=head1 SYNOPSIS

 package My::POF::Factory;

 use base q(Gestinanna::POF);

 package main;

 My::POF::Factory -> register_factory_type( $type => $class );
 My::POF::Factory -> add_factory_type( $type => $class);
 My::POF::Factory -> set_resource( $type => { resource mapping } );

 My::POF::Factory -> new( $type, @params );

 $factory = My::POF::Factory -> ( 
     _factory => ( 
         %presets, 
         _resources => { resource mapping } 
     ) 
 );

 $object = $factory -> new( $type => ( object_id => $id ) );

 $cursor = $factory -> find( $type => ( 
     where => [ ... ], 
     limit => [ ... ] 
 ) );

 while($id = $cursor -> next_id) { }
 while($ob = $cursor -> next) { }

=head1 DESCRIPTION

The Gestinanna Persistant Object Framework is designed to work with 
the Gestinanna application framework currently under development.
This framework consists of two major parts: the object factory and the 
object classes.

The object factory is based on this module, Gestinanna::POF.  A 
particular factory is an instance of a custom class that inherits from 
Gestinanna::POF so that object type to Perl class mappings can be kept 
segregated.  The factory instance can also track some of the attributes 
that might be needed to create objects.  This allows such things as 
data sources to be configured in the factory.  The code that needs a 
particular object doesn't need to know where the data for that object 
comes from or even which Perl class is used to construct the object.

Object factories keep track of which class to use for constructing a 
particular object.  These mappings are created by calling the 
C<register_factory_type> or C<add_factory_type> static methods.  See 
L<Class::Factory> for more information on these methods.

See the various object base classes for more information on how to use 
them.  The base classes included with Gestinanna::POF are

=over 4

=item L<Gestinanna::POF::Base|Gestinanna::POF::Base>

The base class used to define the various data store classes.  Don't 
use this except when defining a class for a new, previously unsupported,
data store.

=item L<Gestinanna::POF::Alzabo|Gestinanna::POF::Alzabo>

This class allows objects to be created from rows in an RDBMS (SQL) 
table using the L<Alzabo|Alzabo> schema management system.

=item L<Gestinanna::POF::Container|Gestinanna::POF::Container>

This class allows objects to be defined as aglomerations of other data 
classes and object types.

=item L<Gestinanna::POF::LDAP|Gestinanna::POF::LDAP>

This class allows objects to be defined using entries from an LDAP directory.

=item L<Gestinanna::POF::MLDBM|Gestinanna::POF::MLDBM>

This class allows objects to be entries in an L<MLDBM|MLDBM> file.

=back

In addition to simple data access, support is provided for attribute-level 
security.  See L<Gestinanna::POF::Secure> for more information.

=head1 NAMESPACES

The tertiary C<Gestinanna::POF::*> namespace should be used for general 
data store modules (e.g., C<Gestinanna::POF::Alzabo>).  This namespace 
should not be used for modules directly instantiated by the factory 
(e.g., a table-specific sub-class of C<Gestinanna::POF::Alzabo>).

General security policy implementations may reside in C<Gestinanna::POF::Secure::*>.

Lock implementations may reside in C<Gestinanna::POF::Lock::*>.

=head1 METHODS

The following methods are defined in addition to the methods 
inherited from L<Class::Factory|Class::Factory>.

=over 4

=item get_object_type

 $type = Gestinanna::POF -> get_object_type($object_class |  $object)

Given either an object or its class, this will return the object 
type the class is associated with.  If the class is associated 
with more than one object type,  the return value is undefined 
(the first match is returned).

The object type may be used to create a new object of this type:

 Gestinanna::POF -> new($type => %params);

If the object class is not known to Gestinanna::POF then C<undef> is returned.

=item Gestinanna::POF -> new(_factory => %params)

This will return a Gestinanna::POF object with C<%params> as 
default parameters for further object creation.  This is useful 
for specifying default Alzabo schemas or actors for secured object 
types.  Default parameters that are not appropriate for the 
requested object type are not passed to the object during creation.

=item $factory -> find($type => %params);

*** This is still in development ***

Given a factory object, this will return an iterator which will 
iterate over all the objects of type C<$type> that match the C<where> 
parameter.  Other parameters may be passed 
to override specific parameters that are stored in the factory object.

For example:

 $cursor = $factory -> find(user => (
    where => [ 'age', '>', '18' ],
    limit => 5,
 ));

 while($object = $cursor -> next) {
     ...
 }

 while($id = $cursor -> next_id) {
     ...
 }

This will iterate through all the users with an age of more than 18 
(or five, whichever is less).  The limit is optional.

Since the criteria are parsed in the basic data store objects, see 
L<Gestinanna::POF::Base> for a more detailed explanation of the 
criteria syntax.

N.B.: This is not the most efficient way to find objects.  It is 
currently the only way within this framework to do a search that is 
independent of the underlying data store, though.  Due to requirements 
for consolidating lazy iterators in L<Gestinanna::POF::Container|Gestinanna::POF::Container>, 
some iterators are not as efficient as they could be (e.g., the MLDBM 
iterator must create a list of all the keys and then sort them, though 
finding the next valid object identifier is done lazily).

=back

=head1 SEE ALSO

L<Class::Factory>,
L<Gestinanna::POF::Base>,
L<Gestinanna::POF::Container>,
L<Gestinanna::POF::Iterator>,
L<Gestinanna::POF::Lock>,
L<Gestinanna::POF::Secure>.

=head1 BUGS

Please report bugs to either the request tracker for CPAN 
(L<http://rt.cpan.org/|http://rt.cpan.org/>) or at the SourceForge project 
(L<http://sourceforge.net/projects/gestinanna/|http://sourceforge.net/projects/gestinanna/>).

=head1 AUTHOR

James G. Smith, <jsmith@cpan.org>

=head1 COPYRIGHT

Copyright (C) 2002-2004 Texas A&M University.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
