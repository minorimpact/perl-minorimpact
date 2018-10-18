# NAME

MinorImpact::Object::Type 

# SYNOPSIS

# DESCRIPTION

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

## del

- ::del(\\%params)

Delete a given object type from the system.

    MinorImpact::Object::Type::del({ object_type_id => 'object'});

### params

- object\_type\_id

    The type ID of the object to the delete.  REQUIRED.

## setVersion

- setVersion

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>

# POD ERRORS

Hey! **The above document had some coding errors, which are explained below:**

- Around line 151:

    You forgot a '=back' before '=head2'
