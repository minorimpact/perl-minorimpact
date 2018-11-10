# NAME

MinorImpact::Object::Field - Base class for MinorImpact object fields.

# METHODS

## new

- new MinorImpact::Object::Field($object\_field\_id)
- new MinorImpact::Object::Field(\\%data)

Create a new field object.

### data

- attributes => \\%hash
    - max\_length => $int

        The max length of the field.

    - is\_text => yes/no

        Is the field a text field (y) or a normal length data field (n)?
- db => \\%hash
    - id => $int
- object\_id => $int

    The id of the $OBJECT this field belongs to, if applicable.

- value => \\@array

    A pointer to an array of values for this field.

## validate

- ->validate($value)

Verify that $value satisfies the conditions of the current field, or
die.

    eval {
        $FIELD->validate($value);
    };
    print "Unable to use $value: $@" if ($@);

## value

- ->value()

Returns a pointer to an array of values.

    $values = $FIELD->value();
    if ($FIELD->isArray()) {
      foreach my $value (@$values) {
        print "$value\n";
      }
    } else {
      print $values[0] . "\n";
    }

NOTE: This returns an array pointer because sometimes fields are arrays, and
it's just easier to always return an array - even if it's just one value - than
it is to have to make the decision every time.

If the field type is a reference to another MinorImpact::Object, the values returned
will be objects, not IDs.

## displayName

- ->displayName()

Returns a "nicer" version of name.

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
