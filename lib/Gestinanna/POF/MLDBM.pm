package Gestinanna::POF::MLDBM;

use base Gestinanna::POF::Base;

use MLDBM ();
use Carp;

use strict;

our $VERSION = '0.02';

our $REVISION = (qw$Revision: 1.5 $)[-1];

use protected qw(mldbm);

__PACKAGE__->valid_params (
    mldbm => { isa => 'MLDBM' },
);

sub save {
    my $self = shift;

    my @keys = grep { !$self -> is_inherited($_) } $self -> show_fields('Public');

    $self -> {mldbm} -> STORE(
        $self -> object_id,
        {
            map { $_ => $self->{$_} } @keys
        }
    );
}

sub load {
    my $self = shift;

    if($self -> {mldbm} -> EXISTS($self -> object_id)) {
        my $r = $self -> {mldbm} -> FETCH($self -> object_id);
        @{ $self }{keys %{$r || {}}} = values %{$r || {}};
    }
}

sub is_live { my $self = shift; return $self -> {mldbm} -> EXISTS($self -> object_id); }

sub delete {
    my $self = shift;

    $self -> {mldbm} -> DELETE($self -> object_id);

    $self -> object_id(undef);

    delete @{ $self }{ grep { !$self -> is_inherited($_) } $self -> show_fields('Public') };
}

sub find {
    my($self, %params) = @_;
    
    my $search = delete $params{where};
    my $limit = delete $params{limit};
    croak "No search criteria are appropriate" unless UNIVERSAL::isa($search, 'ARRAY');
    
    unless(ref $self) {
        $self = bless { %params } => $self;
    }

    my $type = $self -> {_factory} -> get_object_type($self);

    my $mldbm = $self -> {mldbm} || $self -> {_factory} -> {mldbm};

    my $where = $self -> _find2where($search);

    croak "No search criteria are appropriate" unless $where;

    my @keys;
    my $k;
    push @keys, $k = $mldbm -> FIRSTKEY;
    push @keys, $k while $k = $mldbm -> NEXTKEY($k);
    if(@keys == grep { /^\d+$/ } @keys) {
        @keys = sort { $a <=> $b } @keys;
    }
    else {
        @keys = sort @keys;
    }
 
    return Gestinanna::POF::Iterator -> new(
        factory => $self -> {_factory},
        type => $type,
        limit => $limit,
        generator => sub {
            my $k;
            while($k = shift @keys) {
                return $k if $where -> ($mldbm -> FETCH($k));
            }
            return;
        },
        cleanup => sub {
        },
    );
}

# horribly inefficient, but we're already walking the dbm file, so 
# what's a few function calls? :/
sub _find2where {
    my $self = shift;
    my $search = shift;

    my $n = scalar(@$search) - 1;
      
    for($search -> [0]) {
        /^AND$/ && do {
            my @clauses = grep { defined $_ } map { $self -> _find2where($_) } @{$search}[1..$n];
            if(@clauses > 1) {
                return sub {
                    for(my $i = 0; $i <= $#clauses; $i++) {
                        return 0 unless $clauses[$i] -> ($_[0]);
                    }
                    return 1;
                };
            }
            else {
                return $clauses[0];   
            }
        };
        
        /^OR$/ && do {
            my @clauses = grep { defined $_ } map { $self -> _find2where($_) } @{$search}[1..$n];
            if(@clauses > 1) {   
                return sub {
                    for(my $i = 0; $i <= $#clauses; $i++) {
                        return 1 if $clauses[$i] -> ($_[0]);
                    }
                    return 0;
                };
            }
            else {
                return $clauses[0];
            }
        };

        /^NOT$/ && do {
            my $where = $self -> _find2where([ @{$search}[1..$n] ]);
            if(defined $where) {
                 return sub { !$where -> ($_[0]) };
            }
            else {
                return;
            }
        };

        # plain clause
        return if @$search > 3;

        return unless $self -> is_public($search->[0]);
        return unless $self -> has_access($search->[0], [ 'search' ]);

        my($k, $v) = @{$search}[0,2];

        if(ref($v) eq 'SCALAR') {
            return '' unless $self -> is_public($v) && $self -> has_access($v, [ 'search' ]);
            return '' if $self -> has_access($v, [ 'read' ]) && !$self -> has_access($search->[0], [ 'read' ])
                         || !$self -> has_access($v, [ 'read' ]) && $self -> has_access($search->[0], [ 'read' ]);

            for($search -> [1]) { # switch on op
                /^=$/ && return sub { $_[0] -> {$k} eq $_[0] -> {$v}; };
                /^<$/ && return sub { $_[0] -> {$k} lt $_[0] -> {$v}; };
                /^>$/ && return sub { $_[0] -> {$k} gt $_[0] -> {$v}; };
                /^<=$/ && return sub { $_[0] -> {$k} le $_[0] -> {$v}; };
                /^>=$/ && return sub { $_[0] -> {$k} ge $_[0] -> {$v}; };
            }
        }
        else {
            for($search -> [1]) { # switch on op
                /^=$/ && return sub { $_[0] -> {$k} eq $v; };
                /^<$/ && return sub { $_[0] -> {$k} lt $v; };
                /^>$/ && return sub { $_[0] -> {$k} gt $v; };
                /^<=$/ && return sub { $_[0] -> {$k} le $v; };
                /^>=$/ && return sub { $_[0] -> {$k} ge $v; };
            }
        }
    }
    return; # unsupported operation
}
    

1;

__END__

=head1 NAME

Gestinanna::POF::MLDBM - MLDBM interface for persistant objects

=head1 SYNOPSIS

 package My::DataObject::Base;

 use base qw(Gestinanna::POF::MLDBM);

 package My::DataObject;

 @ISA = q(My::DataObject::Base);

 # any column access method overrides here
 sub key {
     my $self = shift;

     if( @_ ) { # setting
         # do checks here, returning or throwing an exception if 
         # there is a problem
     }

     $self -> SUPER::key(@_);
 }

=head1 DESCRIPTION

=head1 AUTHOR

James Smith, <jsmith@cpan.org>

=head1 COPYRIGHT

Copyright (C) 2002, 2003 Texas A&M University.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
