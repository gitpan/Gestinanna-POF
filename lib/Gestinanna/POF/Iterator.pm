package Gestinanna::POF::Iterator;

use base qw(
    Class::Container
);

use Params::Validate qw(:types);

__PACKAGE__->valid_params(
    generator => { type => CODEREF | UNDEF, optional => 1 },
    cleanup   => { type => CODEREF | UNDEF, optional => 1 },
    list      => { type => ARRAYREF | UNDEF, optional => 1 },
    type      => { type => SCALAR | UNDEF, optional => 1 },
    factory   => { isa => 'Gestinanna::POF', optional => 1 },
    limit     => { type => (SCALAR | ARRAYREF | UNDEF), optional => 1 },
);

sub new {
    my $class = shift;

    my $self = $class -> SUPER::new(@_);

    if($self -> {limit}) {
        $self -> {limit} = [ $self -> {limit}, 1 ]
            unless UNIVERSAL::isa($self -> {limit}, 'ARRAY');

        $self -> {limit} = [ @{ $self -> {limit} } ];

        $self -> {limit} -> [0] -= 2; # save the -2 from the top of _next_id

        my $start = $self -> {limit} -> [1];

        my $n = $self -> _next_id;
        $n = $self -> _next_id while $self -> {n} < $start && defined $n;
        $self -> {next_id} = $n;
    }
    else {
        $self -> {next_id} = $self -> _next_id;
        $self -> {limit} = [ undef, 1 ];
    }

    return $self;
}

sub _next_id {
    my $self = shift;

    return if defined( $self -> {limit} -> [0] ) && defined ($self -> {count})
              && $self -> {count} > $self -> {limit} -> [0]; # - 2;

    if($self -> {list}) {
        return $self -> {list} -> [$self -> {n}++]
            if $self -> {n} <= $#{$self -> {list}};
        $self -> discard;
    }
    elsif($self -> {generator}) {
        my $n = $self -> {generator} -> ();
        if(defined $n) {
            $self -> {n} ++;
            return $n;
        }
        $self -> discard;
    }

    return;
}

sub next_id {
    my $self = shift;

    my $next = $self -> {next_id};

    if(defined $next) {
        $self -> {next_id} = $self -> _next_id;

        $self -> {count} ++;
    }

    return $next;
}

sub next {
    my $self = shift;

    return unless $self -> {type} && $self -> {factory};

    my $id = $self -> next_id;
    return unless defined $id;

    return $self -> {factory} -> new($self -> {type}, object_id => $id);
}

sub position { $_[0] -> {n} > 1 ? $_[0]->{n}-1 : undef }

sub is_first { $_[0] -> {count} == 1 }

sub is_last { !defined $_[0]->{next_id} }

sub has_next { defined $_[0] -> {next_id} }

sub get_all_ids {
    my $self = shift;

    my @ids;

    my $id;
    push @ids, $id while $id = $self -> next_id;

    warn "Returning ids: [" . join("; ", @ids) . "]\n";

    return \@ids;
}

sub get_all {
    my $self = shift;

    my @obs;

    my $ob;
    push @obs, $ob while $ob = $self -> next;

    return \@obs;
}

sub discard {
    my $self = shift;

    $self -> {next_id} = undef;
    delete $self -> {list};
    delete $self -> {generator};

    $self -> {cleanup} -> () if $self -> {cleanup};

    delete $self -> {cleanup};
}

sub DESTROY {
    my $self = shift;

    $self -> discard;
}

1;

__END__

=head1 NAME

Gestinanna::POF::Iterator - Search result iterator

=head1 SYNOPSIS

Returned from data store object:

 Gestinanna::POF::Iterator -> new(
     factory => $factory,
     type => $type,
     limit => $limit,
     %list_params
 );

In user code:

 $cursor = $factory -> find(type => (
      where => [ ... ],
      limit => [ min, max ],
 ));

 while($obj = $cursor -> next) { }
 while($id = $cursor -> next_id) { }

 $cursor -> is_first;
 $cursor -> has_next;
 $cursor -> is_last;

 $cursor -> position;

 @obs = $cursor -> get_all;
 @ids = $cursor -> get_all_ids;

 $cursor -> discard;

