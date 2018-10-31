# NAME

MinorImpact::User

# SYNOPSIS

    use MinorImpact;
    
    my $MINORIMPACT = new MinorImpact();
    
    # Get the current user.
    my $USER = $MINORIMPACT->user();
    if (!$USER) {
        die "No currently logged in user.";
    }

# DESCRIPTION

The object representing application users.

# METHODS

## clearCache

- ->clearCache()

Clear all caches related to this user object.

    $USER->clearCache();

## delete

- delete(\\%params)

Delete the user and all of the objects owned by that user.

    $USER->delete();

## get

- get($field)

Returns the value of $field.

    $address = $USER->get('address');

## id

Returns the user's ID.

    $id = $USER->id();

## isAdmin

Returns TRUE if the user has administrative priviledges for this application.

    if ($USER->isAdmin()) {
        # Go nuts
    } else {
        # Go away
    }

## name

Returns the user's 'name' field.  A shortcut to get('name').

    $name = $USER->name();
    # ... is equivalent to:
    $name = $USER->get('name');

## searchObjects

- searchObjects()
- searchObjects(\\%params)

A shortcut to [MinorImpact::Object::Search::search()](./MinorImpact_Object_Search.md#search) that
adds the current user\_id to the parameter list.

    @objects = $USER->searchObjects({query => {name => '%panda% }});
    # ... is equivalent to:
    @objects = MinorImpact::Object::Search::search({ query => { name => '%panda%', user_id=>$USER->id() }});

## settings

Returns the user's MinorImpact::settings object.

    $settings = $user->settings();

## update

- update(\\%fields)

Update one or more user fields.

    $USER->update({name => "Sting", password => "1234" });

Updates can only be made by the user themself or an admin user.

### Fields

- admin

    True or false, this user has administrative rights in this application.
    Can only be set by another admin user.

- email

    Update the user's email address.

- encrypted

    Not a field, but if set to TRUE the `password` field will not be
    encrypted before being added to the database.

        $USER->update({ password => '4543jksdshjkHUIYUIr', encrypted => 1 });

- name

    Update the user's login name.

- password 

    Sets a new password.

## toData

- ->toData()

Returns the user data as a hash.

## toString

- ->toString(\\%params)

Returns a string representation of the user.

### params

- format
    - json

        Calls [MinorImpact::User::toData()](./MinorImpact_User.md#todata) and returns
        the hash formated as a JSON string.

## validateUser

- validateUser($password)

Returns TRUE if $password is valid.

    # Check if the user's password is "password".
    if ($user->validateUser("password")) {
        print "This is a bad password\n";
    }

# SUBROUTINES

## add

- ::add(\\%params)

Add a MinorImpact user.

    $new_user = MinorImpact::User::add({
      password => 'bar',
      username => 'foo', 
      email => 'foo@bar.com",
    });

### Settings

- admin => true/false

    Make the user an admin.

- email => $string

    Set the user's email to $string.

- encrypted => 0/1

    Set to 1 if the password has already been encrypted.

- password => $string

    The new user's password.

- name => $string

    The new user's login name.

## count

- count()
- count(\\%params)

A shortcut to [MinorImpact::User::search()](./MinorImpact_User.md#search)
that returns the number of results.  With no arguments, returns the 
total number of MinorImpact users.  With arguments, returns the number
of users matching the given criteria.

    # get the number of admin users
    $num_users = MinorImpact::Users::count({ admin => 1 });

## search

- search(\\%params)

Search the database for users that match.

### Parameters

- admin

    Return admin users.

        @users = MinorImpact::User::search({name => "% Smith" });

- limit

    Limit to X number of results.

        @users = MinorImpact::User::search({name => "% Smith", limit => 5 });

- name

    Search for users by name.  Supports MySQL wildcards.

        @users = MinorImpact::User::search({name => "% Smith" });

- order\_by

    Return returns sorted by a particular columnn.

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
