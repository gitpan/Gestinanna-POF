package Gestinanna::POF::LDAP;

use base qw(Gestinanna::POF::Base);

use Carp;

use strict;

use Net::LDAP::Constant qw(LDAP_CONTROL_SORTRESULT);
use Net::LDAP::Control::Sort;
use Net::LDAP::Entry;

our $VERSION = '0.04';

our $REVISION = (split /\s+/, q$Revision: 1.9 $, 3)[1];

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
        regex => qr{^(TRUE|FALSE)$},
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

sub default_objectclass {
    my $class = shift;

    $class = ref $class || $class;

    carp "No default_objectclass for LDAP class $class\n";
}

sub new {
    my($self, %params) = @_;

    $params{ldap_schema} = $params{ldap} -> schema 
        unless defined $params{ldap_schema} || !defined $params{ldap};

    $self = $self -> SUPER::new(%params);

    return $self;
}

# 'no-user-modification' => 1,  ==> implies !write for anyone
# 'single-value' => 1  ==> implies not multi-valued
#sub get {
#    my($self, @attrs) = @_;
#    #my @badattrs = grep { !$self -> is_public($_) } @attrs;
#
#    #my %v = map { $_ => $self -> SUPER::get($_) } @attrs;
#
#    #delete @v{@badattrs};
#
#    return $self -> SUPER::get(@attrs);
#    return @v{@attrs};
#}

sub get {
    my($self) = shift;

    my @attrs = map { lc $_ } @_;

    return $self -> SUPER::get(@attrs);
}

sub set {
    my($self, $attr, @v) = @_;

    $attr = lc $attr;

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

    if(exists $SYNTAX{$a -> {syntax}}) {
        my @badv;
        if(exists $SYNTAX{$a -> {syntax}}{regex}) {
            @badv = grep { $_ !~ $SYNTAX{$a -> {syntax}}{regex} } @v;
        } elsif(exists $SYNTAX{$a -> {syntax}}{code}) {
            @badv = grep { !$SYNTAX{$a -> {syntax}}{code} -> ($_) } @v;
        }

        croak "Attribute values for $attr do not match `$SYNTAX{$a -> {syntax}}{desc}': ", join("; ", @badv)
            if @badv;
    }

    if($attr eq 'objectclass' && $self -> {ldap_schema}) {
        # make sure all the objectclasses are valid
        my %obclasses = map { lc($_ -> {name}) => $_->{name} } $self -> {ldap_schema} -> all_objectclasses;
        my @badocs = grep { !exists $obclasses{lc $_} } @v;
        @v = grep { exists $obclasses{lc $_} } @v;
        return unless @v;
    }

    my $ret = $self -> SUPER::set($attr, @v);
    if($ret && $self -> {_entry}) {
        #main::diag("Setting $attr");
        if(@v) {
            if($self -> {_entry} -> exists($attr)) {
                $self -> {_entry} -> replace($attr => \@v);
            }
            else {
                $self -> {_entry} -> add($attr => \@v);
            }
        }
        elsif($self -> {_entry} -> exists($attr)) {
            $self -> {_entry} -> delete($attr => [ ]);
        }
    }
    return $ret;
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

    return 1 if lc $attribute eq 'objectclass';

    #my @ocs = @{ref $self -> {objectclass} ||[]};
    my @ocs = $self -> objectclass;
    my $oc;
    my %seen_ocs;
    while($oc = shift @ocs) {
        next if $seen_ocs{$oc};
        $seen_ocs{$oc}++;
        #main::diag("Looking at objectclass `$oc'");
        my $oci = $self -> {ldap_schema} -> objectclass($oc);
        next unless $oci;
        push @ocs, @{$oci -> {sup} || []};
        my %atts;
        @atts{map { lc $_ } (@{$oci -> {must} || []}, @{$oci -> {may} || []})} = ( );
        #main::diag("Attributes: " . join(", ", keys %atts));
        return 1 if exists $atts{lc $attribute};
    }
    return 0;
}

sub _attribute_exists {
    my($self, $attribute) = @_;

    return 1 if $self -> {ldap_schema} -> attribute($attribute);

    return 0;
}
        
