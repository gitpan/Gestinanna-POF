package Gestinanna::POF::Alzabo;

use base qw(Gestinanna::POF::Base);
use Carp;
use strict;

our $VERSION = '0.04';

our $REVISION = substr q$Revision: 1.14 $, 10;

use private qw(_row _columns);

__PACKAGE__->valid_params (
    alzabo_schema   => { isa => q(Alzabo::Runtime::Schema) },
);

sub escape_sql_meta {
    my($self, $s) = @_;

    $s =~ s{\\}{\\\\}g;
    $s =~ s{[_*?%]}{\\$1}g;

    return $s;
}

sub import {
    my $class = shift;
    my($table) = @_;
    no strict 'refs';

    if(@_ == 1) {
        my $caller = caller;
        eval "package $caller; use base qw($class);";
        *{"${class}::table"} = sub () { $table };
    }
    else {
        $class -> SUPER::import(@_);
    }
}

sub object_ids {
    my $self = shift;

    return [ ] unless ref $self;

    return [ map { $_ -> name } $self -> {alzabo_schema} -> table($self -> table) -> primary_key ];
}

sub is_public {
    my($self, $attr) = @_;

    # check to see if $attr is in the table we represent
    return 1 if $self -> {alzabo_schema} 
             && $self -> {alzabo_schema} -> table($self -> table) 
             && $self -> {alzabo_schema} -> table($self -> table) -> has_column($attr);

    return $self -> SUPER::is_public($attr);
}

sub attributes {
    my $self = shift;

    my %attrs = map { $_ => undef } ($self -> SUPER::attributes, keys %{$self -> {_columns}||{}});

    return keys %attrs;
}

sub make_accessor {
    my($self, $field) = @_;

    my $accessor = $self -> SUPER::make_accessor($field);

    return $accessor if $self -> SUPER::is_public($field);

    return sub {
        my($self, @v) = @_;
        if(@v) {
            my $c = $self -> {alzabo_schema} -> table($self -> table) -> column($field);
            croak "Primary key " . $c->name . " in Alzabo table " . $self -> table . " is not modifiable" 
                if $c -> is_primary_key;
            croak "Column " . $c->name . " cannot be null"
                unless defined $v[0] || $c->nullable || defined $c->default;
        }
        $self -> $accessor (@v);
    };
}

sub is_live {
    my $self = shift;

    return exists $self->{_row} 
        && defined $self->{_row}
        && $self->{_row}->is_live || 0;
}

sub delete {
    my $self = shift;
    my $class = ref $self || $self;

    return unless $self -> is_live;

    my $pot_row = $self -> {_row} -> table -> potential_row(
        values => { $self -> {_row} -> select_hash },
    );

    $self -> {_row} -> delete;

    $self -> {_row} = $pot_row;

    # need to delete from database
    # and make sure we aren't live afterwards
}

sub save {
    my $self = shift;
    my $class = ref $self || $self;

    # create a row in the table if needed
    my @columns = map { $_ -> name } $self -> {alzabo_schema} -> table($self -> table) -> columns;
    unless(is_live($self)) {
        if($self -> {_row}) {
            my $values = {
                map { $_ => $self -> {$_} }
                    grep { defined $self -> {$_} }
                        @columns
            };

            $self -> {_row} -> make_live( values => $values );

            @$self{@columns} = $self -> {_row} -> select(@columns);
            return 1;
        }
        else {
            my $values = {
                map { $_ => $self -> {$_} }
                    grep { defined $self -> {$_} }
                        map { $_ -> name } $self -> {alzabo_schema} -> table($self -> table) -> columns
            };
            #use Data::Dumper;
            #main::diag(Data::Dumper -> Dump([$values]));
            eval {
                $self -> {_row} =
                    $self -> {alzabo_schema} -> table($self -> table) -> insert(
                        values => {
                            map { $_ => $self -> {$_} }
                                grep { defined $self -> {$_} }
                                     @columns
                        }
                    );
                 @$self{@columns} = $self -> {_row} -> select(@columns);
                 return 1;
            };
        };
        carp "Problems: $@\n" if $@;
    }

    # we make potential rows live first so we can have referential 
    # integrity checks

    # now update it 

    $self -> {_row} -> update(
        map { $_ => $self -> {$_} } 
            map { $_ -> name } 
                grep { !$_ -> is_primary_key } 
                     $self -> {_row} -> table -> columns
    );
    return 1;
}

