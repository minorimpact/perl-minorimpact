package MinorImpact::Object::Field;

use strict;

use Data::Dumper;
use JSON;
use MinorImpact;
use MinorImpact::Util;
use MinorImpact::Util::String;
use MinorImpact::Object::Field::boolean;
use MinorImpact::Object::Field::datetime;
use MinorImpact::Object::Field::float;
use MinorImpact::Object::Field::int;
use MinorImpact::Object::Field::object;
use MinorImpact::Object::Field::password;
use MinorImpact::Object::Field::text;
use MinorImpact::Object::Field::url;
use MinorImpact::Object::Type;
use Text::Markdown 'markdown';

=head1 NAME

MinorImpact::Object::Field - Base class for MinorImpact object fields

=head1 METHODS

=cut

our @valid_types = ('boolean', 'datetime', 'float', 'int', 'object', 'password', 'string', 'text', 'url');
our @reserved_names = ( 'create_date', 'description', 'id', 'mod_date', 'name', 'object_type_id', 'public', 'user_id' );

=head2 new

=over

=item new MinorImpact::Object::Field($object_field_id)

=item new MinorImpact::Object::Field(\%data)

=back

Create a new field object.  If called with $object_field_id or if $data->{db}{id} is set, it will
try to create a field that belongs to a particular type of object, as defined by
L<MinorImpact::Object::Type::addField()|MinorImpact::Object::Type/addfield>.

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

The database id of this particular field.

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
        $field_type = 'object' if ($field_type =~/^\@?object\[\d+\]$/);
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
    $self->{attributes}{string_value_seperator} = ",";

    # Override the default field attributes with anything added by an
    #   inherited class.
    $self->{attributes} = { %{$self->{attributes}}, %{$data->{attributes}} };
    $self->{db} = clone($data->{db});
    $self->{attributes}{default_value} = $self->{db}{default_value} if ($self->{db}{default_value});

    $self->{object_id} = $data->{object_id};
    $self->{value} = [];

    if (defined($data->{value})) {
        # We're being manually assigned a value when the field object is being
        #   created.  Just use that.
        #if (ref($data->{value}) eq 'ARRAY') {
        #    foreach my $value (@{$data->{value}}) {
        #        push(@{$self->{value}}, split(/\0/, $value));
        #    }
        #} else {
        #    push(@{$self->{value}}, split(/\0/, $data->{value}));
        #}
        my @values = unpackValues($data->{value});
        foreach my $value (@values) {
            push(@{$self->{value}}, { value => $value });
        }
    } elsif ($self->{db}{id} && $self->{object_id}) {
        # We're a field that exists in the database and we're assinged to a 
        #   particular object.  Load the values from the the database.
        my $DB = MinorImpact::db();
        my $data_table = "object_data";
        if ($self->{attributes}{is_text}) {
            $data_table = "object_text";
        }
        my $data = $DB->selectall_arrayref("SELECT id, value FROM $data_table WHERE object_field_id=? AND object_id=?", {Slice=>{}}, ($self->{db}{id}, $self->{object_id}));
        foreach my $row (@$data) {
            MinorImpact::log('debug',"\$row->{value}='" . $row->{value} . "'");
            push(@{$self->{value}}, { value=> $row->{value}, value_id=>$row->{id} });
        }
    }

    # We didn't get any values from either of those other two places, so just use the default,
    #  if one is set.
    if (scalar(@{$self->{value}}) == 0 && defined($self->{attributes}{default_value})) {
        push(@{$self->{value}}, { value => $self->{attributes}{default_value} });
    }

    MinorImpact::log('debug', "ending");
    return $self;
}

=head2 defaultValue

=over

=item ->defaultValue()

=back

Returns the default value for the field.

  $default_value = $FIELD->defaultValue();

=cut

sub defaultValue {
    return shift->{db}{default_value};
}

=head2 update

=over

=item ->update($value[, $value, ... ])

=back

Sets the value(s) for the field.

  $FIELD->udpate("Sven", "Gustav");

If the field type is a reference to another object (or
an array of objects), $value can be an object or that 
object's id.

  $object = new MinorImpact::Object(45);
  $FIELD->update($object);

=cut

