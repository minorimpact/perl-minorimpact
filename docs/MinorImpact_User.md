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

## get

- get($field)

Returns the value of $field.

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

A shortcut to ["MinorImpact::Object::Search/search" in MinorImpact::Object::Search::search()](./MinorImpact_Object_Search_search\(\.md)#MinorImpact::Object::Search-search) that
adds the current user\_id to the parameter list.

    @objects = $USER->searchObjects({name => '%panda% });
    # ... is equivalent to:
    @objects = MinorImpact::Object::Search::search({ name => '%panda%', user_id=>$USER->id() });

## settings

Returns the user's MinorImpact::settings object.

    $settings = $user->settings();

## update

- update(\\%fields)

Update one or more user fields.

    $USER->update({name => "Sting", address => "6699 Tantic Ave." });

## validateUser

- validateUser($password)

Returns TRUE if $password is valid.

    # Check if the user's password is "password".
    if ($user->validateUser("password")) {
        print "This is a bad password\n";
    }

# SUBROUTINES

## search

- search(\\%params)

Search the database for users that match.

### Parameters

- name

    Search for users by name.  Supports MySQL wildcards.

        @users = MinorImpact::User::search({name => "% Smith" });

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