sub load {
    my $self = shift;

    # load row from RDBS, based on object_id
    # if no object_id, create a new potential row, with a potential object_id :/
    # if object_id doesn't exist, load an empty potential row with that object_id

#    if(defined $self -> object_id) {
#        eval {
#            $self -> {_row} = $self -> {alzabo_schema} -> table($self -> table) -> row_by_id(row_id => $self -> object_id);
#        };
#    }

    unless($self -> {_row} && $self -> {_row} -> is_live) {
        eval {
            if(defined $self -> object_id && $self -> {alzabo_schema} -> table($self -> table) -> primary_key_size == 1) {
                $self -> {_row} = $self -> {alzabo_schema} -> table($self -> table) -> row_by_pk(
                    pk => $self -> object_id
                );
            }
            else {
                my @where = map { [ $_, '=', $self -> {$_ -> name} ] }
                                grep { defined $self -> { $_ -> name } }
                                    ($self -> {alzabo_schema} -> table($self -> table) -> primary_key);
                $self -> {_row} = $self -> {alzabo_schema} -> table($self -> table) -> one_row(
                   where => \@where
                ) if @where;
            }
        };
    }

    unless($self -> {_row} && $self -> {_row} -> is_live) {
        if(defined $self -> object_id && $self -> {alzabo_schema} -> table($self -> table) -> primary_key_size == 1) {
            eval {
                $self -> {_row} = $self -> {alzabo_schema} -> table($self -> table) -> potential_row(
                    values => {
                        $self -> {alzabo_schema} -> table($self -> table) -> primary_key -> name => $self -> object_id
                    },
                );
            };
        }
        else {
            eval {
                $self -> {_row} = $self -> {alzabo_schema} -> table($self -> table) -> one_row(
                    where => [
                        map { [ $_, '=', $self -> {$_ -> name} ] }
                            grep { defined $self -> { $_ -> name } }
                                $self -> {alzabo_schema} -> table($self -> table) -> columns
                    ],
                );
            };
        }
    }

    unless($self -> {_row}) {
        eval {
            my $table = $self -> {alzabo_schema} -> table($self -> table);
            $self -> {_row} = $table -> potential_row(
                values => {
                    map { $_ => $self -> {$_} }
                        grep { exists $self -> {$_} }
                            map { $_ -> name }
                                $table -> columns
                },
            );
        };
    }

    # now we read data from $self->{_row} into $self

    my @columns = map { $_ -> name } $self -> {_row} -> table -> columns if $self -> {_row};
    @{$self}{@columns} = $self -> {_row} -> select(@columns) if $self -> {_row};
}


sub find {
    my($self, %params) = @_;

    my $search = delete $params{where};
    my $limit = delete $params{limit};

    use Data::Dumper;
    #warn "$self -> find(...): ", Data::Dumper -> Dump([$search]);

    croak "No search criteria are appropriate" unless UNIVERSAL::isa($search, 'ARRAY');

    unless(ref $self) {
        $self = bless { %params } => $self;
    }

    my $table = $self -> {_factory} -> {alzabo_schema} -> table($self -> table);
    my $where = $self -> _find2where($search, $table, 0);

    croak "No search criteria are appropriate" unless @{$where} > 0;

    #main::diag("Where: " . Data::Dumper -> Dump([$self -> _find2where($search, $table, 0, 1)]));

    my $cursor = $self -> {_factory} -> {alzabo_schema} -> table($self -> table) -> rows_where(
        where => $where,
        order_by => $table -> primary_key,
    );

    my $type = $self -> {_factory} -> get_object_type($self);

    my $generator;

    if(UNIVERSAL::isa($table -> primary_key, 'ARRAY')) {
        $generator = sub {
            my $row = $cursor -> next;
            if($row) {
                return $row -> id_as_string;
            }
            return;
        };
    }
    else {
        my $pk = $table -> primary_key -> name;
        $generator = sub {
            my $row = $cursor -> next;
            if($row) {
                return $row -> select($pk);
            }
            return;
        };
    }

    return Gestinanna::POF::Iterator -> new(
        factory => $self -> {_factory},
        type => $type,
        limit => $limit,
        generator => $generator,
        cleanup => sub {
        },
    );
}


