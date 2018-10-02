# NAME 

MinorImpact::Object - The base class for MinorImpact objects.

# SYNOPSIS

    use MinorImpact;
    use MinorImpact::Object;
    $object = new MinorImpact::Object({ object_type_id => 'type', name => $name, description => 'bar' });
    $description = $object->get('description');
    print $object->name() . ": $description\n";

    # output
    foo: bar

# DESCRIPTION

# METHODS

- MinorImpact::Object::new( $id )
- MinorImpact::Object::new( { field => value\[, ...\] })

    Create a new MinorImpact::Object.

- back( \\%options )

    Returns the url that makes the most sense when returning from viewing or editing this 
    object. Options:

        url     Additional url parameters that you want to be included in the link.

- id() 

    Returns the id of the this objec.t

- name( \\%options )

    Returns the 'name' value for this object.   Shortcut for ->get('name', \\%options). 

- public()
- userID()

    The ID of the user this object belongs to.

- update( { field => value \[,...\] })

    Update the value of one or more of the object fields.

- $object->validateUser( \\%options ) 

    Verify that a given user has permission to instantiate this object.  Returns true for "system"
    object types. Options:

        user              A MinorImpact::User object.  Defaults to the the current logged 
                          in user if one exists.

- version()

    The value of the $VERSION variable ihe inherited class, or 0.

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
