use Test::More;

require "t/api_tests";

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

eval {
    require "t/ldap";
};

if($@) {
    plan skip_all => $@;
    exit 0;
}

eval {
    start_server( );
};

if($@) {
    plan skip_all => $@;
    exit 0;
}

my $ldap;
my $mesg;
eval {
    $ldap = client();

    $mesg = $ldap->bind($MANAGERDN, password => $PASSWD);
};

if($@) {
    plan skip_all => $@;
    exit 0;
};

if(!$mesg) {
    plan skip_all => "Unable to bind to test ldap server";
    exit 0;
}

if($mesg->code) {
    plan skip_all => "Unable to bind to test ldap server: (" . $mesg->code . ") " . $mesg->error;

    exit 0;
}

my $schema;

eval {

    $schema = $ldap -> schema;
};

if($@) {
    plan skip_all => "unable to retrieve schema: $@";

    exit 0;
}

unless($schema) {
    plan skip_all => "unable to retrieve schema";

    exit 0;
}

my @parents;  # entries that need to be added to LDAP

my $dn = $BASEDN;

while($dn) {
    push @parents, $dn;

    $dn =~ s{[^=]+=[^,]+(,\s*|$)}{};
}

#main::diag("Parents: <" . join("><", @parents));

my %objectclasses = (
    o => {
        objectclass => q(organization),
    },
    c => {
        objectclass => q(country),
    },
);

foreach my $parent (sort { length($a) <=> length($b) } @parents) {
    $parent =~ m{^([^=]+)};
    my $type = $1;
    my %attrs = (map { split(/=/, $_, 2) } split(/,\s*/, $parent));
    #main::diag("$parent => type `$type'");
    my $mesg = $ldap -> add(
        dn => $parent,
        attr => [ $type => $attrs{$type},
                  objectclass => $objectclasses{$type}->{objectclass} ],
    );

    #if($mesg -> code) {
    #    main::diag("Error adding <$parent>: (" . $mesg -> code . ") " . $mesg -> error);
    #}
}

plan tests => ($Gestinanna::POF::NumTests::API + 3);

###
### 1
###   
    
eval qq"
package My::LDAP::Type;

use base qw(Gestinanna::POF::LDAP);
    
use constant base_dn => '$BASEDN';
use constant id_field => 'cn';
use constant default_objectclass => 'device';
";

$e = $@; diag($e) if $e;

ok(!$e, "Defined data type");


###
### 2
###   
    
eval {
    Gestinanna::POF -> register_factory_type(test => My::LDAP::Type);
};

$e = $@; diag($e) if $e;
    
ok(!$e, "Registering factory type");


###
### 3
###
        
my $factory;
        
eval {
    $factory = Gestinanna::POF -> new(_factory => ( ldap => $ldap, ldap_schema => $schema ) );
};

$e = $@; diag($e) if $e;
    
ok(!$e, "Instantiating factory");
    
 
$INC{'My/LDAP/Type.pm'} = 1;

run_api_tests($factory, 'test-device', 'description');


__END__
package My::LDAP::Type;

sub load {
    my $self = shift;

    $self -> SUPER::load(@_);

#    main::diag("Allowed Attributes: ". join(", ", $self -> attributes));

    unless($self -> is_live) {
#        main::diag("Setting objectclass to `device'");
        $self -> objectclass("device");
#        main::diag("Objectclass: " . $self -> objectclass);
#        main::diag("Allowed Attributes: ". join(", ", $self -> attributes));
    }
}