sub _find2where {
    my $self = shift;
    my $search = shift;
    my $table = shift;
    my $not = shift;
    my $debug = shift;

    my $where;
    my $n = $#$search; #scalar(@$search) - 1;

    for($search -> [0]) {
        (($not && /^OR$/) || (!$not && /^AND$/)) && do { 
            my @clauses = grep { @{$_} > 0 } map { $self -> _find2where($_, $table, $not, $debug) } @{$search}[1..$n];
            if(@clauses > 1) {
                return [ $clauses[0], map +( 'and', $_ ), @clauses[1..$#clauses] ];
            }
            elsif(@clauses) {
                return $clauses[0];
            }
            else {
                return [];
            }
        } && next;

        (($not && /^AND$/) || (!$not && /^OR$/)) && do { 
            my @clauses = grep { @{$_} > 0 } map { $self -> _find2where($_, $table, $not, $debug) } @{$search}[1..$n];
            if(@clauses > 1) {
                return [ $clauses[0], map +( 'or', $_ ), @clauses[1..$#clauses] ];
            }
            elsif(@clauses) {
                return $clauses[0];
            }
            else {
                return [];
            }
        } && next;

        /^NOT$/ && do { 
            return $self -> _find2where([ @{$search}[1..$n] ], $table, !$not, $debug);
        };

        # plain clause
        if(#$self -> is_public($search->[0]) 
           $self -> has_access($search->[0], [ 'search' ]) 
           && eval { $table -> column($search->[0]) } ) 
        {
            if($debug) {
                $where = [ "column:" . $search->[0] ];
            }
            else {
                $where = [ $table -> column($search->[0]) ];
            }

            if($not) {
                for($search->[1]) {
                    /^=$/ && do { push @$where, '!=' } && next;
                    /^!=$/ && do { push @$where, '=' } && next;
                    /^<=$/ && do { push @$where, '>' } && next;
                    /^>=$/ && do { push @$where, '<' } && next;
                    /^<$/ && do { push @$where, '>=' } && next;
                    /^>$/ && do { push @$where, '<=' } && next;
                    /^EXISTS$/ && do { push @$where, '=', undef; } && next;
                    /^CONTAINS$/ && do { push @$where, 'NOT LIKE' } && next;
                    push @$where, "NOT " . $search->[1];  # default
                }
            }
            else {
                if($search->[1] eq 'EXISTS') {
                    push @$where, '!=', undef;
                }
                elsif($search -> [1] eq 'CONTAINS') {
                    push @$where, 'LIKE';
                }
                else {
                    push @$where, $search -> [1];
                }
            }

            for my $bit (@{$search}[2..$n]) {
                if(ref($bit) eq 'SCALAR') {
                    return [] unless eval { $table -> column($$bit) };
                    return [] unless $self -> has_access($$bit, [ 'search' ]);
                    return [] if $self -> has_access($$bit, [ 'read' ]) && !$self -> has_access($search->[0], [ 'read' ]) 
                                 || !$self -> has_access($$bit, [ 'read' ]) && $self -> has_access($search->[0], [ 'read' ]); 

                    if($debug) {
                        push @$where, "column:" . $$bit;
                    }
                    else {
                        #warn "pushing column $$bit\n";
                        push @$where, $table -> column($$bit);
                    }
                }
                elsif( $search -> [1] eq 'CONTAINS' ) {
                    $bit =~ s{\\}{\\\\}g;
                    $bit =~ s{%}{\\%}g;
                    push @$where, "%$bit%";
                }
                else {
                    push @$where, $bit;
                }
            }
        }
        else {
            $where = [ ];
        }
    }

    return $where;
}

1;

__END__

=head1 NAME

Gestinanna::POF::Alzabo - Support for persistant objects stored in Alzabo

=head1 SYNOPSIS

 package My::DataObject::Base;

 use base qw(Gestinanna::POF::Alzabo);

 use constant table => q(SQLTablename);


 package My::DataObject;

 use base q(My::DataObject::Base);

 # any column access method overrides here
 sub column1 {
     my $self = shift;

     if( @_ ) { # setting
         # do checks here, returning or throwing an exception if 
         # there is a problem
     }

     $self -> SUPER::column1(@_);
 }

=head1 DESCRIPTION

This provides the basis for using an RDBMS as an object store via 
L<Alzabo|Alzabo>.  Do not use this for complex objects using 
relationships and normalization (yet).  This is best used for simple types 
where each object can be a row in a table.

=head2 Object Ids

Given an object in this class, the Alzabo row object can be retrieved from the table with

  $row = $table -> row_by_id($object -> object_id);

The object id is identical to the string returned by the C<id_as_string> 
method of the L<Alzabo::Runtime::Row|Alzabo::Runtime::Row> class.
It is easiest if this corresponds to only one column in the table.

If there is only one column in the primary key, then the object_id is 
the unmodified value of that column.

=head2 Primary Keys

Primary keys are read-only.  They may be specified at object creation/loading 
time (see below for details).

=head1 ATTRIBUTES

The attributes are those columns in the table.  Primary key attributes 
are read-only.  They may be specified at object creation time in the 
factory method call.

For example,

  $object = $factory -> new( object => (
       primary_key_1 => $value1,
       primary_key_2 => $value2
  );

This will create a new object with the specified primary key values.  
The object will be stored in the RDBMS when the C<save> method is 
called (or when the object is destroyed if C<Commit> is true).

=head1 DATA CONNECTIONS

This module expects an L<Alzabo|Alzabo> schema from the factory.  
Providing this at the time the factory is created is sufficient.

 $factory = Gestinanna::POF -> new(_factory => (
      schema => $alzabo_schema
 ) );

=head1 AUTHOR

James Smith, <jsmith@cpan.org>

=head1 COPYRIGHT

Copyright (C) 2002, 2003 Texas A&M University.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

