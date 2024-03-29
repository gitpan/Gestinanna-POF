package Gestinanna::POF::Base;

use base qw(
    Class::Container
    Class::Accessor
    Class::Fields
    );

use Class::ISA ();
use Params::Validate qw(:types);

use Carp;

use vars qw($AUTOLOAD);

our $VERSION = '0.02';

our $REVISION = 'something';

use public qw(object_id Commit);
use private qw(_factory);

__PACKAGE__->valid_params (
    object_id   => { type => SCALAR | UNDEF, optional => 1},
    Commit      => { type => SCALAR, optional => 1},
    _factory    => { isa => 'Gestinanna::POF' },
);

use constant object_ids => [qw(object_id)];

use strict;

sub object_id {
    my $self = shift;

    my $fields = $self -> object_ids;

    #if(@$fields == 1) {
    #    my $f = $fields -> [0];
    #    return $self -> $f;
    #}

    #warn "object_id fields: ", join(", ", @$fields), "\n";

    my %attrs = map { defined($self -> {$_}) ? ($_ => $self -> {$_}) : () } @$fields;

    #warn "object_id attributes: ", Data::Dumper -> Dump([\%attrs]);

    if(1 == keys %attrs) {
        return( (values %attrs)[0] );
    }
     
    foreach my $attr (keys %attrs) {
        $attrs{$attr} =~ s{([\\,=()])}{\\$1}; 
    } 

    return join(",", map { "$_=$attrs{$_}" } keys %attrs);
}

sub process_object_id {
    my($self, $objectid, %params) = @_;

    #main::diag("$self -> process_object_id($objectid, ...)");

    my %attrs;

    my $keys = $self -> object_ids;

    $keys = [ $keys] unless ref $keys;

    #main::diag("object ids: " . join(", ", @$keys));

    if($objectid =~ m{=}) {
        # N.B.: These regular expressions are being applied in _reverse_
        #       so that we can do variable-length look-behind assertions.
        #warn "object id: $objectid\n";
        my @pairs = split(/\s*,(?:\\\\)*(?=[^\\])/, reverse $objectid);
        #warn "Pairs: " . join("; ", @pairs) . "\n";
        %attrs = map {
                     map {
                         $_ = reverse $_
                     } reverse split(/=(?:\\\\)*(?=[^\\])/, $_, 2)
                 } @pairs;
    }
    elsif(@$keys == 1) {
        $attrs{$keys->[0]} = $objectid;
    }

    #main::diag("Keys found in object id: " . join(", ", keys %attrs));

    $attrs{$keys->[0]} = $objectid
        unless keys %attrs;
    
    my %attrs_for_this_ob = map { $_ => $params{$_} } grep { defined $params{$_} } @$keys;
    %attrs_for_this_ob = map { $_ => $attrs{$_} } grep { defined $attrs{$_} } @$keys;

    #main::diag("Attributes for this ob: " . Data::Dumper -> Dump([\%attrs_for_this_ob]));

    #$self = $self -> SUPER::new(%params, %attrs_for_this_ob);
    if(keys %attrs_for_this_ob) {
        @$self{keys %attrs_for_this_ob} = values %attrs_for_this_ob;

        use Data::Dumper;
        #main::diag("Attrs from object id: " . Data::Dumper -> Dump([\%attrs_for_this_ob]));
        #main::diag("Object id: " . $self -> object_id);

        return 1;
    }

    return 0;
}

# for Gestinanna::POF -- Class::Factory stuff
sub init {
    my($self, %params) = @_;

    $self = $self -> SUPER::new(%params);

    if($self -> process_object_id(delete $params{object_id}, %params)) {
        $self -> load;
    }

    return $self;
}

sub attributes {
    my $self = shift;

    # returns the attributes defined by this class
    #return $self -> show_fields('Public');
    my @attrs = $self -> show_fields('Public');
    
    push @attrs, @{$self -> object_ids || []};
    
    return keys %{ +{map {$_ => undef} @attrs } };  # make them unique
}

sub make_accessor {
    my $class = shift;
    my $field = shift;

    my $accessor = $class -> SUPER::make_accessor($field);

    return $accessor if $field eq 'Commit';

    return sub {
        return if @_ > 1 && defined $_[0] -> {object_id};
        goto &$accessor;
    } if $field eq 'object_id';

    #my %ids = map {$_ => undef} @{$class -> object_ids || []};

    return sub {
        return if @_ > 1;
        goto &$accessor;
    } if $class -> is_object_id($field);

    return sub {
        return unless @_ > 1 ? !$_[0] -> is_object_id($field)
                                 && $_[0] -> has_access($field, [ qw(write) ])
                             : $_[0] -> has_access($field, [ qw(read) ]);
        goto &$accessor;
    };
}

sub is_object_id {
    my($self, $field) = @_;

    return 0 + grep { $_ eq $field } @{$self -> object_ids || []};
}

