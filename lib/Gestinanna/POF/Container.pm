package Gestinanna::POF::Container;

use base qw(Gestinanna::POF::Base);
#use Data::Dumper;

use Carp;
use strict;

our $VERSION = '0.02';

our $REVISION = substr q$Revision: 1.8 $, 10;

my %ATTRIBUTE_MAPPINGS = ( );
my %ATTRIBUTE_REVERSE_MAPPINGS = ( );
my %CONTAINED_OBJECT_CLASSES = ( );

sub contained_objects {
    my $self = shift;
    my %mapping = @_;
    my $class = ref $self || $self;

    my %params;

    my($k, $v);
    while(($k, $v) = each %mapping) {
        if(UNIVERSAL::isa($v, 'HASH')) {
            $params{$k} = { isa => $v->{class} };
            $CONTAINED_OBJECT_CLASSES{$class}{$k} = $v->{class};
        }
        else {
            $params{$k} = { isa => $v };
            $CONTAINED_OBJECT_CLASSES{$class}{$k} = $v;
        }
    }

    $self -> valid_params(%params);

    $self -> SUPER::contained_objects(%mapping);
}

sub attribute_mappings {
    my $class = shift;

    $class = ref $class || $class;

    my %mappings = @_;
    $ATTRIBUTE_MAPPINGS{$class} = \%mappings;

    $ATTRIBUTE_REVERSE_MAPPINGS{$class} = { };

    foreach my $c ( keys %mappings ) {
        $ATTRIBUTE_REVERSE_MAPPINGS{$class}{$c} = { reverse %{$mappings{$c}} };
    }
}

sub _contained_pof_objects {
    my $self = shift;

    my %objects;

    while(my($k, $v) = each %$self) {
        next unless UNIVERSAL::isa($v, 'Gestinanna::POF::Base');
        $objects{$k} = $v;
    }

    return \%objects;
}

sub get_attribute_name {
    my($self, $contained, $attr) = @_;

    my $class = ref $self || $self;

    return $ATTRIBUTE_MAPPINGS{$class}{$contained}{$attr}
        if defined $ATTRIBUTE_MAPPINGS{$class}{$contained}{$attr};

    return $attr;
}

sub get_attribute_reverse_name {
    my($self, $contained, $attr) = @_;
    
    my $class = ref $self || $self;
        
    return $ATTRIBUTE_REVERSE_MAPPINGS{$class}{$contained}{$attr}
        if defined $ATTRIBUTE_REVERSE_MAPPINGS{$class}{$contained}{$attr};
            
    return $attr;
}

sub object_ids {
    my $self = shift;

    return [ ] unless ref $self;

    my $cos = $self -> _contained_pof_objects;

    my @ids;

    while(my($k, $v) = each %$cos) {
        push @ids, map { $self -> get_attribute_reverse_name($k, $_) } @{$v -> object_ids || []};
    }

    #main::diag("Object ids: " . join(", ", keys %{ +{ map { $_ => undef } @ids } }));

    return [ keys %{ +{ map { $_ => undef } @ids } } ];
}


sub get {
    my($self, @attrs) = @_;

    return if grep { !$self -> has_access($_, [ qw(read) ]) } @attrs;

    my $cos = $self -> _contained_pof_objects;
    my %data;
    my %d;

    while(my($k, $v) = each %$cos) {
        # we need to see which attributes are available in each contained object
        # store them in a hash...
        # then return them as a hash slice...
        my @at = grep { $v -> is_public($self -> get_attribute_name($k, $_)) 
                        && $_ eq $self -> get_attribute_reverse_name($k, $_) 
                      } @attrs;
        %d = ( );
        @d{@at} = map { $v -> $_ } map { $self -> get_attribute_name($k, $_) } @at;
        while(my($a, $b) = each %d) {
            push @{$data{$a}||=[]}, (UNIVERSAL::isa($b, 'ARRAY') ? @{$b} : $b);
        }
    }
    foreach my $k (@attrs) {
        $data{$k} = [ keys %{ +{ map { $_ => undef } grep { defined } @{$data{$k}||[]} } } ];
        $data{$k} = $data{$k} -> [0] if @{$data{$k}} < 2;
    }
    return @data{@attrs};
}

