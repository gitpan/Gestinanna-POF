use Test::More;
use strict;

package main;

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
    require Gestinanna::POF::Secure;
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
};

eval {
    require Alzabo::Driver::SQLite;
};

if($@) {
    plan skip_all => 'Alzabo must support SQLite in order to test Gestinanna::POF::Alzabo';
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

plan tests => (  $Gestinanna::POF::NumTests::API 
               + $Gestinanna::POF::NumTests::SECURE_API 
               + $Gestinanna::POF::NumTests::SECURE_RO_API 
               + 8
               + 3 + 10
              );

my $object_class = 'My::Secure::Type';


eval q"
package My::Secure::Package;

use base qw(Gestinanna::POF::Secure);

our $VERSION = 1;

sub has_access {
    my($self, $attribute, $access) = @_;

    # do check - return true or false
    $main::has_actor = defined $self -> {actor};
    $main::has_access_attribute = $attribute;
    $main::has_access_access = $access;

    return 1;
}


package My::Alzabo::Type;

use base qw(Gestinanna::POF::Alzabo);

our $VERSION = 1;

use constant table => 'Thing';



use Class::ISA;


package My::Secure::Type;

use base qw(
    My::Secure::Package
    My::Locker
    My::Alzabo::Type
);

use constant table => 'Thing';

our $VERSION = 1;


package My::ReadOnly::Type;

use base qw(
    Gestinanna::POF::Secure::ReadOnly
    My::Locker
    My::Alzabo::Type
);

use constant table => 'Thing';

our $VERSION = 1;
";

$e = $@; diag($e) if $e;

ok(!$e, "Defined test data types");

###
### 1
###

eval {
    Gestinanna::POF -> register_factory_type(test => $object_class);
    Gestinanna::POF -> register_factory_type(ro_test => 'My::ReadOnly::Type');
};

$e = $@; diag($e) if $e;

ok(!$e, "Registering factory type");



###
### 2
###

my $factory;

eval {
    $factory = Gestinanna::POF -> new(_factory => ( 
        schema => $schema, 
        actor => Gestinanna::POF::Base -> new(
            _factory => 'Gestinanna::POF'
        ) 
    ) );
};

$e = $@; diag($e) if $e;
ok(!$e, "Instantiating factory");


$INC{'My/Secure/Type.pm'} = 1;
$INC{'My/ReadOnly/Type.pm'} = 1;

###
### 3-5 + 1 (lock)
###

ok($object_class -> isa('Gestinanna::POF::Secure'));
ok($object_class -> isa('Gestinanna::POF::Lock'));
ok($object_class -> isa('Gestinanna::POF::Base'));

is($factory -> get_factory_class('test'), $object_class);


run_api_tests($factory, 2, 'name');

###
### 3-5 again + 1 (lock)
###

ok($object_class -> isa('Gestinanna::POF::Secure'));
ok($object_class -> isa('Gestinanna::POF::Lock'));
ok($object_class -> isa('Gestinanna::POF::Base'));

is($factory -> get_factory_class('test'), $object_class);


run_secure_api_tests($factory, 2, 'name');

run_secure_ro_api_tests($factory, 2, 'name');

my $object;

eval {
    $object = $factory -> new(test => (object_id => '100'));
};

$e = $@; diag($e) if $e;

ok(!$e, "Creating object");
    
ok(defined($object), "Object is defined");


ok($object -> is_lockable, "Locker is in \@ISA chain");
    
ok($object -> is_locked == 0, "Object is not locked");

ok($object -> lock, "Object is locked");
    
ok($object -> is_locked, "Object is locked");

eval {
    $object -> name('foo');
};

$e = $@; diag($e) if $e;

ok(!$e, "Setting name");  

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
    $create_schema -> drop;
    $create_schema -> delete;
};

exit 0;
