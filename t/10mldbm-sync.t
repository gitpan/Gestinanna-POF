use Test::More;
use Fcntl;

require "t/api_tests";

my $e; # for $@;

eval {
    require MLDBM::Sync;
};

if($@) {
    plan skip_all => 'MLDBM::Sync is required to test Gestinanna::POF::MLDBM support for MLDBM::Sync';
    exit 0;
}

eval {
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
    $dbm = tie %o, MLDBM::Sync => 'testmldbm-sync', O_CREAT|O_RDWR, 0666 or die $!;
};

if($@) {
    plan skip_all => 'Unable to create an MLDBM::Sync database.';
    exit 0;
}




# see if we can do what we need to

{ no warnings;
plan tests => $Gestinanna::POF::NumTests::API + $Gestinanna::POF::NumTests::EXT_OID_API + 2;
}

Gestinanna::POF::MLDBM -> build_object_class (
    class => 'My::MLDBM::Type',
    config => {
        public => [qw(this that foo bar)],
        object_ids => [qw(id)],
    },
);

#eval q"
#package My::MLDBM::Type;
#
#use base qw(Gestinanna::POF::MLDBM);
#
#use public qw(this that foo bar);
#
#use constant object_ids => [qw(id)];
#";
#
#$e = $@; diag($e) if $e;
#
#ok(!$e, "Defined test data type");



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

run_api_tests($factory, 'object_1', 'this');

run_ext_object_id_tests($factory, id => 'object_1', 'this');


# clean up the schema - errors here are warnings, not failed tests

eval {
    no warnings;
    untie %o;
    undef $dbm;

    unlink 'testmldbm-sync.dir';
    unlink 'testmldbm-sync.pag';
    unlink 'testmldbm-sync.lock';
};
$e = $@; diag($e) if $e;

exit 0;


1;