sub set {
    my($self, $attr, @v) = @_;

    return unless $self -> has_access($attr, [ qw(write) ]);

    my $cos = $self -> _contained_pof_objects;
    my $class = ref $self || $self;
    while(my($k, $v) = each %$cos) {
        # we need to see which contained objects have this attribute
        # and set it in those that do
        if(exists $ATTRIBUTE_MAPPINGS{$class}{$k}{$attr}) {
            next unless $v -> is_public($ATTRIBUTE_MAPPINGS{$class}{$k}{$attr});
            $v -> set($ATTRIBUTE_MAPPINGS{$class}{$k}{$attr}, @v);
        }
        else {
            next unless $v -> is_public($attr);
            $v -> set($attr, @v);
        }
    }
}

sub is_lockable {
    my($self) = shift;

    return $self -> {_is_lockable} if defined $self -> {_is_lockable};

    my $cos = $self -> _contained_pof_objects;
    my($k, $v);
    while(($k, $v) = each %$cos) {
        return $self -> {_is_lockable} = 0 unless $v -> is_lockable;
    }

    return $self -> {_is_lockable} = 1;
}

sub is_locked {
    my($self) = shift;

    my $cos = $self -> _contained_pof_objects;
    my($k, $v);
    while(($k, $v) = each %$cos) {
        return 0 unless $v -> is_locked;
    }

    return 1;
}

sub lock {
    my($self) = shift;

    return 0 unless $self -> is_lockable;

    my $cos = $self -> _contained_pof_objects;
    my($k, $v);
    my @locked;
    while(($k, $v) = each %$cos) {
        if($v -> lock(@_)) {
            push @locked, $v;
        }
        else {
            $_ -> unlock for @locked;
            return 0;
        }
    }

    return 1;
}

sub unlock {
    my($self) = shift;

    return 0 unless $self -> is_lockable;

    return 0 unless $self -> is_locked;

    my $cos = $self -> _contained_pof_objects;
    my($k, $v);
    while(($k, $v) = each %$cos) {
        $v -> unlock(@_);
    }

    return 1;
}

