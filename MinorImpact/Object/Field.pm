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

=cut

our @valid_types = ('boolean', 'datetime', 'float', 'int', 'string', 'text', 'url');
our @reserved_names = ( 'create_date', 'description', 'id', 'mod_date', 'name', 'object_type_id', 'public', 'user_id' );

=head2 new

=over

=item new MinorImpact::Object::Field($object_field_id)

=item new MinorImpact::Object::Field(\%data)

=back

Create a new field object.

=head3 data

=over

=item attributes => \%hash

=over

=item max_length => $int

The max length of the field.

=item is_text => yes/no

Is the field a text field (y) or a normal length data field (n)?

=back

=item db => \%hash

=over

=item id => $int

=back

=item object_id => $int

The id of the $OBJECT this field belongs to, if applicable.

=item value => \@array

A pointer to an array of values for this field.

=back

=cut

sub new {
    my $package = shift || return;
    my $id = shift || return;

    MinorImpact::log('debug', "starting");

    my $DB = MinorImpact::db();
    my $data;
    if (ref($id) eq 'HASH') {
        $data = $id;
        $id = $data->{db}{id};
    } else {
        $data->{db} = $DB->selectrow_hashref("SELECT * from object_field where id = ?", undef, ($id));
    }

    my $self;
    eval {
        my $field_type = $data->{db}{type};
        MinorImpact::log('debug', "\$field_type=$field_type");
        $self = "MinorImpact::Object::Field::$field_type"->new($data) if ($field_type);
    };
    if ($@ && $@ !~/Can't locate object method "new" via package/) {
        MinorImpact::log('debug', "$@") if ($@);
        my $error = $@;
        $error =~s/ at \/.*$//;
        $error =~s/^error://;
        die $error;
    }

    unless ($self) {
        $self = MinorImpact::Object::Field::_new($package, $data);
        bless($self, $package);
    }

    MinorImpact::log('debug', "ending");
    return $self;
}

sub _new {
    my $package = shift || return;
    my $data = shift || return;

    die "No {db} data defined\n" unless (defined($data->{db}));
    $data->{attributes} = {} unless (defined($data->{attributes}));

    MinorImpact::log('debug', "starting");

    my $self = {};

    $self->{attributes} = {};
    $self->{attributes}{isText} = 0;
    $self->{attributes}{maxlength} = 255;

    # Override the default field attributes with anything added by an
    #   inherited class.
    $self->{attributes} = { %{$self->{attributes}}, %{$data->{attributes}} };
    $self->{db} = cloneHash($data->{db});
    $self->{attributes}{default_value} = $self->{db}{default_value} if ($self->{db}{default_value});

    $self->{object_id} = $data->{object_id};
    $self->{value} = [];
    if (defined($data->{value}) && ref($data->{value}) eq 'ARRAY') {
        foreach my $value (@{$data->{value}}) {
            push(@{$self->{value}}, split(/\0/, $value));
        }
    } elsif (defined($data->{value})) {
        push(@{$self->{value}}, split(/\0/, $data->{value}));
    }

    if ($self->{db}{id} && $self->{object_id}) {
        #MinorImpact::log('debug', "\$self->{db}{id}='" . $self->{db}{id} . "'");
        #MinorImpact::log('debug', "\$self->{object_id}='" . $self->{object_id} . "'");
        my $DB = MinorImpact::db();
        if ($self->{attributes}{is_text}) {
            my $data = $DB->selectall_arrayref("select value from object_text where object_field_id=? and object_id=?", {Slice=>{}}, ($self->{db}{id}, $self->{object_id}));
            foreach my $row (@$data) {
                MinorImpact::log('debug',"\$row->{value}='" . $row->{value} . "'");
                push(@{$self->{value}}, $row->{value});
            }
        } else {
            my $data = $DB->selectall_arrayref("select value from object_data where object_field_id=? and object_id=?", {Slice=>{}}, ($self->{db}{id}, $self->{object_id}));
            foreach my $row (@$data) {
                MinorImpact::log('debug',"\$row->{value}='" . $row->{value} . "'");
                push(@{$self->{value}}, $row->{value});
            }
        }
    }
    if (scalar(@{$self->{value}}) == 0 && defined($self->{attributes}{default_value})) {
        push(@{$self->{value}}, $self->{attributes}{default_value});
    }

    MinorImpact::log('debug', "ending");
    return $self;
}

sub defaultValue {
    return shift->{db}{default_value};
}

