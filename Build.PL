use Module::Build;

my $m = Module::Build -> new(
    module_name => 'Gestinanna::POF',
    module_version_from => 'lib/Gestinanna/POF.pm',
    license => 'perl',
    requires => {
        Class::Accessor => 0.17,
        Class::Container => 0.07,
        Class::Factory => 1.00,
        Class::Fields => 0.14,
        Class::Observable => 1,
        Params::Validate => 0.24,
        NEXT => 0,
    },
    recommends => {
        MLDBM => 0,
        MLDBM::Sync => 0,
        Net::LDAP => 0,
        Alzabo => 0,
        DBI => 0, # for testing
        DBD::SQLite => 0, # for testing
    },
) -> create_build_script;
