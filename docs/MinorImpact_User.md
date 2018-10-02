# NAME

MinorImpact::User

# SYNOPSIS

    use MinorImpact;
    
    my $MINORIMPACT = new MinorImpact();
    
    # Get the current user.
    my $user = $MINORIMPACT->user();
    if (!$user) {
        die "No currently logged in user.";
    }

# DESCRIPTION

The object representing application users.

# METHODS

## get($field)

Returns the value of $field.

## id()

Returns the user's ID.

## isAdmin()

Returns TRUE if the user has administrative priviledges for this application.

## name() 

Returns the user's 'name' field.  A shortcut to get('name').

## search(\\%params)

A passthru function that appends the user\_id of the user object to to the query 
hash of %params.

## settings()

Returns the user's MinorImpact::settings object.

    $settings = $user->settings();

## update(\\%fields)

Update one or more user fields.

## validateUser($password)

Returns TRUE if $password is valid.

    # Check if the user's password is "password".
    if ($user->validateUser("password")) {
        print "This is a bad password\n";
    }

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
