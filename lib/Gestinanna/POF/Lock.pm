package Gestinanna::POF::Lock;

use Carp;
use NEXT;

sub is_lockable { return 1; }

sub lock {
    my $class = ref $_[0] || $_[0];

    carp "$class -> lock is not implemented";
}

sub unlock {
    my $class = ref $_[0] || $_[0];

    carp "$class -> unlock is not implemented";
}

sub is_locked {
    my $class = ref $_[0] || $_[0];

    carp "$class -> is_locked is not implemented";
}

sub save {
    my $self = shift;

    my $ret;

    if($self -> lock) {
        $ret = $self -> NEXT::save;
        $self -> unlock;
    }
    else {
        croak "Unable to obtain lock for save operation";
    }
    return $ret;
}

1;

__END__

=head1 NAME

Gestinanna::POF::Lock - Base class for locking mechanisms

=head1 SYNOPSIS

 package My::ObjectClass;

 use base qw(
    Gestinanna::POF::Secure::Type
    Gestinanna::POF::Lock::Type
    Gestinanna::POF::Type
 );

=head1 DESCRIPTION

** The lock protocol is still in development and may change in the next 
few releases. **

Deriving a locking implementation from this base class and including 
it in the inheritance of a data object provides a generic way to add 
(advisory) locking semantics to any data object.

=head1 METHODS

The following methods are expected in any implementation.

=head2 $object -> lock

This method should try to obtain a lock on the object.  If unable to, 
it should return undef.  Otherwise, it should return a true value such 
as the number of C<unlock>s needed to completely release the object.  
An object may be locked multiple times by the same process, requiring 
the same number of C<unlock>s.  This makes some algorithms more 
efficient and allows them not to make assumptions regarding the locked 
state of any objects they may need.

=head2 $object -> unlock

This method should release the lock on the object.  Calls to C<unlock> 
and C<lock> should be balanced, though it is safer to have more C<unlock>s 
than C<lock>s.

=head2 $object is_locked

This method should return the identifier of the object that ownes the 
lock if there is a lock.  Otherwise, it should return C<undef>.

=head1 AUTHOR

James Smith, <jsmith@cpan.org>

=head1 COPYRIGHT
    
Copyright (C) 2003 Texas A&M University.  All Rights Reserved.
    
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