sub compare {
    my($self, $field, $value) = @_;

    return unless $self -> is_public($field);

    return unless $self -> has_access($field, [ [ qw(search compare) ] ]);

    return $self -> {$field} eq $value;
}

sub find {
    my $class = ref $_[0] || $_[0];

    carp "$class -> find() is not implemented";
}

sub AUTOLOAD {
    my $self = $_[0];
    my $class = ref $self;

    my($field) = $AUTOLOAD =~ /::([^:]+)$/;

    return if $field eq 'DESTROY';

    # If it's a public field, set up a named closure as its
    # data accessor.
    if ( $self->is_public($field) ) {
        no strict 'refs';
        *{$class."::$field"} = $self -> make_accessor($field); # sometimes we need an instance
        goto &{$class."::$field"};
    } else {
        carp "'$field' is not a public data member of '$class'";
    }
}

# following private method is crufty
sub _get_contained_args
{
    my ($class, $name, $args) = @_;

    my $spec = $class->get_contained_object_spec->{$name}
      or die "Unknown contained object '$name'";

    my $contained_class = $args->{"${name}_class"} || $spec->{class};
    die "Invalid class name '$contained_class'"
        unless $contained_class =~ /^[\w:]+$/;

    $class->_load_module($contained_class);
    return ($contained_class, {}) unless $contained_class->isa(__PACKAGE__);

    my $allowed = $contained_class->allowed_params($args);

    my %contained_args;
    foreach (keys %$allowed) {
        $contained_args{$_} = $args->{$_} if exists $args->{$_};
        # allow parameters to be specific to a contained object
        # (allows general parameters and different tables, for example, for Alzabo objects)
        # except for these 4 lines (3 comments plus following), this is taken from Class::Container
        $contained_args{$_} = $args->{"${name}_$_"} if exists $args->{"${name}_$_"};
    }
    return ($contained_class, \%contained_args);
}

sub has_access { return 1; }

sub is_live { return 0; }

sub is_secured { return 0; }

sub is_lockable { return 0; }

sub lock { return 0; }

sub unlock { return 0; }

sub is_locked { return 0; }

sub object_type {
    my $self = shift;

    my $class = ref $self || $self;

    return unless defined $self -> {_factory};

    return $self -> {_factory} -> get_object_type($class);
}

sub save {
    my $self = shift;
    my $class = ref $self || $self;
    warn "$class->save() needs to be implemented\n";
}

sub load {
    my $self = shift;
    my $class = ref $self || $self;
    warn "$class->load() needs to be implemented\n";
}

sub delete {
    my $self = shift;
    my $class = ref $self || $self;
    warn "$class->delete() needs to be implemented\n";
}

sub start_transaction {  
    my $self = shift;

    if($self -> {_transaction}) {
        my $t = $self -> {_transaction};
        $self -> {_transaction} = {
            rollback => [ ],
            transaction => $t,
        };
    }
}

sub log_transaction_rollback {
    my($self, @code) = @_;

    return unless $self -> {_transaction};
    #unshift @{$t -> {_transaction} -> {rollback}}, @code;
}
   
sub commit_transaction {  
    my $self = shift;

    # we can discard the most recent thing... kindof
    # if there's a transaction under this one, make these changes part of that transaction

    return unless $self -> {_transaction};

    if($self -> {_transaction} -> {transaction}) {
        my $t = $self -> {_transaction};
        $self -> {_transaction} = $self -> {_transaction} -> {transaction};
        unshift @{$self -> {_transaction} -> {rollback}}, @{$t -> {rollback}};
    }
    else {
        delete $self -> {_transaction};
    }
}
   
sub discard_transaction {  
    my $self = shift;

    return unless $self -> {_transaction};
    # we need to roll back
    my $code;

    $_->() foreach @{$self -> {_transaction}->{rollback}};

    if($self -> {_transaction} -> {transaction}) {
        $self -> {_transaction} = $self -> {_transaction} -> {transaction};
    }
    else {
        delete $self -> {_transaction};
    }
}

sub resource_requirements {
    my $class = shift;

    $class = ref $class || $class;
    my %params = @_;

    my $resource_attr;
    no strict 'refs';
    foreach my $c ($class, Class::ISA::super_path($class)) {
        $resource_attr = ${"${c}::RESOURCE"};
        last if defined $resource_attr;
    }

    warn "resource attribute: $resource_attr\n";
    return { } unless defined $resource_attr;

    warn "resource: ", $params{params} -> {resource}, "\n";
    return { $resource_attr => $params{params} -> {resource} };
}

sub DESTROY {
    my $self = shift;

    if($self -> Commit) {
        $self -> start_transaction;
        eval {
            $self -> save;
            $self -> commit_transaction;
        };
        $self -> discard_transaction if $@;
    }
    else {
        $self -> discard_transaction while exists $self -> {_transaction};
    }
}

1;

__END__

=head1 NAME

Gestinanna::POF::Base - Base framework object

