package Gestinanna::POF::LDAP;

use base qw(Gestinanna::POF::Base);

use Carp;

use Net::LDAP::Constant qw(LDAP_CONTROL_SORTRESULT);
use Net::LDAP::Control::Sort;

our $VERSION = '0.02';

our $REVISION = (split /\s+/, q$Revision: 1.6 $, 3)[1];

#use fields qw(_entry _is_live ldap);
use public qw(ldap ldap_schema dn);

use private qw(_entry _is_live);

__PACKAGE__->valid_params (
    ldap   => { isa => q(Net::LDAP) },
    ldap_schema => { isa => q(Net::LDAP::Schema), optional => 1 },
);

# regular expressions that match a valid value for the given syntax
# the ones here are from RFC 2252
our %SYNTAX = (
    '1.3.6.1.4.1.1466.115.121.1.1' => {
        desc => 'ACI Item',
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.2' => {
        desc => 'Access Point',
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.3' => {
        desc => 'Attribute Type Description',
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.4' => {
        desc => 'Audio',
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.5' => {
        desc => 'Binary',
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.6' => {
        desc => 'Bit String',
        regex => qr{^'[01]+'B$},
    },
    '1.3.6.1.4.1.1466.115.121.1.7' => {
        desc => 'Boolean',
        regex => qw{^(TRUE|FALSE)$},
    },
    '1.3.6.1.4.1.1466.115.121.1.8' => {
        desc => 'Certificate',
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.9' => {
        desc => 'Certificate List',
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.10' => {
        desc => 'Certificate Pair'
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.11' => {
        desc => 'Country String',                
        regex => qr{^..$},  # actually, needs to be two printable characters from ISO 3166
    },
    '1.3.6.1.4.1.1466.115.121.1.12' => {
        desc => 'DN',                            
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.13' => {
        desc => 'Data Quality Syntax',           
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.14' => {
        desc => 'Delivery Method',               
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.15' => {
        desc => 'Directory String',
        #regex => qr{^.+$},
    },
    '1.3.6.1.4.1.1466.115.121.1.16' => {
        desc => 'DIT Content Rule Description',  
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.17' => {
        desc => 'DIT Structure Rule Description',
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.18' => {
        desc => 'DL Submit Permission',          
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.19' => {
        desc => 'DSA Quality Syntax',            
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.20' => {
        desc => 'DSE Type',                      
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.21' => {
        desc => 'Enhanced Guide',                
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.22' => {
        desc => 'Facsimile Telephone Number',    
        #regex => qr{^.*(\$(twoDimensional|fineResolution|unlimitedLength|b4Length|a3Width|b4Width|uncompressed))*$},
    },
    '1.3.6.1.4.1.1466.115.121.1.23' => {
        desc => 'Fax',                           
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.24' => {
        desc => 'Generalized Time',              
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.25' => {
        desc => 'Guide',                         
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.26' => {
        desc => 'IA5 String',                    
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.27' => {
        desc => 'INTEGER',                       
        regex => qr{^\d+$},
    },
    '1.3.6.1.4.1.1466.115.121.1.28' => {
        desc => 'JPEG',                          
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.54' => {
        desc => 'LDAP Syntax Description',       
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.56' => {
        desc => 'LDAP Schema Definition',        
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.57' => {
        desc => 'LDAP Schema Description',       
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.29' => {
        desc => 'Master And Shadow Access Points',
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.30' => {
        desc => 'Matching Rule Description',     
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.31' => {
        desc => 'Matching Rule Use Description', 
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.32' => {
        desc => 'Mail Preference',               
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.33' => {
        desc => 'MHS OR Address',                
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.55' => {
        desc => 'Modify Rights',                 
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.34' => {
        desc => 'Name And Optional UID',         
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.35' => {
        desc => 'Name Form Description',         
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.36' => {
        desc => 'Numeric String',                
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.37' => {
        desc => 'Object Class Description',      
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.40' => {
        desc => 'Octet String',                  
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.38' => {
        desc => 'OID',                           
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.39' => {
        desc => 'Other Mailbox',                 
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.41' => {
        desc => 'Postal Address',                
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.42' => {
        desc => 'Protocol Information',          
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.43' => {
        desc => 'Presentation Address',          
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.44' => {
        desc => 'Printable String',              
        regex => qr{^[-a-zA-Z0-9"()+,./:? ]+$},
    },
    '1.3.6.1.4.1.1466.115.121.1.58' => {
        desc => 'Substring Assertion',           
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.45' => {
        desc => 'Subtree Specification',         
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.46' => {
        desc => 'Supplier Information',          
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.47' => {
        desc => 'Supplier Or Consumer',          
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.48' => {
        desc => 'Supplier And Consumer',         
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.49' => {
        desc => 'Supported Algorithm',           
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.50' => {
        desc => 'Telephone Number',
        #regex => qr{^.+$},
    },
    '1.3.6.1.4.1.1466.115.121.1.51' => {
        desc => 'Teletex Terminal Identifier',   
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.52' => {
        desc => 'Telex Number',                  
        #regex =>
    },
    '1.3.6.1.4.1.1466.115.121.1.53' => {
        desc => 'UTC Time',    
        #regex =>
    },
);

sub id_field {
    my $class = shift;

    $class = ref $class || $class;

    carp "No id_field defined for LDAP class $class\n";
}

sub base_dn {
    my $class = shift;

    $class = ref $class || $class;

    carp "No base_dn defined for LDAP class $class\n";
}

sub new {
    my($self, %params) = @_;

    $params -> {ldap_schema} = $params -> {ldap} -> schema 
        unless defined $params -> {ldap_schema} || !defined $params -> {ldap};

    $self = $self -> SUPER::new(%params);

    return $self;
}

# 'no-user-modification' => 1,  ==> implies !write for anyone
# 'single-value' => 1  ==> implies not multi-valued
sub get {
    my($self, @attrs) = @_;
    #my @badattrs = grep { !$self -> is_public($_) } @attrs;

    #my %v = map { $_ => $self -> SUPER::get($_) } @attrs;

    #delete @v{@badattrs};

    return $self -> SUPER::get(@attrs);
    return @v{@attrs};
}

sub set {
    my($self, $attr, @v) = @_;

    croak "$attr is not a public attribute" unless defined $attr && $self -> is_public($attr);

    my $a = $self -> _get_attribute_info($attr);
    croak "The attribute $attr is not user modifiable" 
        if $a  -> {'no-user-modification'} || $attr eq $self -> id_field;
    croak "The attribute $attr is single valued" 
        if $a -> {'single-value'} && @v > 1;

    # make sure each item is unique
    if(1) { # if case is not important...
        @v = values %{ +{ map { lc $_ => $_ } @v } };
    }
    else {  # if case is important...
        @v = keys %{ +{ map { $_ => undef } @v } };
    }

    # we can do other checks here also
    # probably want to support most of the standard syntaxes
    if($a -> {max_length}) {
        my @badv = grep { length($_) > $a -> {max_length} } @v;

        croak "Attribute values for $attr are too long: ", join("; ", @badv)
            if @badv;
    }

    if(exists $SYNTAX{$a -> {syntax}} && exists $SYNTAX{$a -> {syntax}}{regex}) {
        my @badv = grep { $_ !~ $SYNTAX{$a -> {syntax}}{regex} } @v;
        croak "Attribute values for $attr do not match `$SYNTAX{$a -> {syntax}}{desc}': ", join("; ", @badv)
            if @badv;
    }

    if($attr eq 'objectclass' && $self -> {ldap_schema}) {
        # make sure all the objectclasses are valid
        my %obclasses = map { lc $_ => $_ } $self -> {ldap_schema} -> objectclasses;
        my @badocs = grep { !$obclasses{$_} } @v;
    }

    return $self -> SUPER::set($attr, @v);
}


sub _get_attribute_info {
    my($self, $attribute) = @_;

    return { } unless $self -> {ldap_schema};

    my $info = $self -> {ldap_schema} -> attribute($attribute);

    my @info = map { $self -> _get_attribute_info($_) } @{$info->{sup} || []};

    foreach my $i (@info) {
        foreach my $k (keys %$i) {
            next if exists $info->{$k};
            $info->{$k} = $i->{$k};
        }
    }

    delete $info->{sup};

    return $info;
}

sub _attribute_allowed {
    my($self, $attribute) = @_;

    my @ocs = @{$self -> {objectclass}||[]};
    my $oc;
    my %seen_ocs;
    while($oc = shift @ocs) {
        next if $seen_ocs{$oc};
        $seen_ocs{$oc}++;
        my $oci = $self -> {ldap_schema} -> objectclass($oc);
        next unless $oci;
        push @ocs, @{$oci -> {sup} || []};
        my %atts;
        @atts{map { lc $_ } (@{$oci -> {must} || []}, @{$oci -> {may} || []})} = ( );
        return 1 if exists $atts{lc $attribute};
    }
    return 0;
}
        
sub _required_attributes {
    my($self) = @_;

    my @ocs = @{$self -> {objectclass}||[]};
    my $oc;
    my %seen_ocs;
    my %attrs;
    while($oc = shift @ocs) {
        next if $seen_ocs{$oc};
        $seen_ocs{$oc}++;
        my $oci = $self -> {ldap_schema} -> objectclass($oc);
        next unless $oci;
        push @ocs, @{$oci -> {sup} || []};
        @attrs{map { lc $_ } @{$oci -> {must} || []}} = ( );
    }
    return keys %attrs;
}

sub _allowed_attributes {
        my($self) = @_;

    my @ocs = @{$self -> {objectclass}||[]};
    my $oc;
    my %seen_ocs;
    my %attrs;
    while($oc = shift @ocs) {
        next if $seen_ocs{$oc};
        $seen_ocs{$oc}++;
        my $oci = $self -> {ldap_schema} -> objectclass($oc);
        next unless $oci;
        push @ocs, @{$oci -> {sup} || []};
        @attrs{map { lc $_ } (@{$oci -> {must} || []}, @{$oci -> {may} || []})} = ( );
    }
    return keys %attrs;
}

sub attributes {
    my $self = shift;

    return keys %{ 
                   +{ 
                      map { $_ => undef } 
                          (
                              $self -> SUPER::attributes, 
                              $self -> _allowed_attributes
                          ) 
                    } 
                 };
}

sub generate_ldif {
    my $self = shift;

    my @required = $self -> _required_attributes;

    my @missing = grep { !defined($self -> {$_}) } @required;
    carp "Required attribute", (@missing > 1 ? "s " : " "), join(", ", @missing), " not defined"
        if @missing;

    # original is in $self -> {_entry}

}

sub generate_reverse_ldif {
    my $self = shift;

    my @required = $self -> _required_attributes;

    my @missing = grep { !defined($self -> {$_}) } @required;
    carp "Required attribute", (@missing > 1 ? "s " : " "), join(", ", @missing), " not defined"
        if @missing;

    # original is in $self -> {_entry}
}

sub ldap_modify {
    return if $self -> {_deleted} || !defined $self -> {_entry};

    
}

sub ldap_add {
    my $self = shift;

    return unless $self -> {_deleted} || !defined $self -> {_entry};

    my $result = $self -> {ldap} -> add(
        $self -> dn,
        attrs => [
            map { $_ => $self -> {$_} } $self -> _allowed_attributes
        ],
    );

    $result->code && carp "failed to add entry: ", $result->error;
}

sub dn {
    my $self = shift;

    return $self -> id_field . "=" . $self -> object_id . ", " . $self -> base_dn;
}

sub is_live { return $_[0] -> {_is_live}; }

sub is_public {
    my($self, $attr) = @_;

    return 1 if $self -> SUPER::is_public($attr);

    return $self -> _attribute_allowed($attr);

}

sub save {
    my $self = shift;

    my $class = ref $self || $self;

    my @required = $self -> _required_attributes;

    my @missing = grep { !defined($self -> {$_}) } @required;
    carp "Required attribute", (@missing > 1 ? "s " : " "), join(", ", @missing), " not defined"
        if @missing;

    # use ldap protocol for saves and suggest something better in 
    # the documentation
    if($self -> {_is_live} && defined $self -> {_entry}) {
        $self -> ldap_modify;
    }
    else {
        $self -> ldap_add;
        $self -> {_is_live} = 1;
    }
}

sub load {
    my $self = shift;

    # load into $self -> {_entry};
    # copy attributes into $self

    my $mesg = $self -> {ldap} -> search(
        base => $self -> base_dn,
        filter => "(" . $self -> id_field . "=" . $self -> object_id . ")",
        attrs => [ '*', '+' ],
    );

    $mesg -> code && carp $mesg -> error;

    die "Too many results -- expected 0 or 1" if $mesg->count > 1;

    return unless $mesg -> count;

    my $entry = $mesg -> entry(0);

    if(defined $entry) {
        $self -> {_entry} = $entry;

        foreach my $attr ($entry -> attributes) {
            my @v = $entry -> get_value($attr);
            $self->{lc $attr} = @v > 1 ? [ @v ] : $v[0];
        }
        $self -> {_is_live} = 1;
    }
    else {
        $self -> {$self -> id_field} = $self -> object_id;

        $self -> {_is_live} = 0;
    }
}

sub find {
    my($self, %params) = @_;
        
    my $search = delete $params{where};
    my $limit = delete $params{limit};
    return unless UNIVERSAL::isa($search, 'ARRAY');
        
    unless(ref $self) {
        $self = bless { %params } => $self;
    }

    my $type = $self -> {_factory} -> get_object_type($self);
    my $id_field = $self -> id_field;

    my $sort = Net::LDAP::Control::Sort -> new(
        order => $id_field
    );

    my $where = $self -> _find2where($search);

    croak "No search criteria are appropriate" if $where eq '';

    my $cursor = $self -> {ldap} -> search( 
        base => $self -> base_dn,
        filter => $self -> _find2where($search),
        attrs => [ $id_field ],
        control => [ $sort ] 
    );

    return Gestinanna::POF::Iterator -> new(
        factory => $self -> {_factory},
        type => $type,
        limit => $limit,
        generator => sub {
            my $entry = $cursor -> shift_entry;
            if($row) {
                return $row -> get_value($id_field);
            }
            return;
        },
        cleanup => sub {
        },
    );
}


my %ops = (
    '!=' => [qw((! = ))],
    '>'  => [qw((! <= ))],
    '<'  => [qw((! >= ))],
    '>=' => '>=',
    '<=' => '<=',
    '='  => '=',
);

sub _find2where {
    my $self = shift;
    my $search = shift;

    my $where;
    my $n = scalar(@$search) - 1;

    for($search -> [0]) {
        /^AND$/ && do {
            my @clauses = grep { @{$_} > 0 } map { $self -> _find2where($_) } @{$search}[1..$n];
            if(@clauses > 1) {
                $n = $#clauses; 
                $where = '(&' . join('', @clauses) . ')';
            }
            elsif(@clauses) {
                $where = $clauses[0];
            }
            else {
                $where = '';
            }
        } && next;

        /^OR$/ && do {
            my @clauses = map { $self -> _find2where($_) } @{$search}[1..$n];
            if(@clauses > 1) {
                $n = scalar(@clauses) - 1;
                $where = '(|' . join('', @clauses) . ')';
            }
            elsif(@clauses) {
                $where = $clauses[0];
            }
            else {
                $where = '';
            }
        } && next;

        /^NOT$/ && do {
            $where = $self -> _find2where([ @{$search}[1..$n] ]);    
            if($where ne '') {
                 $where = "(!$where)";
            }
            else {
                $where = '';
            }
        } && next;

        # plain clause
        if(@$search > 3) {
            $where = '';
        }
        else {
            my($attr, $op, $test) = @$search;
            my($pre, $post);
            if(exists $ops{$op} 
               && $self -> is_public($attr) 
               && $self -> has_access($attr, [ 'search' ])) 
            {
                if(defined $ops{$op}) {
                    if($ops{$op} -> isa('ARRAY')) {
                        ($pre, $op, $post) = @{$ops{$op}};
                    }
                    else {
                        $op = $ops{$op};
                    }
                }
                $attr =~ s{[=()]}{\\$1}g;
                $test =~ s{[=()]}{\\$1}g;
                
                $where = "$pre($attr$op$test)$post";
            }
            else {
                $where = ''; # unsupported operation, attribute, or lack of search authorization
            }
        }
    }

    return $where;
}

sub delete {
    my $self = shift;

    return unless defined $self -> {ldap};

    return unless defined $self -> {_entry};

    $self -> {ldap} -> delete($self -> {_entry});
    $self -> {_is_live} = 0;

    #delete @$self{$self->{_entry}->attributes};
}

#sub undelete {
#    my $self = shift;
#
#    return unless defined $self -> {ldap};
#
#    return unless defined $self -> {_entry};
#
#    return if $self -> {_is_live};
#
#    $self -> {ldap} -> add($self -> {_entry});
#    $self -> {_is_live} = 1;
#
#    my $entry = ($self -> {_entry});
#    #foreach my $attr ($entry -> attributes) {
#    #    my @v = $entry -> get_value($attr);
#    #    $self->{$attr} = @v > 1 ? [ @v ] : $v[0];
#    #}
#}

1;

__END__

=head1 NAME

Gestinanna::POF::LDAP - LDAP interface for persistant objects

=head1 SYNOPSIS

 package My::DataObject;

 use base qw(Gestinanna::POF::LDAP);

 use constant base_dn => 'ou=branch, dc=some, dc=com';
 use constant id_field => 'uid';

 # override set, get, save methods here

=head1 DESCRIPTION



=head1 SEE ALSO

L<Gestinanna::POF>

=head1 AUTHOR

James Smith, <jsmith@cpan.org>

=head1 COPYRIGHT

Copyright (C) 2002, 2003 Texas A&M University.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

