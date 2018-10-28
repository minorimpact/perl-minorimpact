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
