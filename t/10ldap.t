use Test::More;

#require "t/api_tests";

my $e; # $@

eval {
    require Net::LDAP;
};

if($@) {
    plan skip_all => 'Net::LDAP is required to test Gestinanna::POF::LDAP';
    exit 0;
}

eval {
    require Gestinanna::POF::LDAP;
    require Gestinanna::POF;
};

if($@) {
    plan skip_all => 'errors caught in t/00basic.t';
    exit 0;
}

plan skip_all => 'no significant tests yet defined for Gestinanna::POF::LDAP';

exit 0;

package My::LDAP::Type;

use base qw(Gestinanna::POF::LDAP);

use constant base_dn => 'ou=somthing, dc=other, dc=domain';
use constant id_field => 'uid';

1;
