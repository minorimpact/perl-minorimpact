package MinorImpact::Object::Field;

use strict;

use Data::Dumper;
use Text::Markdown 'markdown';

use MinorImpact;
use MinorImpact::Util;
use MinorImpact::Object::Field::boolean;
use MinorImpact::Object::Field::text;
use MinorImpact::Object::Field::datetime;
use MinorImpact::Object::Field::url;

=head1 NAME

MinorImpact::Object::Field - Base class for MinorImpact object fields.

=head1 METHODS

=over 4

=cut

our @valid_types = ('boolean', 'datetime', 'float', 'int', 'string', 'text', 'url');
our @reserved_names = ( 'create_date', 'description', 'id', 'mod_date', 'object_type_id', 'system', 'user_id' );

# TODO: This object doesn't know shit about the database, which is pretty dumb.  It should pull values automatically if
#   it's attached to a particular object, should be able to create new fields, and when values are added or changes, they
#   should be written back to the database.  It's really weak as is.

sub new {
    my $package = shift || return;
    my $data = shift || return;

    MinorImpact::log(7, "starting");
    my $self;
    eval {
        my $field_type = $data->{type};
        MinorImpact::log(7, "\$field_type=$field_type");
        $self = "MinorImpact::Object::Field::$field_type"->new($data) if ($field_type);
    };
    MinorImpact::log(8, "$@") if ($@);
    if ($@ && $@ !~/Can't locate object method "new" via package/) {
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

    $self->{attributes} = {};
    $self->{attributes}{isText} = 0;
    $self->{attributes}{maxlength} = 255;

    my $local_data = cloneHash($data);
    $local_data->{attributes} ||= {};

    $self->{attributes} = { %{$self->{attributes}}, %{$local_data->{attributes}} };
    $self->{attributes}{default_value} = $data->{default_value} || '';

    delete($local_data->{attributes});

    # TODO: We're basically sending this the database row that we want to be turned into a field.  We should really just give
    #   it an object_type and an object_field_id and let it suck it in for itself.
    # We want the value to be an array, not a scalar, so duplicate
    #   it and rewrite it as an array.
    $self->{data} = $local_data;
    #MinorImpact::log(8, "\$name='" . $self->{data}{name} . "'");
    if (defined($self->{data}{value}) && !ref($self->{data}{value})) {
        my $value = $self->{data}{value};
        #MinorImpact::log(8, "\$value='$value'");
        $self->{data}{value} = [];
        push(@{$self->{data}{value}}, split("\0", $value)) if ($value);
    } elsif (!defined($self->{data}{value})) {
        $self->{data}{value} = []; # $self->{attributes}{default_value} ];
    }

    MinorImpact::log(7, "ending");
    return $self;
}

sub defaultValue {
    return shift->{attribute}{default_value};
}

sub validate {
    my $self = shift || return;
    my $value = shift;
    #MinorImpact::log(7, "starting");

    my $field_type = $self->type();
    #MinorImpact::log(8, "$field_type,'$value'");
    if ((!defined($value) || (defined($value) && $value eq '')) && $self->get('required')) {
        die $self->name() . " cannot be blank";
    }
    die $self->name() . ": value is too large." if ($value && length($value) > $self->{attributes}{maxlength});

    #MinorImpact::log(8, "ending");
    return $value;
}

sub addValue {
    my $self = shift || return;
    my $data = shift || return;
    #MinorImpact::log(7, "starting(" . $self->id() . ")");
    
    $self->{data}{data_id} = $data->{id};
    $self->{data}{name} = $data->{name};
    #MinorImpact::log(8, $self->{data}{name} . "='" . $data->{value} . "'");
    $self->{data}{value} ||= [];
    push(@{$self->{data}{value}}, $data->{value});

    #MinorImpact::log(7, "ending");
}

sub fieldName {
    my $self = shift || return;

    return $self->name();
}

sub displayName {
    my $self = shift || return;

    my $display_name = $self->name();
    $display_name =~s/_id$//;
    $display_name =~s/_date$//;
    $display_name =~s/_/ /g;
    $display_name = ucfirst($display_name);
    return $display_name;
}

sub value { 
    my $self = shift || return; 
    my $params = shift || {};

    my @values = ();
    @values = @{$self->{data}{value}} if (defined($self->{data}{value}));
    return @values;
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
sub name { shift->{data}{name}; }
sub toString { 
    my $self = shift || return; 
    my $value = shift;
    
    my $string;
    if ($value) {
        # I don't understand why this exists.
        $string = $value;
    } else {
        foreach my $value (@{$self->{data}{value}}) {
            if ($self->{attributes}{markdown}) {
                $value = markdown($value);
            }
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
sub rowForm {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "start");

    my $name = $self->name()|| return;
    my $local_params = cloneHash($params);

    my @values;
    @values = @{$local_params->{value}} if (defined($local_params->{value}));
    @values = $self->value({id_only=>1}) unless (scalar(@values));
    
    my $row;
    if ($self->isArray()) {
        foreach my $value (@values) {
            my $row_form;
            $local_params->{row_value} = htmlEscape($value);
            MinorImpact::tt('row_form', { field => $self, input => $self->_input($local_params) }, \$row_form);
            $row .= $row_form;
        }
        $local_params->{duplicate} = 1;
        delete($local_params->{row_value});
        my $row_form;
        MinorImpact::tt('row_form', { field => $self, input => $self->_input($local_params) }, \$row_form);
        $row .= $row_form;
    } else {
        $local_params->{row_value} = htmlEscape($values[0]);
        MinorImpact::tt('row_form', { field => $self, input => $self->_input($local_params) }, \$row);
    }
    #MinorImpact::log(7, "ending");
    return $row;
}

# Returns the form input control for this field.
sub _input {
    my $self = shift || return;
    my $params = shift || {};

    my $name = $params->{name} || $self->name();
    my $value = $params->{row_value};
    my $row;
    if ($self->type() =~/object\[(\d+)\]$/) {
        my $object_type_id = $1;
        my $local_params = cloneHash($params);
        $local_params->{query}{debug} .= "Object::Field::_input();";
        $local_params->{query}{object_type_id} = $object_type_id;
        $local_params->{fieldname} = $name;
        $local_params->{selected} = $value;
        $local_params->{required} = $self->get('required');
        $row .= "" .  MinorImpact::Object::selectList($local_params);
    } else {
        $row .= "<input class='w3-input w3-border' id='$name' type=text name='$name' value='$value'";
        if ($name eq 'name') {
            $row .= " maxlength=50";
        } else {
            $row .= " maxlength=" . ($self->{attributes}{maxlength} ||  255);
        }
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
    add(@_);
}

sub add {
    my $params = shift || return;

    my $DB = MinorImpact::db() || die "Can't connect to database.";

    my $local_params = cloneHash($params);
    my $object_type_id = MinorImpact::Object::typeID($local_params->{object_type_id}) || die "No object type id";
    $local_params->{name} || die "Field name can't be blank.";
    $local_params->{type} || die "Field type can't be blank.";
    $local_params->{required} = $local_params->{required}?1:0;
    $local_params->{hidden} = $local_params->{hidden}?1:0;
    $local_params->{sortby} = $local_params->{sortby}?1:0;
    $local_params->{readonly} = $local_params->{readonly}?1:0;
    $local_params->{description} = $local_params->{description} || '';
    $local_params->{default_value} = $local_params->{default_value} || '';

    my $type = $local_params->{type};
    my $array = ($type =~/^@/);
    $type =~s/^@//;
    die "'" . $local_params->{name} . "' is reserved." if (defined(indexOf($local_params->{name}, @reserved_names, @valid_types)));
    if (!defined(indexOf(lc($type), @valid_types))) {
        my $object_type_id = MinorImpact::Object::typeID($type);
        if ($object_type_id) {
            $local_params->{type} = "object[$object_type_id]";
            $local_params->{type} = "@" . $type if ($array);
        } else {
            die "'$type' is not a valid object type.";
        }
    } else {
        $type = lc($type);
    }

    MinorImpact::cache("object_field_$object_type_id", {});
    MinorImpact::cache("object_type_$object_type_id", {});
    MinorImpact::log(8, "adding field '" . $object_type_id . "-" . $local_params->{name} . "'");
    my $data = $DB->selectrow_hashref("SELECT * FROM object_field WHERE object_type_id=? AND name=?", {Slice=>{}}, ($object_type_id, $local_params->{name}));
    if ($data) {
        my $object_field_id = $data->{id};
        $DB->do("UPDATE object_field SET type=? WHERE id=?", undef, ($local_params->{type}, $object_field_id)) || die $DB->errstr unless ($data->{type} eq $local_params->{type});
        $DB->do("UPDATE object_field SET required=? WHERE id=?", undef, ($local_params->{required}, $object_field_id)) || die $DB->errstr unless ($data->{required} eq $local_params->{required});
        $DB->do("UPDATE object_field SET hidden=? WHERE id=?", undef, ($local_params->{hidden}, $object_field_id)) || die $DB->errstr unless ($data->{hidden} eq $local_params->{hidden});
        $DB->do("UPDATE object_field SET sortby=? WHERE id=?", undef, ($local_params->{sortby}, $object_field_id)) || die $DB->errstr unless ($data->{sortby} eq $local_params->{sortby});
        $DB->do("UPDATE object_field SET readonly=? WHERE id=?", undef, ($local_params->{readonly}, $object_field_id)) || die $DB->errstr unless ($data->{readonly} eq $local_params->{readonly});
        $DB->do("UPDATE object_field SET description=? WHERE id=?", undef, ($local_params->{description}, $object_field_id)) || die $DB->errstr unless ($data->{description} eq $local_params->{description});
        $DB->do("UPDATE object_field SET default_value=? WHERE id=?", undef, ($local_params->{default_value}, $object_field_id)) || die $DB->errstr unless ($data->{default_value} eq $local_params->{default_value});
    } else {
        $DB->do("INSERT INTO object_field (object_type_id, name, description, default_value, type, hidden, readonly, required, sortby, create_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())", undef, ($object_type_id, $local_params->{name}, $local_params->{description}, $local_params->{default_value}, $local_params->{type}, $local_params->{hidden}, $local_params->{readonly}, $local_params->{required}, $local_params->{sortby})) || die $DB->errstr;
        my $object_field_id = $DB->{mysql_insertid};
        my $field = new MinorImpact::Object::Field($local_params);
        my $isText = $field->isText();
        my $data = $DB->selectall_arrayref("SELECT id FROM object WHERE object_type_id=?", {Slice=>{}}, ($object_type_id)) || die $DB->errstr;
        foreach my $row (@$data) {
            my $object_id = $row->{id};
            if ($isText) {
                $DB->do("INSERT INTO object_text (object_id, object_field_id, value, create_date) VALUES (?, ?, ?, NOW())", undef, ($object_id, $object_field_id, $field->defaultValue())) || die $DB->errstr;
            } else {
                $DB->do("INSERT INTO object_data (object_id, object_field_id, value, create_date) VALUES (?, ?, ?, NOW())", undef, ($object_id, $object_field_id, $field->defaultValue())) || die $DB->errstr;
            }
        }
    }
}


# Delete a field from an object.
sub del {
    my $params = shift || return;

    my $DB = MinorImpact::db() || die "Can't connect to database.";

    my $object_type_id = $params->{object_type_id} || die "No object type id";
    my $name = $params->{name} || die "Field name can't be blank.";

    my $object_field_id = ($DB->selectrow_array("SELECT id FROM object_field WHERE object_type_id=? AND name=?", undef, ($object_type_id, $name)))[0] || die $DB->errstr;
    $DB->do("DELETE FROM object_data WHERE object_field_id=?", undef, ($object_field_id)) || die $DB->errstr;
    $DB->do("DELETE FROM object_text WHERE object_field_id=?", undef, ($object_field_id)) || die $DB->errstr;
    $DB->do("DELETE FROM object_field WHERE object_type_id=? AND name=?", undef, ($object_type_id, $name)) || die $DB->errstr;
    MinorImpact::cache("object_field_$object_type_id", {});
    MinorImpact::cache("object_type_$object_type_id", {});
}
sub delField { del(@_); }

sub isText {
    return shift->{attributes}{is_text};
}

1;
