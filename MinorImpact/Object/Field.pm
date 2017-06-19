package MinorImpact::Object::Field;

use Data::Dumper;

use MinorImpact;
use MinorImpact::Util;
use MinorImpact::Object::Field::url;
use MinorImpact::Object::Field::boolean;

sub new {
    my $package = shift || return;
    my $field_type = shift || return;
    my $data = shift || return;

    MinorImpact::log(7, "starting");
    my $self;
    eval {
        MinorImpact::log(7, "\$field_type=$field_type");
        $self = "MinorImpact::Object::Field::$field_type"->new($data) if ($field_type);
    };
    if ($@ =~/^error:/) {
        my $error = $@;
        $error =~s/ at \/.*$//;
        $error =~s/^error://;
        die $error;
    }

    unless ($self) {
        $self = MinorImpact::Object::Field::_new($package, $data);
        bless($self, $package);
    }
    MinorImpact::log(7, "ending");
    return $self;
}

sub _new {
    my $package = shift || return;
    my $data = shift || return;
    MinorImpact::log(7, "starting");

    my $self = {};

    # We want the value to be an array, not a scalar, so duplicate
    # it and rewrite it as an array.
    my $local_data = cloneHash($data);
    my $self->{data} = $local_data;
    if (defined($local_data->{value})) {
        my $value = $data->{value};
        undef($data->{value});
        push(@{$self->{data}{value}}, $value);
    }

    MinorImpact::log(7, "ending");
    return $self;
}

sub validate {
    my $self = shift || return;
    my $value = shift;

    my $field_type = $self->type();
    if (defined($value) && !$value && $self->get('required')) {
        die $self->name() . " cannot be blank";
    }
    return $value;
}

sub addValue {
    my $self = shift || return;
    my $data = shift || return;
    
    $self->{data}{data_id} = $data->{id};
    $self->{data}{name} = $data->{name};
    push(@{$self->{data}{value}}, $data->{value});
}

sub fieldname {
    my $self = shift || return;

    return $self->name();
}

sub displayname {
    my $self = shift || return;

    my $displayname = $self->name();
    $displayname =~s/_id$//;
    $displayname =~s/_date$//;
    $displayname = ucfirst($displayname) . " (f)";
    return $displayname;
}

sub value { 
    my $self = shift || return; 

    return wantarray?@{$self->{data}{value}}:@{$self->{data}{value}}[0]; 
}

sub get {
    my $self = shift || return;
    my $field = shift || return; 
    my $data_field = $field;
    if ($field eq 'object_field_id') {
        $data_field = 'id';
    }
    return $self->{data}{$data_field};
}
sub id { my $self = shift || return; return $self->{data}{data_id}; }
sub name { my $self = shift || return; return $self->{data}{name}; }
sub toString { 
    my $self = shift || return; 
    my $value = shift;
    
    my $string;
    if ($value) {
        $string = $value;
    } else {
        foreach my $value (@{$self->{data}{value}}) {
            $string .= "$value,";
        }
        $string =~s/,$//;
    }
    return $string;
}

sub type {
    my $self = shift || return;

    return $self->{data}{type};
}

1;