sub update {
    my $self = shift || return;

    #MinorImpact::log("starting");
    my @values = ();
    foreach my $v (@_) {
        if (ref($v) eq 'ARRAY') {
            push(@values, @{$v});
        } else {
            push(@values, $v);
        }
    }

    if ($self->id() && $self->object_id()) {
        my $object_id = $self->object_id();
        MinorImpact::cache("object_data_$object_id", {});
        my $DB = MinorImpact::db();
        if ($self->isText()) {
            $DB->do("delete from object_text where object_id=? and object_field_id=?", undef, ($object_id, $self->id())) || die $DB->errstr;
        } else {
            $DB->do("delete from object_data where object_id=? and object_field_id=?", undef, ($object_id, $self->id())) || die $DB->errstr;
        }
        foreach my $split_value (map { split(/\0/, $_); } @values) {
            my $sql;
            if ($self->isText()) {
                $sql = "insert into object_text(object_id, object_field_id, value, create_date) values (?, ?, ?, NOW())";
            } else {
                $sql = "insert into object_data(object_id, object_field_id, value, create_date) values (?, ?, ?, NOW())";
            }
            #MinorImpact::log('debug', "$sql \@fields=" . $object_id . ", " . $self->id() . ", $split_value");
            MinorImpact::log('debug', "$sql, '$object_id','" . $self->id() . "','$split_value'");
            $DB->do($sql, undef, ($object_id, $self->id(), $split_value)) || die $DB->errstr;
        }
    }
    $self->{value} = [];
    foreach my $split_value (map { split(/\0/, $_); } @values) {
        push(@{$self->{value}}, $split_value);
    }
    #MinorImpact::log("ending");
}

sub validate {
    my $self = shift || return;
    my $value = shift;
    MinorImpact::log('debug', "starting");

    my $field_type = $self->type();
    #MinorImpact::log('debug', "$field_type,'$value'");
    if ((!defined($value) || (defined($value) && $value eq '')) && $self->get('required')) {
        die $self->name() . " cannot be blank";
    }
    die $self->name() . ": value is too large." if ($value && length($value) > $self->{attributes}{maxlength});

    MinorImpact::log('debug', "ending");
    return $value;
}

