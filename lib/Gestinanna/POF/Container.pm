package Gestinanna::POF::Container;

use base qw(Gestinanna::POF::Base);
#use Data::Dumper;

use vars qw($VERSION $REVISION @ISA $AUTOLOAD);

our $VERSION = '0.01';

our $REVISION = substr q$Revision: 1.4 $, 10;

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
        if exists $ATTRIBUTE_MAPPINGS{$class}{$contained}{$attr};

    return $attr;
}

sub get_attribute_reverse_name {
    my($self, $contained, $attr) = @_;
    
    my $class = ref $self || $self;
        
    return $ATTRIBUTE_REVERSE_MAPPINGS{$class}{$contained}{$attr}
        if exists $ATTRIBUTE_REVERSE_MAPPINGS{$class}{$contained}{$attr};
            
    return $attr;
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
        $data{$k} = [ keys %{ +{map { $_ => undef } @{$data{$k}||[]} } } ];
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

sub find {
    my($self, %params) = @_;

    return () unless $params{criteria};

    keys %{$CONTAINED_OBJECT_CLASSES{$class}||{}}; # reset counter
    my($k, $v);
    my %objects;
    while(($k, $v) = each %{$CONTAINED_OBJECT_CLASSES{$class}||{}}) {
        my @obs = $v -> do_find(%params);
        return unless @obs && defined $obs[0];
        $objects{$_ -> object_id}{$k} = $_ for @obs;
    }

    my @ret;
    my @ks = keys %{$CONTAINED_OBJECT_CLASSES{$class}||{}};

    foreach my $id ( keys %objects ) {
        next unless @ks == grep { defined } @{$objects{$id}}{@ks};
        push @ret, $self -> new(%params, %{$objects{$id}});
    }

    return @ret;
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

    return unless $self -> object_type;

    my $cos = $self -> _contained_pof_objects;

    # no transactions at this level
    $_ -> save foreach values %$cos;
}

sub load {
    my $self = shift;

    return unless $self -> object_type && $self -> object_id;

    my $cos = $self -> _contained_pof_objects;

    return unless UNIVERSAL::isa($cos, 'HASH');

    # no transactions at this level
    $_ -> load foreach values %$cos;
}

sub delete {
    my $self = shift;

    return unless $self -> object_type && $self -> object_id;
 
    my $cos = $self -> _contained_pof_objects;
    
    # no transactions at this level
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

=head1 AUTHOR

James Smith, <jsmith@cpan.org>

=head1 COPYRIGHT

Copyright (C) 2002-2003 Texas A&M University.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
