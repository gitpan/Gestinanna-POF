package Gestinanna::POF::Secure;

use base q(Class::Container);

use vars qw($VERSION $REVISION);

$VERSION = '0.02';

$REVISION = 'something';

__PACKAGE__->valid_params (
    actor => { isa => q(Gestinanna::POF::Base), optional => 1},
);

sub has_access {
    my $self = shift;

    $self = ref $self || $self;

    warn "$self -> has_access() has not been defined.\n";
}

sub is_secured { return 1; }

sub get_auth_id {
    my $self = shift;

    return [ $self -> get_object_type, $self -> get_object_id ];
}

sub get_actor {
    my $self = shift;

    return $self -> {actor};
}

sub set_actor {
    my $self = shift;

    my $a = shift;

    return unless UNIVERSAL::isa($a, 'Gestinanna::POF::Base');

    $self -> {actor} = $a;
}

# sub find { my($self, %params) = @_;  $self -> NEXT::find(%params); }

1;

__END__

=head1 NAME

Gestinanna::POF::Secure - provides security for POF classes

=head1 SYNOPSIS

 package My::Security;

 use base qw(Gestinanna::POF::Secure);

 sub has_access {
     my($self, $attribute, $access) = @_;

     # do check - return true or false
 }

 package My::DataObject;

 use base qw(My::Security);
 use base qw(Gestinanna::POF::Container);

 __PACKAGE__ -> contained_objects(
 );

=head1 DESCRIPTION

The following parameters are required for the security code.

=over 4

=item actor

This is the object acting on this object.  Permissions may be based 
on both the actor and the object being acted upon.

=back

=head1 METHODS

=head2 ACCESS METHODS

By default, access methods are created as needed for attributes.  
The following are part of the base POF security object class and should 
not be used for anything else.

=over 4

=item actor

=item auth_id

This returns the identifier for the object in the form C<[ object_type, object_id ]>.

=back

=head2 SECURITY (has_access)

Secured objects will call the C<has_access> method to check whether or 
not a particular actor has a particular access to a particular attribute.
This method should return a true value if the actor has the access and 
should return a false value if it does not.

The L<Gestinanna::POF::Base|Gestinanna::POF::Base> class (from which 
the other data store classes in the L<Gestinanna::POF|Gestinanna::POF> 
distribution are based) uses the following values for the access:

=over 4

=item read

This is used to indicate read access to an attribute.

=item write

This is used to indicate write access to an attribute.

=item search

This is used to indicate the searchability of an attribute.

=back

The C<has_access> method should be prepared to receive an array 
reference containing one or more attributes or array references.  
Nested array references are allowed.  Elements within an array 
reference either must all be satisfied, or any of them be satisfied, 
alternately.

For example, given C<[ qw(read write) ]>, the actor must have both read 
and write access.  But given C<[ 'exec', [ qw(read write) ] ]>, the 
actor must have exec access and at least one of read or write access.  
Given C<[ [ qw(read write) ] ]>, the actor must have at least one of 
read or write access.

Some security systems may allow for arbitrary attributes (such as C<exec> 
in the example above).  For example, the Gestinanan application framework 
makes use of such attributes as C<admin> to indicate an administrative 
role, C<exec> to indicate execute permission for a state machine, 
and C<create> for the ability to create a new folder or file in a repository.

=head1 TODO

Need to be able to query available attributes considering security and not considering security.

=head1 AUTHOR

James Smith, <jsmith@cpan.org>

=head1 COPYRIGHT

Copyright (C) 2002, 2003 Texas A&M University.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

