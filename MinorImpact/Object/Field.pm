package MinorImpact::Object::Field;

use Data::Dumper;

use MinorImpact;
use MinorImpact::Util;
use MinorImpact::Object::Field::boolean;
use MinorImpact::Object::Field::text;
use MinorImpact::Object::Field::url;

sub new {
    my $package = shift || return;
    my $data = shift || return;

    MinorImpact::log(7, "starting");
    my $self;
    eval {
        MinorImpact::log(7, "\$field_type=$field_type");
        my $field_type = $data->{type};
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

sub fieldName {
    my $self = shift || return;

    return $self->name();
}

sub displayName {
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

sub formRow {
    my $self = shift || return;
    my $params = shift || {};

    my $name = $self->name()|| return;
    my $local_params = cloneHash($params);

    my @values = @{$local_params->{value}};
    @values = $self->value() unless (scalar(@values));
    
    my $field_name = $self->displayName();
    my $i = 0;

    $local_params->{row_value} = $values[$i];
    my $row;
    $row .= "<tr><td class=fieldname>$field_name</td><td>\n";
    $row .= $self->_input($local_params);
    $row .= "*" if ($self->get('required'));
    $row .= "</td></tr>\n";

    if ($self->isArray()) {
        while (++$i <= (scalar(@values)-1)) {
            $local_params->{row_value} = $values[$i];
            $row .= "<tr><td></td><td>" . $self->_input($local_params) . "</td></tr>";
        }
        $local_params->{duplicate} = 1;
        delete($local_params->{row_value});
        $row .= "<tr><td></td><td>" . $self->_input($local_params) . "</td></tr>";
    }
    MinorImpact::log(7, "ending");
    return $row;
}

sub _input {
    my $self = shift || return;
    my $params = shift || {};

    my $name = $params->{name};
    my $value = $params->{row_value};
    my $row;
    if ($self->type() =~/object\[(\d+)\]$/) {
        my $object_type_id = $1;
        my $local_params = cloneHash($params);
        $local_params->{object_type_id} = $object_type_id;
        $local_params->{fieldname} = $name;
        $local_params->{selected} = $value;
        delete($local_params->{name});
        $row .= "" .  MinorImpact::Object::selectList($local_params);
        #} elsif ($field_type =~/text$/) {
        #   $row .= "<textarea name='$name'>$value</textarea>\n";
        #} elsif ($field_type =~/boolean$/) {
        #}  
    } else {
        $row .= "<input id='$name' type=text name='$name' value='$value'";
        if ($params->{duplicate}) {
            $row .= " onchange='duplicateRow(this);'";
        }
        $row .= ">\n";
    }
    return $row;
}

sub isArray {
    my $self = shift || return;

    return 1 if ($self->type() =~/^\@/);
    return 0;
}

1;