sub _required_attributes {
    my($self) = @_;

    #my @ocs = @{$self -> {objectclass}||[]};
    my @ocs = $self -> objectclass;
    my $oc;
    my %seen_ocs;
    my %attrs = (objectclass => undef);
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

    #my @ocs = @{$self -> {objectclass}||[]};
    my @ocs = $self -> objectclass;
    my $oc;
    my %seen_ocs;
    my %attrs = (objectclass => undef);
    while($oc = shift @ocs) {
        next if $seen_ocs{$oc};
        #main::diag("Looking at objectclass `$oc'");
        $seen_ocs{$oc}++;
        my $oci = $self -> {ldap_schema} -> objectclass($oc);
        next unless $oci;
        push @ocs, @{$oci -> {sup} || []};
        @attrs{map { lc $_ } (@{$oci -> {must} || []}, @{$oci -> {may} || []})} = ( );
        #main::diag("Attributes: " . join(", ", keys %attrs));
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
    croak "Required attribute", (@missing > 1 ? "s " : " "), join(", ", @missing), " not defined"
        if @missing;

    # original is in $self -> {_entry}

}

sub generate_reverse_ldif {
    my $self = shift;

    my @required = $self -> _required_attributes;

    my @missing = grep { !defined($self -> {$_}) } @required;
    croak "Required attribute", (@missing > 1 ? "s " : " "), join(", ", @missing), " not defined"
        if @missing;

    # original is in $self -> {_entry}
}

sub ldap_modify {
    my $self = shift;

    return unless defined $self -> {_entry};

    #my $entry = $self -> {_entry};

    my $id_field = $self -> id_field;

    #main::diag("Updating entry");
#    $entry->replace(map { defined($self -> {$_}) ? ($_ => $self -> {$_}) : ( ) } grep { $_ ne $id_field } $self -> _allowed_attributes);
#    $entry->delete( map { (exists($self -> {$_}) && !defined($self -> {$_})) ? ( $_ => undef ) : ( ) } grep { $_ ne $id_field } $self -> _allowed_attributes);

    my $result = $self -> {_entry} -> update( $self -> {ldap} );

    $result->code && croak "failed to update entry: ", $result->error;
}

sub ldap_add {
    my $self = shift;

    return if defined $self -> {_entry};

    my $entry = Net::LDAP::Entry -> new;
    $entry -> changetype( 'add' );
    $entry -> dn($self -> dn);
    $entry->add(map { defined($self -> {$_}) ? ($_ => $self -> {$_}) : ( ) } $self -> _allowed_attributes);
    $entry -> replace( $self -> id_field => $self -> {$self -> id_field} );

    #my $result = $self -> {ldap} -> add( $entry );
    my $result = $entry -> update( $self -> {ldap} );

    $result->code && croak "failed to add entry: ", $result->error;

#    $self -> {_is_live} = 1;
#    $self -> {_entry} = $entry;
    $self -> load;
}

sub dn {
    my $self = shift;

    return $self -> id_field . "=" . $self -> object_id . ", " . $self -> base_dn;
}

#sub is_live { return !$self->{_deleted} && (defined($_[0] -> {_entry}) || 0); }
#sub is_live { return defined($_[0] -> {_entry}) || 0; }
sub is_live { return( (defined($_[0] -> {_entry}) && $_[0] -> {_entry} -> changetype eq 'modify') || 0); }

sub is_public {
    my($self, $attr) = @_;

    return 1 if $self -> SUPER::is_public($attr);

    #main::diag("$self -> is_public($attr) : " . $self -> _attribute_allowed($attr));

    return $self -> _attribute_allowed($attr);

}

sub save {
    my $self = shift;

    my $class = ref $self || $self;

    my @required = $self -> _required_attributes;

    my @missing = grep { !defined($self -> {$_}) } @required;
    croak "Required attribute", (@missing > 1 ? "s " : " "), join(", ", @missing), " not defined"
        if @missing;

    # use ldap protocol for saves and suggest something better in 
    # the documentation
    my $changetype = $self -> {_entry} -> changetype;
    my $result = $self -> {_entry} -> update( $self -> {ldap} );

    $result->code && croak "failed to $changetype entry: ", $result->error;

    #$self -> load if $changetype eq 'add';
    #if(defined $self -> {_entry}) {
    #    $self -> ldap_modify;
    #}
    #else {
    #    $self -> ldap_add;
    #    #$self -> {_is_live} = 1;
    #}
}

sub load {
    my $self = shift;

    # load into $self -> {_entry};
    # copy attributes into $self

    return unless $self -> {ldap};

    #main::diag("Searching for " . $self -> dn);

    my $mesg = $self -> {ldap} -> search(
        base => $self -> base_dn,
        filter => "(" . $self -> id_field . "=" . $self -> object_id . ")",
        attrs => [ '*', '+' ],
    );

    croak $mesg -> error if $mesg -> code && $mesg -> error !~ m{No such object};

    #main::diag($mesg -> count . " entries found");

    die "Too many results -- expected 0 or 1" if $mesg->count > 1;

    if($mesg -> count == 1) {
        my $entry = $mesg -> entry(0);

        $self -> {_entry} = $entry;
        $self -> {_entry} -> changetype( 'modify' );

        foreach my $attr ($entry -> attributes) {
            my @v = grep { defined } $entry -> get_value($attr);
            #main::diag("  fetching attribute $attr - has ". scalar(@v) . " values");
            $self->{lc $attr} = @v > 1 ? [ @v ] : $v[0];
        }
    }
    else {
        my $entry = Net::LDAP::Entry -> new;
        $entry -> changetype( 'add' );
        $entry -> dn($self -> dn);
        $entry -> add(objectclass => $self -> default_objectclass);
        $entry -> add($self -> id_field => $self -> object_id);

        $self -> {_entry} = $entry;

        $self -> {$self -> id_field} = $self -> object_id;
        $self -> {objectclass} = $self -> default_objectclass;
    }
}

sub find {
    my($self, %params) = @_;

    my $search = delete $params{where};
    my $limit = delete $params{limit};

    return unless UNIVERSAL::isa($search, 'ARRAY');
        
    unless(ref $self) {
        $self = bless { ldap => $params{_factory} -> {ldap},
                        ldap_schema => $params{_factory} -> {ldap_schema} || $params{_factory} -> {ldap} -> schema,
                        %params } => $self;
    }

    my $type = $self -> {_factory} -> get_object_type($self);
    my $id_field = $self -> id_field;

    my $sort = Net::LDAP::Control::Sort -> new(
        order => $id_field
    );

    my $where = $self -> _find2where($search);

    #main::diag("LDAP search string: $where");
    croak "No search criteria are appropriate" if $where eq '';

    my $cursor = $self -> {ldap} -> search( 
        base => $self -> base_dn,
        scope => 'one',
        filter => $where,
        attrs => [ $id_field ],
        #control => [ $sort ] 
    );

    $cursor -> code && croak "Failed search: (" . $cursor -> code . ") " . $cursor -> error;

    return Gestinanna::POF::Iterator -> new(
        factory => $self -> {_factory},
        type => $type,
        limit => $limit,
        generator => sub {
            my $entry = $cursor -> shift_entry;
            #main::diag("Entry: $entry");
            if($entry) {
                #main::diag("\$entry -> get_value($id_field): " . $entry -> get_value($id_field));
                #main::diag("entry dn: " . $entry -> dn);
                return $entry -> get_value($id_field);
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
    my $n = $#$search;

    use Data::Dumper;

    for($search -> [0]) {
        /^AND$/ && do {
            my @clauses = grep { $_ ne '' } map { $self -> _find2where($_) } @{$search}[1..$#$search];
            if(@clauses > 1) {
                return '(&' . join('', @clauses) . ')';
            }
            elsif(@clauses) {
                return $clauses[0];
            }
            else {
                return '';
            }
        };

        /^OR$/ && do {
            my @clauses = grep { $_ ne '' } map { $self -> _find2where($_) } @{$search}[1..$n];
            if(@clauses > 1) {
                return '(|' . join('', @clauses) . ')';
            }
            elsif(@clauses) {
                return $clauses[0];
            }
            else {
                return '';
            }
        };

        /^NOT$/ && do {
            $where = $self -> _find2where([ @{$search}[1..$n] ]);    
            if($where ne '') {
                return "(!$where)";
            }
            else {
                return '';
            }
        };

        # plain clause
        if(@$search > 3 || @$search < 2) {
            return '';
        }
        elsif(@$search == 2) {
            return '' unless $search->[1] eq 'EXISTS';
            my $attr = $search -> [0];
            if(($self -> _attribute_exists($attr) || $attr eq $self -> id_field)
               && $self -> has_access($attr, [ 'search' ]))
            {
                #$attr =~ s{[\\=()]}{\\$1}g;
                $attr =~ s{(\\*)([=()])}{length($1) % 2 == 0 ? print "$1\\$2" : print "$1$2"}ge;
                return "($attr=*)";
            }
            return '';
        }
        else {
            my($attr, $op, $test) = @$search;
            #main::diag("Test: $attr | $op | $test");
            my($pre, $post);
            if(exists $ops{$op} 
               && ($self -> _attribute_exists($attr)  || $attr eq $self -> id_field)
               && $self -> has_access($attr, [ 'search' ])) 
            {
                if(defined $ops{$op}) {
                    if(UNIVERSAL::isa($ops{$op}, 'ARRAY')) {
                        ($pre, $op, $post) = @{$ops{$op}};
                    }
                    else {
                        $op = $ops{$op};
                    }
                }
                #$attr =~ s{[=()]}{\\$1}g;
                $attr =~ s{(\\*)([=()])}{length($1) % 2 == 0 ? print "$1\\$2" : print "$1$2"}ge;
                $test =~ s{(\\*)([=()])}{length($1) % 2 == 0 ? print "$1\\$2" : print "$1$2"}ge;
                #$test =~ s{[=()]}{\\$1}g;
                
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

    my $mesg = $self -> {ldap} -> delete($self -> {_entry});

    $mesg -> code && croak "(" . $mesg -> code . ") " . $mesg -> error;

    delete @$self{$self->{_entry}->attributes};

    delete $self -> {_entry};
}

1;

__END__

=head1 NAME

Gestinanna::POF::LDAP - LDAP interface for persistant objects

=head1 SYNOPSIS

 package My::DataObject;

 use base qw(Gestinanna::POF::LDAP);

 use constant base_dn => 'ou=branch, dc=some, dc=tld';
 use constant id_field => 'uid';
 use constant default_objectclass => [qw(list of objectClasses)];

=head1 DESCRIPTION

Gestinanna::POF::LDAP uses L<Net::LDAP|Net::LDAP> to provide access 
via LDAP to objects stored in a directory.  This module does make 
certain assumptions about the structure of the directory.  If more 
sophisticated access is required, you may need to go directly to the 
L<Net::LDAP|Net::LDAP> module instead of using this one.

=head1 ATTRIBUTES

This module tries to use as many hints as possible from the LDAP 
schema.  Such hints override any security allowance (e.g., if security 
says an attribute is modifiable but the LDAP schema says it isn't, 
then modifications are not allowed).

The following are some notes on how attributes are handled.

=over 4

=item *
C<id_field>

The C<id_field> (see below) is considered the primary key of the LDAP 
branch.  As such, it may not be modified.

=item *
objectclass

C<ObjectClass> always is a valid attribute.

=item *
multiplicity

If an attribute is marked as single valued in the LDAP schema, then 
only one value may be set.  Otherwise, multiple values are allowed, 
though duplicate values will be ignored.

=item *
removing an attribute

To remove an attribute, assign it an C<undef> value.

=item *
available attributes

The available attributes are determined by the C<objectclass>.  Any 
attributes the are allowed for an objectclass are allowed for the 
object.  Any attributes which are required by the objectclass may not 
be deleted or assigned an C<undef> value.

=item *
case

Attribute names are case-insensitive though lower-case is preferred.

=item *
attribute syntax

The global C<%Gestinanna::POF::LDAP::SYNTAX> holds regular expressions 
or code references that may be used to check the validity of attribute 
values.  This global hash is keyed by the OID of the syntax.  For example:

    $Gestinanna::POF::LDAP::SYNTAX{'1.3.6.1.4.1.1466.115.121.1.27'} = {   
        desc => 'INTEGER',
        regex => qr{^\d+$},
    };

Use the C<code> key instead of C<regex> to apply a subroutine 
reference.  The subroutine takes one argument: the value being tested.
It should return a true value if the value is valid.  Regular 
expressions are used in favor of code references if both are present.

Only the syntaxes from RFC 2252 are currently included (though only a few
have regular expressions or code references yet).

=back

=head1 CONFIGURATION

Three class methods are required to configure a data class.

=head2 base_dn

The C<base_dn> is both the search base for finding objects and the 
common portion of the C<dn> across all objects represented by the 
the search base and the class (also called a `branch' in the rest of this document).

=head2 id_field

The C<id_field> is the attribute containing the unique identifier for 
an object within a branch.  The value of the C<id_field> and the 
C<base_dn> together are used to create the C<dn> of an object.
This is the attribute C<object_id> is mapped to when creating or 
loading objects using L<Gestinanna::POF|Gestinanna::POF>.

=head2 default_objectclass

The C<default_objectclass> is the initial object class (or list of 
them) that is given to any new objects that are created by 
L<Gestinanna::POF|Gestinanna::POF> and are not in the directory.
This may be a single value of an array reference containing multiple values.
All the object classes should be valid object classes in the LDAP schema.

=head1 DATA CONNECTIONS

This module expects an L<Net::LDAP|Net::LDAP> connection and an 
(optional) L<Net::LDAP::Schema|Net::LDAP::Schema> object from the 
factory.  If the schema object is not provided, it will pull a copy 
from the LDAP server.
Providing this at the time the factory is created is sufficient.
    
 $factory = Gestinanna::POF -> new(_factory => (
      ldap => $ldap_connection,
      ldap_schema => $ldap_schema,
 ) );

=head1 SEE ALSO

L<Gestinanna::POF>,
L<Net::LDAP>,
L<Net::LDAP::Schema>.

=head1 AUTHOR

James Smith, <jsmith@cpan.org>

=head1 COPYRIGHT

Copyright (C) 2002, 2003 Texas A&M University.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

