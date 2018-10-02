# NAME

MinorImpact::User

# SYNOPSIS

# DESCRIPTION

The object representing application users.

## Getting the current user.

    use MinorImpact;
    my $MINORIMPACT = new MinorImpact();
    my $user = $MINORIMPACT->user();
    if (!$user) {
        die "No currently logged in user.";
    }

# OBJECT METHODS

- get( $field )

    Returns the value of $field.

- id()

    Returns the user's ID.

- isAdmin()

    Returns TRUE if the user has administrative priviledges for this application.

- name() 

    Returns the user's 'name' field.  A shortcut to get('name').

- search( \\%params )

    A passthru function that appends the user\_id of the user object to to the query 
    hash of %params.

- settings()

    Returns the user's MinorImpact::settings object.

- update( \\%fields )

    Update one or more user fields.

- validateUser( $password )

    Returns TRUE if $password is valid.

# AUTHOR

Patrick Gillan (pgillan@minorimpact.com)