=head1 DESCRIPTION

The C<find> method available in the factory and in the data store 
objects returns an iterator object.

=head1 CREATING AN ITERATOR

Iterators should only be created from within a data store's C<find> 
method (or similar).  There are two different ways to create a useful 
iterator.

Both methods of creating an iterator accept three arguments in common:

=over 4

=item factory

 factory => $factory

This is a factory object which can create objects of the type stored 
in the data store the iterator is for.

If this is defined, then the object methods will be able to create 
objects as needed (i.e., C<get_all> and C<next>).

=item limit

 limit => $limit

If this is a scalar, then this indicates how many objects or object 
identifiers to iterate over, beginning with the first.

 limit => [ $limit, $offset ]

If this is an array reference with two elements, then objects or object 
identifiers are returned starting at C<$offset> with no more than 
C<$limit> objects or object identifiers being returned.  If C<$offset> 
is undefined, then it indicates the beginning of the sequence.  If 
C<$limit> is undefined, then iteration begins at C<$offset> and 
continues until there are no objects or object identifiers left.

=item type

 type => $type

This is the type that the object is known as within the factory:

 $type = $factory -> get_object_type($class);

If this is defined, then the object methods will be able to create 
objects as needed (i.e., C<get_all> and C<next>).

=back

=head2 Creating From a List

The easiest way is to build up an array of object ids and give the 
iterator constructor a reference to this array.

 $cursor = Iterator::Class -> new(
   list => [ ... ],
   limit => ...,
   factory => $factory,
   type => $object_type,
 );

The resulting iterator will step through the list of object ids, returning 
C<undef> when it is exhausted.  It will use the given factory object and 
object type to create objects if needed.  If the factory and object type 
are not given, then only object identifiers will be available.

For objects based on L<Gestinanna::POF::Container|Gestinanna::POF::Controller> 
(or similar consolidating objects) to work correctly, the list of 
object identifiers must be sorted in ascending order (a simple C<sort @list> 
should suffice).

=head2 Creating from a Generating Function

The best way to conserve memory and time for potentially large or 
expensive lists of object identifiers is to pass a code reference that 
will return an object identifier on each call (or C<undef> if there 
are no more identifiers).

 $cursor = Iterator::Class -> new(
   generator => sub { ... },
   cleanup => sub { ... },
   limit => ...,
   factory => $factory,
   type => $type,
 );

The resulting iterator will call the C<generator> function each time a 
new object identifier is needed.

=head1 USER METHODS

The following methods are available for code using an iterator instance.

=head2 discard

Calling this method tells the iterator to release any resources it might have held.

=head2 get_all

Returns the remaining list of objects in the search results.

=head2 get_all_ids

Returns the remaining list of object identifiers in the search results.

=head2 has_next

Returns true if there is at least one more object identifier or object 
in the search results.

=head2 is_first

Returns true if the most recently returned object or identifier 
is the first object or identifier returned by the iterator.

=head2 is_last

This is true if the most recently returned object or object identifier 
is the last object or object identifier in the search results.  Any 
subsequent calls to C<next> or C<next_id> should return C<undef>.  
This should return the opposite truth of C<has_next>.

=head2 next

This will retrieve the next identifier of an object that satisfies the 
search criteria and return the object associated with the identifier.  
If no such object identifier or object exists, then C<undef> is returned,
indicating that there are no more search results.

=head2 next_id

This will retrieve and return the next object identifier of an object 
that satisfies the search criteria.  If no such object exists, then 
C<undef> is returned, indicating that there are no more search results.

=head2 position

This will return the position of the most recently returned object or 
object identifier.  If no objects or object identifiers have been 
returned, then this will be C<undef>.

=head1 BUGS

Please report bugs to either the request tracker for CPAN
(L<http://rt.cpan.org/|http://rt.cpan.org/>) or at the SourceForge project
(L<http://sourceforge.net/projects/gestinanna/|http://sourceforge.net/projects/gestinanna/>).

=head1 AUTHOR

James G. Smith, <jsmith@cpan.org>

=head1 COPYRIGHT

Copyright (C) 2002-2003 Texas A&M University.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.  

