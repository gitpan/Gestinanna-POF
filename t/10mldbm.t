use Test::More;
use Fcntl;

require "t/api_tests";

my $e; # for $@;

eval {
    require MLDBM;
};

if($@) {
    plan skip_all => 'MLDBM is required to test Gestinanna::POF::MLDBM';
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
    $dbm = tie %o, MLDBM => 'testmldbm', O_CREAT|O_RDWR, 0666 or die $!;
};

if($@) {
    plan skip_all => 'Unable to create an MLDBM database.';
    exit 0;
}

# see if we can do what we need to

plan tests => $Gestinanna::POF::NumTests::API + 3;


eval q"
    package My::MLDBM::Type;

    use base qw(Gestinanna::POF::MLDBM);

    use public qw(this that foo bar);
";

$e = $@; diag($e) if $e;

ok(!$e, "Defined test data type");

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



# clean up the schema - errors here are warnings, not failed tests

eval {
    untie %o;
    undef $dbm;

    unlink 'testmldbm.dir';
    unlink 'testmldbm.pag';
};
$e = $@; diag($e) if $e;

exit 0;



1;
