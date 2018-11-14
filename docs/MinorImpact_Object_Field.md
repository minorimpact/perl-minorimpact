# NAME

MinorImpact::Object::Field - Base class for MinorImpact object fields

# METHODS

## new

- new MinorImpact::Object::Field($object\_field\_id)
- new MinorImpact::Object::Field(\\%data)

Create a new field object.  If called with $object\_field\_id or if $data->{db}{id} is set, it will
try to create a field that belongs to a particular type of object, as defined by
[MinorImpact::Object::Type::addField()](./MinorImpact_Object_Type.md#addfield).

### data

- attributes => \\%hash
    - max\_length => $int

        The max length of the field.

    - is\_text => yes/no

        Is the field a text field (y) or a normal length data field (n)?
- db => \\%hash
    - id => $int

        The database id of this particular field.
- object\_id => $int

    The id of the $OBJECT this field belongs to, if applicable.

- value => \\@array

    A pointer to an array of values for this field.

## defaultValue

- ->defaultValue()

Returns the default value for the field.

    $default_value = $FIELD->defaultValue();

## update

- ->update($value\[, $value, ... \])

Sets the value(s) for the field.

    $FIELD->udpate("Sven", "Gustav");

If the field type is a reference to another object (or
an array of objects), $value can be an object or that 
object's id.

    $object = new MinorImpact::Object(45);
    $FIELD->update($object);

## validate

- ->validate($value)

Verify that $value satisfies the conditions of the current field, or
die.

    eval {
        $FIELD->validate($value);
    };
    print "Unable to use $value: $@" if ($@);

- ::unpackValues($value\[, $value, ...\])

Tries to smooth out all of the possible ways that values get packed up
for fields, starting with coverting any array pointers in the parameter list
to actual arrays, splitting any values that are delimited by a null character ('\\0',
something that HTML multi-select input fields produce), and converting and 
[MinorImpact objects](./MinorImpact_Object.md) to their ->id() value.

## value

- ->value()

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
will be objects, not IDs.

## displayName

- ->displayName()

Returns a "nicer" version of name.

## get

- ->get($name)

Returns piece of meta data about this field.

## isArray

Returns TRUE if the field contains and array of values.

    if ($FIELD->isArray()) {
      # do array things
    } else {
      # do scalar things
    }

## isHidden

Returns TRUE is this field is marked 'hidden'.

    if ($FIELD->isHidden()) {
      # don't show the field
    } else {
      # show the field
    }

Equivilant to:

    $FIELD->get('hidden');

## isReadonly

Returns TRUE is this field is marked 'readonly'.

    if ($FIELD->isReadonly()) {
      # no editing
    } else {
      # edit
    }

Equivilant to:

    $FIELD->get('readonly');

## isRequired

Returns TRUE is this field is marked 'required'.

    if ($FIELD->isRequired()) {
      # set the field
    } else {
      # don't set the field
    }

Equivilant to:

    $FIELD->get('required');

## add

- ::add(\\%params)

    MinorImpact::Object::Field::add

### params

- default\_value => $string

    The default value of the field if nothing is set by the user.

- description => $string

    A brief description of the field.  Currently unused, but eventually intended
    for "help" tooltips on forms, or other places.

- hidden => TRUE/FALSE

    This field will not be shown to the user or editable on forms.  Default: FALSE

- name => $string

    Field name.  Required.

- object\_type\_id => $int

    The object type this field will be 
    &#x3d;item readonly => TRUE/FALSE

    Field will be shown to the user, but will not be editable on forms.  Default: FALSE

- required => TRUE/FALSE

    Whether or not this field is required to be set.  Default: FALSE

- sortby => TRUE/FALSE

    This field will be used by [MinorImpact::Object::cmp()](./MinorImpact_Object.md#cmp) to 
    sort lists of objects.  If set on more than one field in the same object type, results
    are undefined. Default: FALSE

- type => $string

    The type of field.  Required.

    Some valid types are "string", "int", "float", "text", "datetime", and "boolean".
    See [MinorImpact::Manual::Objects](./MinorImpact_Manual_Objects.md#fields) for more
    information.

## clearCache

- ->clearCache()

Clear the cache of anything related to $TYPE.

    $TYPE->clearCache();

## delete

- ->delete(\\%params)
- ::delete(\\%params)

Delete a field.

### params

- object\_field\_id => $int

    Only requried if called as a package subroutine, rather than a $FIELD object
    method.

        MinorImpact::Object::Field::delete({ object_field_id => 3 });

- object\_type\_id => $int
- name => $string

## toData

Return the object as a pure hash.

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>

# POD ERRORS

Hey! **The above document had some coding errors, which are explained below:**

- Around line 297:

    Unknown directive: =head
