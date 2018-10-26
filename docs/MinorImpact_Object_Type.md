# NAME

MinorImpact::Object::Type 

# SYNOPSIS

# DESCRIPTION

# METHODS

## new

## del

- ->del(\\%params)
- ::del(\\%params)

Delete a given object type from the system.

    MinorImpact::Object::Type::del({ object_type_id => 'object'});

    $TYPE->del();

### params

- object\_type\_id

    The type ID of the object to the delete. 

## fields

- ->fields(\\%params)
- ::fields(\\%params);

Return a hash of field objects.

### params

- object\_id

    Pre fill the field values with data from a particular object.

        $fields = $TYPE->fields({ object_id => 445 });

- object\_type\_id

        $fields = MinorImpact::Object::Type::fields({ object_type_id => 'MinorImpact::settings' });

## form

## get

## id

Returns the id of this type.

    $TYPE->id();

## name

Return the name of this $TYPE.

    $TYPE->name();

## toData

Returns $TYPE as a pure hash.

    $type = $TYPE->toData();

## toString

- ->toString(\\%params)

Return $TYPE as a string.

    print $TYPE->toString();

### params

- format
    - json

        Return [MinorImpact::Object::Type::toData()](./MinorImpact_Object_Type.md#todata) as a 
        JSON formatted string.

            print $TYPE->toString({ format => 'json' });

# SUBROUTINES

## add

- add( \\%options )

Add a new object type to the MinorImpact application.

### options

- name => STRING

    The name of the object.  This must also be how it's accessed in code:

        $new_name_object = new <name>({ param1 => 'foo' });

- no\_name => BOOLEAN

    If TRUE, this object will not include a "Name" field in input/edit forms. If
    developer doesn't add a name value programatically during the 'new' or 
    'update' functions of the inherited object class, 
    '$object->type()->name() . "-" . $obect-id()' will be used instead.

    Default: FALSE

- no\_tags => BOOLEAN

    If TRUE, this type will no longer support tagging.

    DEFAULT: FALSE

- public => BOOLEAN

    This option does \*\*not\*\* make the objects public.  If TRUE, the user will have
    the \*option\* of designating the type a public.  Essentially controls whether or
    the the 'public' checkbox appears on object input/edit forms.

    Default: FALSE

- readonly => BOOLEAN

    'readonly' objects are not editable by the user, and they will never be given 
    option from the standard library.  These differ from 'sytem' objects by virtue
    of having and owners and containing information that's relevant to said user.

    Default: FALSE

- system => BOOLEAN

    Objects marked 'system' are meant to be core parts of the application - think
    dropdowns or statuses.  They can be instantiated by any user, but only an 
    admin user can add or edit them.
    Default: FALSE

## addField

- addField(\\%options)

Adds a field to the database

    MinorImpact::Object::Type::addField({ object_type_id => $object_type_id, name=>'address', type=>'string'});

### options

- name

    The field name.

- type

    The type of field.

## setVersion

- setVersion

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