sub update {
    my $self = shift || return;

    MinorImpact::log('debug', "starting");
    my @values = unpackValues(@_);

    foreach my $value (@values) {
        $self->validate($value);
    }

    if ($self->id() && $self->object_id()) {
        my $object_id = $self->object_id();
        MinorImpact::Object::clearCache($object_id);
        my $DB = MinorImpact::db();
        if ($self->isText()) {
            $DB->do("DELETE FROM object_text WHERE object_id=? AND object_field_id=?", undef, ($object_id, $self->id())) || die $DB->errstr;
        } else {
            $DB->do("DELETE FROM object_data WHERE object_id=? AND object_field_id=?", undef, ($object_id, $self->id())) || die $DB->errstr;
        }
        foreach my $value (@values) {
            my $sql;
            if ($self->isText()) {
                $sql = "INSERT INTO object_text(object_id, object_field_id, value, create_date) VALUES (?, ?, ?, NOW())";
            } else {
                $sql = "INSERT INTO object_data(object_id, object_field_id, value, create_date) VALUES (?, ?, ?, NOW())";
            }
            MinorImpact::log('debug', "$sql, '$object_id','" . $self->id() . "','$value'");
            $DB->do($sql, undef, ($object_id, $self->id(), $value)) || die $DB->errstr;
            my $value_id = $DB->{mysql_insertid};
            push (@{$self->{value}}, { value => $value, value_id => $value_id});
        }
    } else {
        foreach my $value (@values) {
            push(@{$self->{value}}, { value => $_ });
        }
    }

    foreach my $reference ($self->references()) {
        # TODO: Other people can create references between objects they don't own, references that won't get ever
        #   deleted because they will never come up again... this could (will) be a major problem.
        unless ($reference->verify()) {
            $reference->delete();
        }
    }

    MinorImpact::log('debug', "ending");
    return @values;
}

=head2 validate

=over

=item ->validate($value)

=back

Verify that $value satisfies the conditions of the current field, or
die.

  eval {
      $FIELD->validate($value);
  };
  print "Unable to use $value: $@" if ($@);

=cut

sub validate {
    my $self = shift || return;
    my $value = shift || return;

    MinorImpact::log('debug', "starting");

    if ((!defined($value) || (defined($value) && $value eq '')) && $self->get('required')) {
        MinorImpact::log('debug', "ending(invalid - blank)");
        die $self->name() . " cannot be blank";
    }
    if ($value && $self->{attributes}{maxlength} && length($value) > $self->{attributes}{maxlength}) {
        MinorImpact::log('debug', "ending(invalid - too large)");
        die $self->name() . ": value is too large.";
    }

    MinorImpact::log('debug', "ending(valid)");
    return $value;
}

=head2 unpackValues

=over

=item ::unpackValues($value[, $value, ...])

=back

Tries to smooth out all of the possible ways that values get packed up
for fields, starting with coverting any array pointers in the parameter list
to actual arrays, splitting any values that are delimited by a null character ('\0',
something that HTML multi-select input fields produce), and converting and 
L<MinorImpact objects|MinorImpact::Object> to their ->id() value.

=cut

sub unpackValues {
    my @values = ();
    foreach my $v (@_) {
        if (ref($v) eq 'ARRAY') {
            push(@values, @{$v});
        } else {
            push(@values, $v);
        }
    }

    my @split_values = ();
    foreach my $value (@values) {
        if (ref($value)) {
            my $id = $value->id();
            push(@split_values, $id);
        } else {
            foreach my $split_value (split(/\0/, $value)) {
                push(@split_values, $split_value);
            }
        }
    }

    return @split_values;
}

=head2 value

=over

=item ->value(\%params)

=back

Returns an array of values.

  @values = $FIELD->value();
  if ($FIELD->isArray()) {
    foreach my $value (@values) {
      print "$value\n";
    }
  } else {
    print $values[0] . "\n";
  }

NOTE: This returns an array because sometimes fields are arrays, and
it's just easier to always return an array - even if it's just one value - than
it is to have to make the decision every time.

If the field type is a reference to another MinorImpact::Object, the values returned
will be objects, not IDs (unless the C<id_only> param is set).

=head3 params

=over

=item id_only => TRUE/FALSE

If the field is a L<MinorImpact::Object|MinorImpact::Object>, return the
object's id, rather than the obect itelf.  
DEFAULT: FALSE

=item value_id => TRUE/FALSE

Rather than an array of values, return an array of hashes with the C<value> and
C<value_id> keys set to the value and internal ID field of the object_value (or object_text) 
row from the database.  
DEFAULT: FALSE

=back

=cut

