use Test::More;

require "t/api_tests";

use lib 't/lib';

my $e; # $@

eval {
    require Alzabo::Create;
    require Alzabo::Runtime;
    require Alzabo::MethodMaker;
};

if($@) {
    plan skip_all => 'Alzabo is required to test Gestinanna::POF::Alzabo';
    exit 0;
}

eval {
    require Gestinanna::POF::Alzabo;
    require Gestinanna::POF;
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
    plan skip_all => 'DBI support for SQLite (DBD::SQLite) is required to test Gestinanna::POF::Alzabo';
    exit 0;
}

eval {
    require Alzabo::Driver::SQLite;
};

if($@) {
    #plan skip_all => 'Alzabo must support SQLite in order to test Gestinanna::POF::Alzabo';
    plan skip_all => 'Unable to load included Alzabo SQLite modules';
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

# see if we can do what we need to

{ no warnings;
plan tests => ($Gestinanna::POF::NumTests::API + $Gestinanna::POF::NumTests::EXT_OID_API + 3);
}

eval q"
package My::Alzabo::Type;

use base qw(Gestinanna::POF::Alzabo);

use constant table => Thing;
";

$e = $@;  diag($e) if $e;

ok(!$e, "Define test data type");


###
### 1
###

eval {
    Gestinanna::POF -> register_factory_type(test => 'My::Alzabo::Type');
};

$e = $@; diag($e) if $e;

ok(!$e, "Registering factory type");

###
### 2
###

my $factory;

eval {
    $factory = Gestinanna::POF -> new(_factory => ( alzabo_schema => $schema ) );
};

$e = $@; diag($e) if $e;
ok(!$e, "Instantiating factory");


$INC{'My/Alzabo/Type.pm'} = 1;

run_api_tests($factory, 1, 'name');

run_ext_object_id_tests($factory, id => 1, 'name');

# clean up the schema - errors here are warnings, not failed tests


eval {
    $create_schema -> drop;
    $create_schema -> delete;
};

exit 0;

1;