=head1 SYNOPSIS

 package My::DataStore;

 use base qw(Gestinanna::POF::Base);

 use fields qw(attribute list);

 __PACKAGE__->valid_params (
    parameter list
 );

 sub load { }
 
 sub save { }

 sub delete { }

 sub find { }



 package My::DataObject::Base;

 use base qw(My::DataStore);



 package My::DataObject;

 use base qw(My::DataObject::Base);

 # any attribute access method overrides here
 sub attribute {
     my $self = shift;

     if( @_ ) { # setting
         # do checks here, returning or throwing an exception if 
         # there is a problem
     }

     $self -> SUPER::attribute(@_);
 }

=head1 DESCRIPTION

This module provides the base for the data store classes.   Data store 
classes should never be used directly to create objects or access 
data.  Instead, object classes should be derived from the data store classes.

=head1 CREATING/LOADING OBJECTS

Objects should be created or loaded through the factory object.

 $object = $factory -> new(object_type => object_id => $id);

This is the minimum that should be used.  The first parameter is the 
object type that is registered with the factory.  The remaining 
parameters are used to find the object in the data store or to create 
the object.

The object id (C<$id> in the above example) may be either a single string or an LDAP-like rdn.


=head1 METHODS

The following methods need to be implemented in any data store class.

=head2 load

This method is used by the factory to load data when creating a new object.

=head2 save

This method is called when the object needs to save its data to the 
data store.  This method may assume that any required locking has 
taken place if locking is being used.

=head2 delete

This method is called when the object's data is to be deleted from the 
data store.

=head2 find

 $factory -> find($type => ( 
     where => [ ... ],
     limit => [ ... ],
 ));

=over 4

=item limit

The limit may be either a scalar value, in which case no more than 
that number of objects or object identifiers will be returned, or an 
array reference.  The array reference should point to an array with 
two elements.  The first element indicates the maximum number of 
objects or object identifiers to return.  The second element indicates 
at which position to begin.

=item where

An example may be the quickest way to illustrate how the search 
criteria work:

 [ AND => (
     [ 'name', '=', 'some name' ],
     [ OR => (
          [ 'age',  '<', '40' ],
          [ 'postalcode', '=', '12345' ]
       )
     ]
   )
 ]

Three words are reserved in the initial position of an array reference: 
C<AND>, C<OR>, and C<NOT>.

This would be comparable to the following SQL SELECT statement:

 select * from Table 
     where name = 'some name' 
       AND ( age < 40 
          OR postalcode = 12345 
       );

This would also be comparable to the following LDAP search string:

 (&(name=some name)
   (|(!(age>=40))
     (postalcode=12345)
   )
 )

=back

This method should return a list of objects which satisfy the search 
criteria.  If no objects match, an empty list should be returned.  If 
there is an error, then either an exception should be thrown or 
C<undef> returned.

See L<Gestinanna::POF::Iterator> for more information.


=head1 SEARCH OPERATIONS

Data stores are expected to support AND, OR, and negation of statements 
via NOT as well as the following operators.  More may be added later 
(such as IN or BETWEEN from SQL).

=head2 Binary Operations

=over 4

=item =

Equality.  This may be string or numeric equality.  Most databases do 
not distinguish between the two in their syntax, basing it on the data 
type of the attribute being tested.

=item !=

This should be the opposite truth of C<=>.

=item <

Preceeds.  This should be true if the left value would sort earlier than the right value in ascending order.

=item >

Succeeds.  This should be true if the left value would sort later than the right value in ascending order.

=item <=

This should be the opposite truth of C<E<gt>>.

=item >=

This should be the opposite truth of C<E<lt>>.

=back

=head2 Unary Operations

=over 4

=item EXISTS

This should be true if the attribute exists and is set to a defined value.

=back

=head1 TRANSACTIONS

The C<save> and C<delete> methods should call the C<log_transaction_rollback> 
with one or more CODE references that can be called to rollback 
the save or delete operation.

 sub save {
     my $self = shift;
     
     $self -> log_transaction_rollback( sub {
         # do something to un-save
     } );
     
     # do the save
 }

This is needed if the data store class is to support transactions 
(especially if the data store itself does not have transaction 
support).  Note that transaction support relies on the program having
full control and realizing when transactions need to be rolled back.  
It does not guard against abnormal program termination.  Support in 
the data store itself is required to protect data integrity in case 
the program does terminate abnormally.  The transaction support here 
is meant for those times when a sequence of actions must be taken 
across several different data stores and the program needs a way to
undo what it did when it detects a problem part way through the 
sequence of data changes.

Transaction support is not fully implemented yet.

=head1 SEE ALSO

L<Gestinanna::POF::Alzabo>,
L<Gestinanna::POF::Container>,
L<Gestinanna::POF::LDAP>,
L<Gestinanna::POF::MLDBM>.

=head1 AUTHOR

James Smith <jsmith@cpan.org>

=head1 COPYRIGHT

Copyright (C) 2002-2003 Texas A&M University.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