sub _find_and_next_id {
    my($iterators, $next_ids) = @_;

    #local($Gestinanna::POF::CAN_WEAKEN) = 0;

    # we know that we either need to prime the ids or we used the last 
    # one, so either way, get the next_id for each iterator
    for my $i (keys %$iterators) {
        $next_ids -> {$i} = $iterators->{$i} -> next_id;
    }

    my(@its) = sort { 
          $next_ids->{$a} <=> $next_ids->{$b} 
                           || 
        $next_ids -> {$a} cmp $next_ids -> {$b} 
    } grep { defined $next_ids -> {$_} } keys %$iterators;

    # if the first and last in the array agree, then all the ones in the middle must agree
    return unless @its;

    my $x = $next_ids -> {$its[$#its]};
    my $match = $next_ids -> {$its[0]} eq $x;

    while(!$match) {
        # we start the iteration from the back since that's the greatest 
        # value - nothing below it can be a valid search result

        # we fetch ids from each iterator until we match or exceed the last one
        # wash, rinse, repeat...


        for my $j ($#its-1 .. 0) {
            $next_ids -> {$its[$j]} = $iterators->{$its[$j]} -> next_id
                while defined($next_ids -> {$its[$j]}) && (
                    $x =~ m{^\d+$} ? $next_ids -> {$its[$j]} < $x 
                                   : $next_ids -> {$its[$j]} lt $x
                );
            return unless defined $next_ids -> {$its[$j]};
        }

        @its = sort { $next_ids->{$a} cmp $next_ids->{$b} } keys %$iterators;
        $x = $next_ids -> {$its[$#its]};
        $match = $next_ids -> {$its[0]} eq $x;
    }

    return $x; # if we have a match, then the last one is it, and we had 
               # it before we entered the loop($j)
}

sub _find_or_next_id {
    my($iterators, $next_ids) = @_;

    #local($Gestinanna::POF::CAN_WEAKEN) = 0;

    # we know that we either need to prime the ids or we used the last
    # one, so either way, get the next_id for each iterator
    for my $i (grep { !defined $next_ids -> {$_} } keys %$iterators) {
        $next_ids -> {$i} = $iterators->{$i} -> next_id;
    }

    my(@its) = sort {
          $next_ids->{$a} <=> $next_ids->{$b}
                           ||
        $next_ids -> {$a} cmp $next_ids -> {$b}
    } grep { defined $next_ids -> {$_} } keys %$iterators;

    return unless @its && defined $its[0];

    my $x = $next_ids -> {$its[0]};

    return unless defined $x;

    my $i = 0;

    delete $next_ids -> {$its[$i++]} 
        until $i >= @its 
              || ($x =~ /^\d+$/ ? ($next_ids -> {$its[$i]} >  $x) 
                                : ($next_ids -> {$its[$i]} gt $x)
                 )
              ;

    return $x;
}

sub find {
    my($self, %params) = @_;
        
    my $search = delete $params{where};
    my $limit = delete $params{limit};
    croak "No search criteria are appropriate" unless UNIVERSAL::isa($search, 'ARRAY');
        
    unless(ref $self) {
        $self = bless { %params } => $self;
    }

    my $class = ref $self;

    my($k, $v);
    my %iterators;
    my %next_ids;
    while(($k, $v) = each %{$CONTAINED_OBJECT_CLASSES{$class}||{}}) {
        my $i;
        eval {
            $i = $v -> find(
                where => $search,
                limit => undef,
                %params,
            );
        };
        croak $@ if $@ && $@ !~ m{No search criteria are appropriate};
        $iterators{$k} = $i if ref $i;
    }

    croak "No search criteria are appropriate" unless scalar keys %iterators;
    
    my $type = $self -> object_type;

    my $generator;
    if(scalar(keys %iterators) > 1) {
        my $i = 0;
        my $not = 0;

        while($search -> [$i] eq 'NOT' && $i < @$search) {
            $not = !$not; $i++;
        }

        if($search -> [0] eq ($not ? 'AND' : 'OR')) {
            $generator = sub {
                return _find_or_next_id(\%iterators, \%next_ids);
            };
        }
        else {
            $generator = sub {
                return _find_and_next_id(\%iterators, \%next_ids);
            };
        }
    }
    else {
        my($iterator) = values %iterators;
        $generator = sub { $iterator -> next_id };
    }

    return Gestinanna::POF::Iterator -> new(
        factory => $self -> {_factory},
        type => $type,
        limit => $limit,
        generator => $generator,
        cleanup => sub {
            %iterators = ( );  %next_ids = ( );
        },
    );
}

sub attributes {
    my $self = shift;

    # need to collect attributes from all contained objects as well as SUPER
    my @super = $self -> SUPER::attributes;

    my $cos = $self -> _contained_pof_objects;

    my %attrs;

    @attrs{@super} = ( );

    while(my($k, $v) = each %$cos) {
        my @a = $v -> attributes;
        @attrs{map { $self -> get_attribute_reverse_name($k, $_) } @a } = ( );
    }

    return keys %attrs;
}

sub is_public {
    my($self, $attr) = @_;

    my $cos = $self -> _contained_pof_objects;
    my $class = ref $self || $self;
    while(my($k, $v) = each %$cos) {
        if(exists $ATTRIBUTE_MAPPINGS{$class}{$k}{$attr}) {
            return 1 if $v -> is_public($ATTRIBUTE_MAPPINGS{$class}{$k}{$attr});
        }
        else {
            return 1 if $v -> is_public($attr);
        }
    }

    return $self -> SUPER::is_public($attr);
}

sub is_live {
    my $self = shift;

    my $cos = $self -> _contained_pof_objects;
    while(my($k, $v) = each %$cos) {
        return 1 if $v -> is_live;
    }
    return 0;
}

sub save {
    my $self = shift;

#    return unless $self -> object_type;

    my $cos = $self -> _contained_pof_objects;

    # no transactions at this level (?)
    $_ -> save foreach values %$cos;
}

sub _build_object_id {
    my($self, %fields) = @_;

    #main::diag("$self->_build_object_id called with: " . Data::Dumper->Dump([\%fields]));

    if(keys %fields == 1) {
        return( (values %fields)[0] );
    }

    foreach my $attr (keys %fields) {
        $fields{$attr} =~ s{([\\,=()])}{\\$1};
    }

    return join(",", map { "$_=$fields{$_}" } keys %fields);
}

sub init {
    my($self, %params) = @_;

    $self -> SUPER::init(%params);

    #main::diag("self: " . Data::Dumper -> Dumper([$self]));

    my $class = ref $self || $self;
    my $cos = $CONTAINED_OBJECT_CLASSES{$class};

    #main::diag("Contained objects: " . join(", ", sort keys %$cos));

    my $object_id = delete $params{object_id};

    while(my($k, $c) = each %$cos) {
        my @allowed = keys(%{ $c -> allowed_params() });
        my %p = (map { $_ => $params{$_} } grep { exists $params{$_} } @allowed);
        my $v = $c -> new(%p);
        $self -> {$k} = $v;
    }

    $self -> process_object_id($object_id, %params);

    $cos = $self -> _contained_pof_objects;

    while(my($k, $v) = each %$cos) {
        my %fields;
        my @ids = @{$v -> object_ids || []};
        @fields{@ids} = @$self{@ids};#  = map { $_ => $self->{$_} } @{$v -> object_ids || []};
        # build object_id
        my $oid = $self -> _build_object_id( %fields );
        #while(my($of, $tf) = each %fields) {
        #    $v -> $tf($self -> {$of});
        #}
        my @allowed = keys(%{ $v -> allowed_params() });
        my %p = (map { $_ => $params{$_} } grep { exists $params{$_} } @allowed);
        $self -> {$k} = $v -> init(%p, object_id => $oid);
    }

    return $self;
}
    
sub load {
    my $self = shift;

    #return unless $self -> object_type && $self -> object_id;
    return if $self -> is_live;

    my $cos = $self -> _contained_pof_objects;

    return unless UNIVERSAL::isa($cos, 'HASH');

    # no transactions at this level
    $_ -> load foreach values %$cos;
}

sub delete {
    my $self = shift;

#    return unless $self -> object_type && $self -> object_id;
    return unless $self -> is_live;
 
    my $cos = $self -> _contained_pof_objects;
    
    # no transactions at this level (?)
    $_ -> delete foreach values %$cos;
}


1;

__END__

=head1 NAME

Gestinanna::POF::Container - Aggregation of POF object classes

=head1 SYNOPSIS

 package My::DataObject;

 use base qw(Gestinanna::POF::Container);

 __PACKAGE__ -> contained_objects(
    name => class,
 );

 __PACKAGE__ -> attribute_mappings(
    name => { external => internal },
 );
    
=head1 DESCRIPTION

This is a container object.  It allows consolidation of multiple 
data sources into a single object.  Data requests are passed to 
the contained objects transparently.

Attributes that are for specific contained objects may be prefixed 
with the name of the contained object.  These will override any 
general attributes passed in to the container constructor.

Attributes names may be mapped from the container's published set 
to the contained objects set.  This allows two contained objects 
with the same attribute name to expose that attribute through the 
container as two different attributes.  N.B.: this does not affect 
attribute names during the container's creation.  This only affects 
attribute value retrieval and storage.

=head1 BUGS

These are more caveats than bugs since they reveal some of the 
limitations in aggregating data sources without being horribly 
inefficient.

=head2 find

=over 4

=item *
Combining iterators from aggregated data stores

C<Gestinanna::POF::Container> handles searches a little differently 
because it is aggregating data from multiple data sources.  It will 
try and construct an iterator for each data source.  As long as at 
least one data source successfully constructs an iterator, this module 
will return an iterator.

If the top-level grouping in the search is C<OR>, then the resulting 
iterator will return the union of the results from the other iterators 
without duplicating object identifiers.  If the top-level grouping in 
the search is C<AND>, then the resulting iterator will return the 
intersection of the results from the other iterators.

In some cases, this behavior may result in slightly different search 
results than if all the data were in one data store.

=item *
Comparing one attribute to another attribute

Two attributes can be compared to each other only if they are in the 
same data store.  This module does not support comparing across data 
stores since this would be terrible inefficient and the code 
constructing the search should not be aware of such boundaries.  Patches 
are welcome to make cross-data-store searching a selectable behavior.

=back

=head1 AUTHOR

James Smith, <jsmith@cpan.org>

=head1 COPYRIGHT

Copyright (C) 2002-2003 Texas A&M University.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