sub value { 
    my $self = shift || return; 
    my $params = shift || {};

    my @values = ();
    @values = @{$self->{value}} if (defined($self->{value}));
    return @values;
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

# return a piece of metadata about this field.
sub get {
    my $self = shift || return;
    my $field = shift || return; 
    my $data_field = $field;
    if ($field eq 'object_field_id') {
        $data_field = 'id';
    }
    return $self->{db}{$data_field};
}

sub id { 
    return shift->{db}{id}; 
}

sub name { 
    return shift->{db}{name}; 
}

sub object_id { 
    return shift->{object_id}; 
}

sub toString { 
    my $self = shift || return; 
    my $value = shift;
    
    my $string;
    if ($value) {
        # I don't understand why this exists.
        $string = $value;
    } else {
        foreach my $value (@{$self->{value}}) {
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

    return $self->{db}{type};
}

# Returns a row in a table that contains the field name and the input field.
sub rowForm {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log('info', "start");

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
    #MinorImpact::log('info', "ending");
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
    my $object_type = new MinorImpact::Object::Type($local_params->{object_type_id}) || die "No object type id";
    my $object_type_id = $object_type->id();

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
    die "'" . $local_params->{name} . "' is reserved." if (defined(indexOf($local_params->{name}, @reserved_names)));
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

    $object_type->clearCache();
    MinorImpact::log('debug', "adding field '" . $object_type_id . "-" . $local_params->{name} . "'");
    my $data = $DB->selectrow_hashref("SELECT * FROM object_field WHERE object_type_id=? AND name=?", {Slice=>{}}, ($object_type_id, $local_params->{name}));
    if ($data) {
        MinorImpact::log('debug', "This already fucking exists?!");
        my $object_field_id = $data->{id};
        $DB->do("UPDATE object_field SET type=? WHERE id=?", undef, ($local_params->{type}, $object_field_id)) || die $DB->errstr unless ($data->{type} eq $local_params->{type});
        $DB->do("UPDATE object_field SET required=? WHERE id=?", undef, ($local_params->{required}, $object_field_id)) || die $DB->errstr unless ($data->{required} eq $local_params->{required});
        $DB->do("UPDATE object_field SET hidden=? WHERE id=?", undef, ($local_params->{hidden}, $object_field_id)) || die $DB->errstr unless ($data->{hidden} eq $local_params->{hidden});
        $DB->do("UPDATE object_field SET sortby=? WHERE id=?", undef, ($local_params->{sortby}, $object_field_id)) || die $DB->errstr unless ($data->{sortby} eq $local_params->{sortby});
        $DB->do("UPDATE object_field SET readonly=? WHERE id=?", undef, ($local_params->{readonly}, $object_field_id)) || die $DB->errstr unless ($data->{readonly} eq $local_params->{readonly});
        $DB->do("UPDATE object_field SET description=? WHERE id=?", undef, ($local_params->{description}, $object_field_id)) || die $DB->errstr unless ($data->{description} eq $local_params->{description});
        MinorImpact::log('debug', "UPDATE object_field SET default_value=? WHERE id=?,'" . $local_params->{default_value} . "', '$object_field_id', \$data->{default_value}='" . $data->{default_value} . "'");
        $DB->do("UPDATE object_field SET default_value=? WHERE id=?", undef, ($local_params->{default_value}, $object_field_id)) || die $DB->errstr unless ($data->{default_value} eq $local_params->{default_value});
    } else {
        $DB->do("INSERT INTO object_field (object_type_id, name, description, default_value, type, hidden, readonly, required, sortby, create_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())", undef, ($object_type_id, $local_params->{name}, $local_params->{description}, $local_params->{default_value}, $local_params->{type}, $local_params->{hidden}, $local_params->{readonly}, $local_params->{required}, $local_params->{sortby})) || die $DB->errstr;
        my $object_field_id = $DB->{mysql_insertid};
        MinorImpact::log('debug', "new object_field_id='$object_field_id'");
        my $field = new MinorImpact::Object::Field($object_field_id);
        MinorImpact::log('debug', "\$field->defaultValue()='" . $field->defaultValue() . "'");
        my $data = $DB->selectall_arrayref("SELECT id FROM object WHERE object_type_id=?", {Slice=>{}}, ($object_type_id)) || die $DB->errstr;
        foreach my $row (@$data) {
            my $object_id = $row->{id};
            MinorImpact::Object::clearCache($object_id);
            if ($field->isText()) {
                $DB->do("INSERT INTO object_text (object_id, object_field_id, value, create_date) VALUES (?, ?, ?, NOW())", undef, ($object_id, $object_field_id, $field->defaultValue())) || die $DB->errstr;
            } else {
                $DB->do("INSERT INTO object_data (object_id, object_field_id, value, create_date) VALUES (?, ?, ?, NOW())", undef, ($object_id, $object_field_id, $field->defaultValue())) || die $DB->errstr;
            }
        }
    }
}

=head2 clearCache

=over

=item ->clearCache()

=back

Clear the cache of anything related to $TYPE.

  $TYPE->clearCache();

=cut

sub clearCache {
    my $self = shift || return;

    my $object_type_id;

    my $object_type_id = $self->typeID();
    MinorImpact::Object::Type::clearCache($object_type_id);

    return;
}

=head2 delete

=over

=item ->delete(\%params)

=item ::delete(\%params)

=back

Delete a field.

=head3 params

=over

=item object_field_id => $int

Only requried if called as a package subroutine, rather than a $FIELD object
method.

  MinorImpact::Object::Field::delete({ object_field_id => 3 });

=item object_type_id => $int

=item name => $string

=back

=cut

sub delete {
    my $self = shift || return;
    my $params = shift || {};

    if (ref($self) eq 'HASH') {
        $params = $self;
        undef($self);
    }

    if ($self) {
        $params->{object_type_id} = $self->typeID();
        $params->{object_field_id} = $self->id();
        $params->{name} = $self->name();
    }

    my $DB = MinorImpact::db() || die "Can't connect to database.";

    my $object_type_id = $params->{object_type_id} || die "No object type id";
    my $object_field_id = $params->{object_field_id};
    my $name = $params->{name};

    if ($name && !$object_field_id) {
        $object_field_id = ($DB->selectrow_array("SELECT id FROM object_field WHERE object_type_id=? AND name=?", undef, ($object_type_id, $name)))[0] || return; # Do we really want do die on this hill? die $DB->errstr;
    }
    $DB->do("DELETE FROM object_data WHERE object_field_id=?", undef, ($object_field_id)) || die $DB->errstr;
    $DB->do("DELETE FROM object_text WHERE object_field_id=?", undef, ($object_field_id)) || die $DB->errstr;
    $DB->do("DELETE FROM object_field WHERE object_type_id=? AND name=?", undef, ($object_type_id, $name)) || die $DB->errstr;
    MinorImpact::cache("object_field_$object_type_id", {});
    MinorImpact::cache("object_type_$object_type_id", {});
}

sub del { MinorImpact::Object::Field::delete(@_); }
sub deleteField { del(@_); }
sub delField { del(@_); }

sub isText { return shift->{attributes}{is_text}; }

sub typeID {
    return shift->{db}{object_type_id};
}

=head1 AUTHOR

Patrick Gillan <pgillan@minorimpact.com>

=cut

1;
