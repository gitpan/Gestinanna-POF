package Gestinanna::POF::MLDBM;

use base Gestinanna::POF::Base;
use MLDBM ();

use vars qw($VERSION $REVISION @ISA $AUTOLOAD);

$VERSION = '0.01';

#$REVISION = sprintf '%2d.%02d', q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/;
$REVISION = (qw$Revision: 1.3 $)[-1];

#@ISA = qw(Gestinanna::POF::Base);

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
