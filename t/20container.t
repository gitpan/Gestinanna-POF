use Test::More;
use Fcntl;

require "t/api_tests";

use lib 't/lib';

my $e; # $@

eval {
    require Alzabo::Create;
    require Alzabo::Runtime;
    require Alzabo::MethodMaker;
};

if($@) {
    plan skip_all => 'Alzabo is required to test Gestinanna::POF::Container';
    exit 0;
}

eval {
    require MLDBM;
};

if($@) {
    plan skip_all => 'MLDBM is required to test Gestinanna::POF::Container';
    exit 0;
}

eval {
    require Gestinanna::POF::Alzabo;
    require Gestinanna::POF;
    require Gestinanna::POF::MLDBM;
    require Gestinanna::POF::Container;
};

if($@) {
    plan skip_all => 'errors caught in t/00basic.t';
    exit 0;
}

eval {
    require DBI;
    require DBD::SQLite;
};

if($@) {
    plan skip_all => 'DBI support for SQLite (DBD::SQLite) is required to test Gestinanna::POF::Container';
    exit 0;
};

eval {
    require Alzabo::Driver::SQLite;
};

if($@) {
    plan skip_all => 'Alzabo must support SQLite in order to test Gestinanna::POF::Container';
    exit 0;
}

# create a schema - errors here make us skip the tests

my $create_schema;
my $schema;
my $schema_name = 'gst_pof_test_alzabo_schema';
eval {
    $create_schema = Alzabo::Create::Schema -> new(
        name => 'gst_pof_test_alzabo_schema',
        rdbms => 'SQLite'
    );

    my $table = $create_schema -> make_table(
        name => 'Thing'
    );

    $table -> make_column(
        name => 'id',
        type => 'int',
        primary_key => 1,
    );

    $table -> make_column(
        name => 'name',
        type => 'char',
        default => 'name',
        length => 32,
    );

    $table -> make_column(
        name => 'bar',
        type => 'char',
        default => 'baba',
        length => 32,
    );

    $create_schema -> create;
    $create_schema -> save_to_file;

    $schema = Alzabo::Runtime::Schema -> load_from_file(
        name => 'gst_pof_test_alzabo_schema',
    );

    $schema -> connect;
};

if($e = $@) {
    diag($e);
    eval { $create_schema -> drop; $create_schema -> delete; };
    plan skip_all => 'Unable to create an Alzabo schema: ' . $e;
    exit 0;
}

my $dbm;
our %o;
eval {
    $dbm = tie %o, MLDBM => 'testmldbm', O_CREAT|O_RDWR, 0666 or die $!;
};

if($@) {
    eval { $create_schema -> drop; $create_schema -> delete; };
    plan skip_all => 'Unable to create an MLDBM database.';
    exit 0;
}

# see if we can do what we need to


plan tests => 3*$Gestinanna::POF::NumTests::API + 2;


###
### 1
###

eval {
    Gestinanna::POF -> register_factory_type(test => 'My::Container::Type');
};

$e = $@; diag($e) if $e;

ok(!$e, "Registering factory type");



###
### 2
###

my $factory;

eval {
    $factory = Gestinanna::POF -> new(_factory => ( schema => $schema, mldbm => $dbm ) );
};

$e = $@; diag($e) if $e;
ok(!$e, "Instantiating factory");

$INC{'My/Container/Type.pm'} = 1;

run_api_tests($factory, 1, 'name');  # test Alzabo object

run_api_tests($factory, 1, 'this');  # test MLDBM object

run_api_tests($factory, 1, 'bar');   # test both

# clean up the schema - errors here are warnings, not failed tests


eval {
    $create_schema -> drop;
    $create_schema -> delete;
};
$e = $@; diag($e) if $e;

eval {
    untie %o;
    undef $dbm;

    unlink 'testmldbm.dir';
    unlink 'testmldbm.pag';
};
$e = $@; diag($e) if $e;


############

package My::MLDBM::Type;

use base qw(Gestinanna::POF::MLDBM);

use public qw(this that foo bar);


######

package My::Alzabo::Type;

use base qw(Gestinanna::POF::Alzabo);

use constant table => Thing;


######

package My::Container::Type;

use base qw(Gestinanna::POF::Container);

BEGIN {
    __PACKAGE__ -> contained_objects(
        dbm => 'My::MLDBM::Type',
        rdbms => 'My::Alzabo::Type',
    );  
}
 
1;
