use Test::More;
use Fcntl;

require "t/api_tests";

use lib 't/lib';

my $e; # for $@;

eval {
    require MLDBM;
};

if($@) {
    plan skip_all => 'MLDBM is required to test Gestinanna::POF::Lock';
    exit 0;
}

eval {
    require NEXT;
};

if($@) {
    plan skip_all => 'NEXT is required to test Gestinanna::POF::Lock';
    exit 0;
}

eval {
    require Gestinanna::POF::Lock;
    require Gestinanna::POF::MLDBM;
    require Gestinanna::POF;
};

if($@) {
    plan skip_all => 'errors caught in t/00basic.t';
    exit 0;
}

my $dbm;
our %o;
eval {
    $dbm = tie %o, MLDBM => 'testmldbm', O_CREAT|O_RDWR, 0666 or die $!;
};

if($@) {
    plan skip_all => 'Unable to create an MLDBM database.';
    exit 0;
}




# see if we can do what we need to

plan tests => $Gestinanna::POF::NumTests::API + 2 + 9;


###
### 1
###

eval {
    Gestinanna::POF -> register_factory_type(test => My::MLDBM::Type);
};

$e = $@; diag($e) if $e;

ok(!$e, "Registering factory type");
    


###
### 2
###

my $factory;

eval {
    $factory = Gestinanna::POF -> new(_factory => ( mldbm => $dbm ) );
};

$e = $@; diag($e) if $e;

ok(!$e, "Instantiating factory");


$INC{'My/MLDBM/Type.pm'} = 1;


###
### 3-15
###

# test api with locking module in place

run_api_tests($factory, 'object_1', 'this');


# test locking

my $object;

eval {
    $object = $factory -> new(test => (object_id => 'object_1'));
};

$e = $@; diag($e) if $e;
 
ok(!$e, "Creating object");

ok(defined($object), "Object is defined");


ok($object -> is_lockable, "Locker is in \@ISA chain");

ok($object -> is_locked == 0, "Object is not locked");

ok($object -> lock, "Object is locked");

ok($object -> is_locked, "Object is locked");

eval {
    $object -> save;
};

$e = $@; diag($e) if $e;

ok(!$e, "Saving locked object");

ok($object -> unlock, "Object is unlocked");

ok($object -> is_locked == 0, "Object is not locked");

# much more sophisticated tested needed to test much more

# clean up the schema - errors here are warnings, not failed tests

eval {
    untie %o;
    undef $dbm;

    unlink 'testmldbm.dir';
    unlink 'testmldbm.pag';
};
$e = $@; diag($e) if $e;

exit 0;

package My::MLDBM::Type;

use base qw(
    My::Locker
    Gestinanna::POF::MLDBM
);

use public qw(this that foo bar);

1;