sub value { 
    my $self = shift || return; 
    my $params = shift || {};

    MinorImpact::log('debug', "starting");
    my $values = [];
    if (defined($self->{value})) {
        foreach my $value (@{$self->{value}}) {
            if (ref($self->type()) && !$params->{id_only}) {
                if ($params->{value_id}) {
                    push(@$values, { value => new MinorImpact::Object($value->{value}), value_id=>$value->{value_id}});
                } else {
                    push(@$values, new MinorImpact::Object($value->{value}));
                }
            } else {
                my $local_value = clone($value);
                if ($self->get('references') && (defined($params->{references}) && $params->{references} != 0)) {
                    my @references = $self->references();
                    foreach my $ref (@references) {
                        my $data = $ref->get('data');
                        my $test_data = $data;

                        $test_data =~s/\W/ /gm;
                        $test_data = join("\\W+?", split(/[\s\n]+/, $test_data));
                        if ($local_value->{value} =~/($test_data)/mgi) {
                            my $match = $1;
                            my $url = MinorImpact::url({ action => 'object', object_id => $ref->get('reference_object')->id()});
                            $local_value->{value} =~s/$match/<a href='$url'>$data<\/a>/;
                        }
                    }
                }
                if ($params->{value_id}) {
                    push(@$values, $local_value);
                } else {
                    push(@$values, $local_value->{value});
                }
            }
        }
    }
    MinorImpact::log('debug', "ending");
    return @$values;
}

sub fieldName {
    my $self = shift || return;

    return $self->name();
}

=head2 displayName

=over

=item ->displayName()

=back

Returns a "nicer" version of name.

=cut

sub displayName {
    my $self = shift || return;

    my $display_name = $self->name();
    $display_name =~s/_id$//;
    $display_name =~s/_date$//;
    $display_name =~s/_/ /g;
    $display_name =~s/^MinorImpact:://;
    $display_name = ucfirst($display_name);

    return $display_name;
}

# return a piece of metadata about this field.
=head2 get

=over

=item ->get($name)

=back

Returns piece of meta data about this field.

=cut

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

sub object {
    my $self = shift || die "no field";

    my $object = new MinorImpact::Object($self->object_id());
    return $object;
}

sub references {
    my $self = shift || die "no field";

    return unless ($self->get('references'));
    my $object_id = $self->object_id() || return;
    my $id = $self->id() || return;

    my @references = MinorImpact::Object::Search::search({
        query => {
            object_type_id => 'MinorImpact::reference', 
            object => $object_id, 
            object_field_id => $id
        }
    });

    return @references;
}

sub toString { 
    my $self = shift || return; 
    my $params = shift || {};
    
    my $string;
    my $sep = $self->{attributes}{string_value_seperator};

    if ($params->{format} eq 'json') {
        $string = to_json($self->toData());
    } else {
        foreach my $value ($self->value($params)) {
            if (ref($value)) {
                $string .= $value->toString($params);
            } else {
                $string .= "$value";
            }
            if ($self->get('references') && $params->{references}) {
                my $object_id = $self->object_id();
                my $id = $self->id();
                if ($object_id && $id) {
                    $string = "<div onmouseup='getSelectedText(" . $object_id . "," . $id . ");'>$string</div>\n";
                }
            }
            $string .= $sep;
        }
        $string =~s/$sep$//;
    }

    return $string;
}

sub type {
    my $self = shift || return;

    MinorImpact::log('debug', "starting");

    my $type = $self->{db}{type};

    if ($type =~/object/) {
        my $object_type;
        if ($type =~/^\@?object\[(\d+)\]$/) {
            my $object_type_id = $1;
            $object_type = new MinorImpact::Object::Type($object_type_id);
        } elsif ($type =~/^\@?object$/) {
            $object_type = new MinorImpact::Object::Type();
        }
        $type = $object_type if ($object_type);
    }

    MinorImpact::log('debug', "ending");
    return $type;
}

# Returns a row in a table that contains the field name and the input field.
sub rowForm {
    my $self = shift || return;
    my $params = shift || {};

    MinorImpact::log('debug', "start(" . $self->name() . ")");

    my $name = $self->name()|| return;
    my $local_params = clone($params);

    my @values;
    @values = @{$local_params->{value}} if (defined($local_params->{value}));
    @values = $self->value({id_only=>1}) unless (scalar(@values));
    
    my $row;
    if ($self->isArray()) {
        foreach my $value (@values) {
            my $row_form;
            $local_params->{row_value} = htmlEscape($value) unless (ref($value));
            MinorImpact::tt('row_form', { field => $self, input => $self->_input($local_params) }, \$row_form);
            $row .= $row_form;
        }
        $local_params->{duplicate} = 1;
        delete($local_params->{row_value});
        my $row_form;
        MinorImpact::tt('row_form', { field => $self, input => $self->_input($local_params) }, \$row_form);
        $row .= $row_form;
    } else {
        $local_params->{row_value} = htmlEscape($values[0]) unless (ref($values[0]));
        MinorImpact::tt('row_form', { field => $self, input => $self->_input($local_params) }, \$row);
    }
    MinorImpact::log('debug', "ending");
    return $row;
}

