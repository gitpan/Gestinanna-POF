package Gestinanna::POF::Alzabo;

use base qw(Gestinanna::POF::Base);
use Carp;
use strict;

our $VERSION = '0.01';

our $REVISION = substr q$Revision: 1.7 $, 10;

use private qw(_row _columns);

__PACKAGE__->valid_params (
    schema   => { isa => q(Alzabo::Runtime::Schema) },
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

    if(@_ == 1) {
        my $caller = caller;
        eval "package $caller; use base qw($class);";
        *{"${class}::table"} = sub () { $table };
    }
    else {
        $class -> SUPER::import(@_);
    }
}

sub is_public {
    my($self, $attr) = @_;

    # check to see if $attr is in the table we represent
    return 1 if $self -> {schema} 
             && $self -> {schema} -> table($self -> table) 
             && $self -> {schema} -> table($self -> table) -> has_column($attr);

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
            my $c = $self -> {schema} -> table($self -> table) -> column($field);
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
        && $self->{_row}->is_live;
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
    unless($self -> is_live) {
        if($self -> {_row}) {
            my $values = {
                map { $_ => $self -> {$_} }
                    grep { defined $self -> {$_} }
                        map { $_ -> name } $self -> {schema} -> table($self -> table) -> columns
            };

            $self -> {_row} -> make_live( values => $values );
            return;
        }
        else {
            eval {
                $self -> {_row} =
                    $self -> {schema} -> table($self -> table) -> insert(
                        values => {
                            map { $_ => $self -> {$_} }
                                grep { defined $self -> {$_} }
                                     map { $_ -> name } $self -> {schema} -> table($self -> table) -> columns
                        }
                    );
                 return;
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
}

sub load {
    my $self = shift;

    # load row from RDBS, based on object_id
    # if no object_id, create a new potential row, with a potential object_id :/
    # if object_id doesn't exist, load an empty potential row with that object_id

    if(defined $self -> object_id) {
        eval {
            $self -> {_row} = $self -> {schema} -> table($self -> table) -> row_by_id(row_id => $self -> object_id);
        };
    }

    unless($self -> {_row} && $self -> {_row} -> is_live) {
        eval {
            if(defined $self -> object_id && $self -> {schema} -> table($self -> table) -> primary_key_size == 1) {
                $self -> {_row} = $self -> {schema} -> table($self -> table) -> row_by_pk(
                    pk => $self -> object_id
                );
            }
            else {
                my @where = map { [ $_, '=', $self -> {$_ -> name} ] }
                                grep { defined $self -> { $_ -> name } }
                                    ($self -> {schema} -> table($self -> table) -> primary_key);
                $self -> {_row} = $self -> {schema} -> table($self -> table) -> one_row(
                   where => \@where
                ) if @where;
            }
        };
    }

    unless($self -> {_row} && $self -> {_row} -> is_live) {
        if(defined $self -> object_id && $self -> {schema} -> table($self -> table) -> primary_key_size == 1) {
            eval {
                $self -> {_row} = $self -> {schema} -> table($self -> table) -> potential_row(
                    values => {
                        $self -> {schema} -> table($self -> table) -> primary_key -> name => $self -> object_id
                    },
                );
            };
        }
        else {
            eval {
                $self -> {_row} = $self -> {schema} -> table($self -> table) -> one_row(
                    where => [
                        map { [ $_, '=', $self -> {$_ -> name} ] }
                            grep { defined $self -> { $_ -> name } }
                                $self -> {schema} -> table($self -> table) -> columns
                    ],
                );
            };
        }
    }

    unless($self -> {_row}) {
        eval {
            my $table = $self -> {schema} -> table($self -> table);
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

    my $search = delete $params{criteria};
    return unless UNIVERSAL::isa($search, 'ARRAY');

    unless(ref $self) {
        $self = bless { %params } => $self;
    }

#use Data::Dumper;
    #main::diag("Search criteria: ", Data::Dumper -> Dump([$search]));

    my $where = $self -> _find2where($search);

    #main::diag("Where: ", Data::Dumper -> Dump([$where]));
    my $cursor = $self -> {schema} -> table($self -> table) -> rows_where(
        where => $where
    );
    my $row;
    my @objects;
    my $type = $self -> {_factory} -> get_object_type($self);
}


sub _find2where {
    my $self = shift;
    my $search = shift;

    my $where;
    my $n = scalar(@$search) - 1;

    for($search -> [0]) {
        /^AND$/ && do { 
            my @clauses = grep { @{$_} > 0 } map { $self -> _find2where($_) } @{$search}[1..$n];
            if(@clauses > 1) {
                $n = scalar(@clauses) - 1;
                $where = [ map { @{$_}, 'and' } @clauses[0..$n-1] ];
                push @$where, @{$clauses[$n]};
            }
            elsif(@clauses) {
                $where = $clauses[0];
            }
            else {
                $where = [];
            }
        } && next;

        /^OR$/ && do { 
            my @clauses = map { $self -> _find2where($_) } @{$search}[1..$n];
            if(@clauses > 1) {
                $n = scalar(@clauses) - 1;
                $where = [ map { @{$_}, 'or' } @clauses[0..$n-1] ];
                push @$where, @{$clauses[$n]};
            }
            elsif(@clauses) {
                $where = $clauses[0];
            }
            else {
                $where = [];
            }
        } && next;

        /^NOT$/ && do { 
        } && next;
        # plain clause
        my $table = $self -> {schema} -> table($self -> table);
        if($table -> column($search->[0])) {
            $where = [ $table -> column($search->[0]), @{$search}[1..$n] ];
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

=head1 BUGS

Perhaps not all bugs, but things to watch out for.

=over 4

=item *
Grouping of search criteria in C<find> method

Alzabo does not provide a way to group clauses in a where statement.  
Thus, nested search criteria are effectively flattened.  You may not 
get the results you expect if you nest ANDs and ORs.

=back

=head1 AUTHOR

James Smith, <jsmith@cpan.org>

=head1 COPYRIGHT

Copyright (C) 2002, 2003 Texas A&M University.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

