package Gestinanna::POF::Secure::ReadOnly;

use base qw(Gestinanna::POF::Secure);

sub has_access {
    my $self = shift;
    my $attribute = shift;
    my $access = shift;

    return $self -> _and_access($access);
}

sub _and_access {
    my $self = shift;
    my $access = shift;

    if(UNIVERSAL::isa($access, 'ARRAY')) {
        foreach my $a (@{$access}) {
            return 0 unless $self -> _or_access($a);
        }
        return 1;
    }

    return 'read' eq $access || 'search' eq $access;
}

sub _or_access {
    my $self = shift;
    my $access = shift;

    if(UNIVERSAL::isa($access, 'ARRAY')) {
        foreach my $a (@{$access}) {
            return 1 if $self -> _and_access($a);
        }
        return 0;
    }

    return 'read' eq $access || 'search' eq $access;
}

1;
