package My::Locker;

use base qw(Gestinanna::POF::Lock);

# basically say everything is lockable

sub lock { $_[0] -> {_locked}++; return $_[0]->{_locked}; }

sub unlock { return $_[0] -> {_locked}-- if $_[0]->{_locked}; }

sub is_locked { return defined($_[0] -> {_locked}) && $_[0] -> {_locked} > 0; }

1;
