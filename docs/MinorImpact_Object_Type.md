# NAME

# SYNOPSIS

# DESCRIPTION

# METHODS

- add( \\%options )

    Add a new object type to the MinorImpact application.

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

- setVersion

# AUTHOR

Patrick Gillan (pgillan@minorimpact.com)
