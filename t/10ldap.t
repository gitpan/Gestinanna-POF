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

plan skip_all => 'no distributable tests yet defined for Gestinanna::POF::LDAP';

exit 0;
