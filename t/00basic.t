use Test::More;

# do things load?

my @classes = qw(
    Gestinanna::POF
    Gestinanna::POF::Base
    Gestinanna::POF::Container
    Gestinanna::POF::LDAP
    Gestinanna::POF::Secure
);

eval {
    require Alzabo;
};

push @classes, 'Gestinanna::POF::Alzabo' unless $@;

eval {
    require MLDBM;
};

push @classes, 'Gestinanna::POF::MLDBM' unless $@;

eval {
    require NEXT;
};

push @classes, 'Gestinanna::POF::Lock' unless $@;

plan tests => scalar(@classes);

foreach my $class (@classes) {
    eval "require $class;";
    ok(!$@, "Requiring $class");
}
