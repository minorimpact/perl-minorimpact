package MinorImpact::Object::Field;

use Data::Dumper;

use MinorImpact;
use MinorImpact::Util;
use MinorImpact::Object::Field::boolean;
use MinorImpact::Object::Field::text;
use MinorImpact::Object::Field::url;

# TODO: This object doesn't know shit about the database, which is pretty dumb.  It should pull values automatically if
#   it's attached to a particular object, should be able to create new fields, and when values are added or changes, they
#   should be written back to the database.  It's really weak as is.

sub new {
    my $package = shift || return;
    my $data = shift || return;

    #MinorImpact::log(7, "starting");
    my $self;
    eval {
        #MinorImpact::log(7, "\$field_type=$field_type");
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
    #MinorImpact::log(7, "ending");
    return $self;
}

sub _new {
    my $package = shift || return;
    my $data = shift || return;
    #MinorImpact::log(7, "starting");

    my $self = {};

    # TODO: We're basically sending this the database row that we want to be turned into a field.  We should really just give
    #   it an object_type and an object_field_id and let it suck it in for itself.
    # We want the value to be an array, not a scalar, so duplicate
    #   it and rewrite it as an array.
    my $local_data = cloneHash($data);
    my $self->{data} = $local_data;
    if (defined($local_data->{value})) {
        my $value = $data->{value};
        undef($data->{value});
        push(@{$self->{data}{value}}, $value);
    }

    #MinorImpact::log(7, "ending");
    return $self;
}

sub validate {
    my $self = shift || return;
    my $value = shift;
    #MinorImpact::log(7, "starting");

    my $field_type = $self->type();
    if (defined($value) && !$value && $self->get('required')) {
        die $self->name() . " cannot be blank";
    }
    return $value;
}

sub addValue {
    my $self = shift || return;
    my $data = shift || return;
    #MinorImpact::log(7, "starting");
    #MinorImpact::log(8, "$data->{name}='$data->{value}'");
    
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
    $displayname =~s/_/ /g;
    $displayname = ucfirst($displayname);
    return $displayname;
}

sub value { 
    my $self = shift || return; 
    my $params = shift || {};

    my @values;
    # TODO: Rethink this.  I like the idea of returning an actual object for fields that are references to other 
    #   objects, but too many things are expecting an an actual id, and then do stuff with that.
    #if ($self->type() =~/object\[(\d+)\]$/ && !$params->{id_only}) {
    #    @values = map { new MinorImpact::Object($_); } @{$self->{data}{value}};
    #} else {
        @values = @{$self->{data}{value}};
    #}
    return wantarray?@values:$values[0]; 
}

# return a piece of metadata about this field.
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

# Returns a row in a table that contains the field name and the input field.
sub formRow {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "start");
    my $name = $self->name()|| return;
    my $local_params = cloneHash($params);

    my @values = @{$local_params->{value}};
    @values = $self->value({id_only=>1}) unless (scalar(@values));
    
    my $field_name = $self->displayName();
    my $i = 0;

    $local_params->{row_value} = $values[$i];
    my $row;
    $row .= "<tr><td class=fieldname>$field_name</td><td>\n";
    $row .= $self->_input($local_params);
    $row .= "*" if ($self->get('required'));
    $row .= "</td><td class=small><span class=small>" . $self->get('description') . "</span></td></tr>\n";

    if ($self->isArray()) {
        while (++$i <= (scalar(@values)-1)) {
            $local_params->{row_value} = $values[$i];
            $row .= "<tr><td></td><td align=left>" . $self->_input($local_params) . "</td></tr>";
        }
        $local_params->{duplicate} = 1;
        delete($local_params->{row_value});
        $row .= "<tr><td></td><td>" . $self->_input($local_params) . "</td></tr>";
    }
    #MinorImpact::log(7, "ending");
    return $row;
}

# Returns the form input control for this field.
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
    } else {
        $row .= "<input id='$name' type=text name='$name' value='$value'";
        if ($params->{duplicate}) {
            $row .= " onchange='duplicateRow(this);'";
        }
        $row .= ">\n";
    }
    return $row;
}

# Returns true if this field contains an array of values.
sub isArray {
    my $self = shift || return;

    return 1 if ($self->type() =~/^\@/);
    return 0;
}

# Add a new field to an object.
sub addField {
    my $params = shift || return;

    my $DB = MinorImpact::getDB() || die "Can't connect to database.";

    my $object_type_id = MinorImpact::Object::type_id($params->{object_type_id}) || die "No object type id";
    my $name = $params->{name} || die "Field name can't be blank.";
    my $type = $params->{type} || die "Field type can't be blank.";

    $DB->do("INSERT INTO object_field (object_type_id, name, description, type, hidden, readonly, required, sortby, create_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())", undef, ($object_type_id, $name, $params->{description}, $type, ($params->{hidden}?1:0), ($params->{"readonly"}?1:0), ($params->{"required"}?1:0), ($params->{"sortby"}?1:0))) || die $DB->errstr;
}

# Delete a field from an object.
sub delField {
    my $params = shift || return;

    my $DB = MinorImpact::getDB() || die "Can't connect to database.";

    my $object_type_id = $params->{object_type_id} || die "No object type id";
    my $name = $params->{name} || die "Field name can't be blank.";

    
    my $object_field_id = ($DB->selectrow_array("SELECT id FROM object_field WHERE object_type_id=? AND name=?", undef, ($object_type_id, $name)))[0] || die $DB->errst;
    $DB->do("DELETE FROM object_data WHERE object_field_id=?", undef, ($object_field_id)) || die $DB->errstr;
    $DB->do("DELETE FROM object_field WHERE object_type_id=? AND name=?", undef, ($object_type_id, $name)) || die $DB->errstr;
}

1;