# Returns the form input control for this field.
sub _input {
    my $self = shift || return;
    my $params = shift || {};

    MinorImpact::log('debug', "starting");

    my $name = $params->{name} || $self->name();
    my $value = $params->{row_value};
    my $row;
    if (ref($self->type())) {
        if ( $self->isHidden() || $self->isReadonly()) {
            $row .= "<input type=hidden name='$name' id='$name' value='$value'>\n";
            if (!$self->isHidden()) {
                my $object = new MinorImpact::Object($value);
                if ($object) {
                    $row .= $object->toString();
                }
            }
        } else {
            my $local_params = clone($params);
            $local_params->{query}{debug} .= "Object::Field::_input();";
            $local_params->{query}{object_type_id} = $self->type()->id();
            $local_params->{fieldname} = $name;
            $local_params->{selected} = $value;
            $local_params->{required} = $self->get('required');
            $row .= "" .  MinorImpact::Object::selectList($local_params);
        }
    } elsif ( $self->get('hidden') ) {
        $row .= "<input type=hidden name='$name' id='$name' value='$value'>\n";
    } elsif ( $self->isReadonly() ) {
        $row .= "$value <input type=hidden name='$name' id='$name' value='$value'>\n";
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

    MinorImpact::log('debug', "ending");
    return $row;
}

=head2 isArray

Returns TRUE if the field contains and array of values.

  if ($FIELD->isArray()) {
    # do array things
  } else {
    # do scalar things
  }

=cut

sub isArray {
    my $self = shift || return;

    return 1 if ($self->type() =~/^\@/);
    return 0;
}

=head2 isHidden

Returns TRUE is this field is marked 'hidden'.

  if ($FIELD->isHidden()) {
    # don't show the field
  } else {
    # show the field
  }

Equivilant to:

  $FIELD->get('hidden');

=cut

sub isHidden {
    return shift->get('hidden');
}

=head2 isReadonly

Returns TRUE is this field is marked 'readonly'.

  if ($FIELD->isReadonly()) {
    # no editing
  } else {
    # edit
  }

Equivilant to:

  $FIELD->get('readonly');

=cut

sub isReadonly {
    return shift->get('readonly');
}

=head2 isRequired

Returns TRUE is this field is marked 'required'.

  if ($FIELD->isRequired()) {
    # set the field
  } else {
    # don't set the field
  }

Equivilant to:

  $FIELD->get('required');

=cut

sub isRequired {
    return shift->get('required');
}

=head2 add

=over

=item ::add(\%params)

=back

  MinorImpact::Object::Field::add

=head3 params

=over

=item default_value => $string

The default value of the field if nothing is set by the user.

=item description => $string

A brief description of the field.  Currently unused, but eventually intended
for "help" tooltips on forms, or other places.

=item hidden => TRUE/FALSE

This field will not be shown to the user or editable on forms.  Default: FALSE

=item name => $string

Field name.  Required.

=item object_type_id => $int

The object type this field will be 
=item readonly => TRUE/FALSE

Field will be shown to the user, but will not be editable on forms.  Default: FALSE

=item required => TRUE/FALSE

Whether or not this field is required to be set.  Default: FALSE

=item sortby => TRUE/FALSE

This field will be used by L<MinorImpact::Object::cmp()|MinorImpact::Object/cmp> to 
sort lists of objects.  If set on more than one field in the same object type, results
are undefined. Default: FALSE

=item type => $string

The type of field.  Required.

Some valid types are "string", "int", "float", "text", "datetime", and "boolean".
See L<MinorImpact::Manual::Objects|MinorImpact::Manual::Objects/fields> for more
information.

=back

=cut

sub add {
    my $params = shift || return;
    MinorImpact::log('debug', "starting");

    my $DB = MinorImpact::db() || die "Can't connect to database.";

    my $local_params = clone($params);
    my $object_type = new MinorImpact::Object::Type($local_params->{object_type_id}) || die "No object type id";
    my $object_type_id = $object_type->id();

    $local_params->{name} || die "Field name can't be blank.";
    $local_params->{type} || die "Field type can't be blank.";
    $local_params->{hidden} = $local_params->{hidden}?1:0;
    $local_params->{sortby} = $local_params->{sortby}?1:0;
    $local_params->{readonly} = $local_params->{readonly}?1:0;
    $local_params->{references} = $local_params->{references}?1:0;
    $local_params->{required} = $local_params->{required}?1:0;
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
    my $field;
    MinorImpact::log('debug', "adding field '" . $object_type_id . "-" . $local_params->{name} . "'");
    my $data = $DB->selectrow_hashref("SELECT * FROM object_field WHERE object_type_id=? AND name=?", {Slice=>{}}, ($object_type_id, $local_params->{name}));
    if ($data) {
        my $object_field_id = $data->{id};
        $DB->do("UPDATE object_field SET type=? WHERE id=?", undef, ($local_params->{type}, $object_field_id)) || die $DB->errstr unless ($data->{type} eq $local_params->{type});
        $DB->do("UPDATE object_field SET hidden=? WHERE id=?", undef, ($local_params->{hidden}, $object_field_id)) || die $DB->errstr unless ($data->{hidden} eq $local_params->{hidden});
        $DB->do("UPDATE object_field SET sortby=? WHERE id=?", undef, ($local_params->{sortby}, $object_field_id)) || die $DB->errstr unless ($data->{sortby} eq $local_params->{sortby});
        $DB->do("UPDATE object_field SET readonly=? WHERE id=?", undef, ($local_params->{readonly}, $object_field_id)) || die $DB->errstr unless ($data->{readonly} eq $local_params->{readonly});
        $DB->do("UPDATE object_field SET `references`=? WHERE id=?", undef, ($local_params->{references}, $object_field_id)) || die $DB->errstr unless ($data->{references} eq $local_params->{references});
        $DB->do("UPDATE object_field SET required=? WHERE id=?", undef, ($local_params->{required}, $object_field_id)) || die $DB->errstr unless ($data->{required} eq $local_params->{required});
        $DB->do("UPDATE object_field SET description=? WHERE id=?", undef, ($local_params->{description}, $object_field_id)) || die $DB->errstr unless ($data->{description} eq $local_params->{description});
        MinorImpact::log('debug', "UPDATE object_field SET default_value=? WHERE id=?,'" . $local_params->{default_value} . "', '$object_field_id', \$data->{default_value}='" . $data->{default_value} . "'");
        $DB->do("UPDATE object_field SET default_value=? WHERE id=?", undef, ($local_params->{default_value}, $object_field_id)) || die $DB->errstr unless ($data->{default_value} eq $local_params->{default_value});
        $field = new MinorImpact::Object::Field($object_field_id);
    } else {
        $DB->do("INSERT INTO object_field (object_type_id, name, description, default_value, type, hidden, readonly, references, required, sortby, create_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())", undef, ($object_type_id, $local_params->{name}, $local_params->{description}, $local_params->{default_value}, $local_params->{type}, $local_params->{hidden}, $local_params->{readonly}, $local_params->{references}, $local_params->{required}, $local_params->{sortby})) || die $DB->errstr;
        my $object_field_id = $DB->{mysql_insertid};
        MinorImpact::log('debug', "new object_field_id='$object_field_id'");
        $field = new MinorImpact::Object::Field($object_field_id);
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
    MinorImpact::log('debug', "ending");
    return $field;
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

    foreach my $reference ($self->references()) {
        # TODO: Other people can create references between objects they don't own, references that won't get ever
        #   deleted because they will never come up again... this could (will) be a major problem.
        $reference->delete();
    }

    $DB->do("DELETE FROM object_data WHERE object_field_id=?", undef, ($object_field_id)) || die $DB->errstr;
    $DB->do("DELETE FROM object_text WHERE object_field_id=?", undef, ($object_field_id)) || die $DB->errstr;
    $DB->do("DELETE FROM object_field WHERE object_type_id=? AND name=?", undef, ($object_type_id, $name)) || die $DB->errstr;
    $self->clearCache();
}

sub del { MinorImpact::Object::Field::delete(@_); }
sub deleteField { MinorImpact::Object::Field::delete(@_); }
sub delField { MinorImpact::Object::Field::delete(@_); }

sub isText { return shift->{attributes}{is_text}; }

=head2 toData

Return the object as a pure hash.

=cut

sub toData {
    my $self = shift || return;

    my $data = {};

    $data->{name} = $self->{db}{name};
    $data->{type} = $self->{db}{type};
    $data->{required} = $self->{db}{required};
    $data->{hidden} = $self->{db}{hidden};
    $data->{sortby} = $self->{db}{sortby};
    $data->{readonly} = $self->{db}{readonly};
    $data->{description} = $self->{db}{description};
    $data->{default_value} = $self->{db}{default_value};

    return $data;
}

sub typeID {
    return shift->{db}{object_type_id};
}

=head1 AUTHOR

Patrick Gillan <pgillan@minorimpact.com>

=cut

1;
