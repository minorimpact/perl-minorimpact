# NAME

MinorImpact - Application/object framework and utility library.

# SYNOPSIS

    use MinorImpact;

    $MINORIMPACT = new MinorImpact();

    # define a new object type
    MinorImpact::Object::Type::add({name => 'test'});

    # create a new object 
    $test = new MinorImpact::Object({ object_type_id => 'test', name => "test-$$" });
    print $test->id() . ": " . $test->get('name') . "\n";

    # retrieve a second copy of the same object using just the id
    $test2 = new MinorImpact::Object($test->id());
    print $test2->id() . ": " . $test2->get('name') . "\n";

    # add a field to the object definition
    MinorImpact::Object::Type::addField({ object_type_id => $test->typeID(), name => 'field_1', type => 'string' });
    $test->update({field_1 => 'one'});

    print $test->get('field_1') . "\n";

# DESCRIPTION

The main interface to the MinorImpact library.

# METHODS

## new(\\%options)

Create a new MinorImpact object.

    $MINORIMPACT = new MinorImpact({ option1 => "value1", option2 => "value2" });

### Options

- config

    A hash containing configuration items.

- config\_file

    The name of a file containing configuration options.

## cache($name, \[$value\], \[$timeout\])

Store, retrieve or delete name/value pairs from the global cache.  If value is not specified,
the previous value for $name is returned.  $timeout is in seconds, and the default value is
3600\.  Pass an empty hash pointer to clear the previous value.

    # remember the color value for five minutes
    $color = "red";
    $MINORIMPACT->cache("color", $color, 300);

    # retrieve the previous $color value
    $old_color = $MINORIMPACT->cache("color");

    # delete the previous color value
    $MINORIMPACT->cache("color", {});

$value can be a hash or an array pointer and a deep copy will be stored.

    $hash = { one => 1, two => 2 };
    $MINORIMPACT->cache("hash", $hash);

    $old_hash = $MINORIMPACT->cache("hash");
    print $old_hash->{one};
    # OUTPUT: 1

## user(\[\\%parameters\])

Returns the currently logged in user, or attempts to validate a user based on various
criteria.

    my $user = $MINORIMPACT->user();

If username and password aren't passed explicitly (and they usually aren't), this method
will first check the CGI object to see if there is a username and password included
in the URL parameters.  If not, it will check $ENV{USER} on a linux server to get the
currently logged in user.

Locking for multiple login attempts is built into this function, and more than 5 login
attempts in a 7 minute span from the same IP or for the same username will result in a 
silent, automatic failure.

If user() is called from a command line script (ie, if $ENV{USER} is set), then a new
user with a blank password will be created if no user already exists.  This is to make
writing scripts easier, since most command-line applications simply assume the user
has already been validated.  It will be up to the developer implement individual logins
if they need to, by testing to see if the current used has a blank password and then 
forcing the user to add a password. (see [MinorImpact::User::validateUser()](./MinorImpact_User.md#validateuserpassword))

### Parameters

- username

    The username of the user to validate.

- password

    The password of the user to validate.

## www(\\%params)

Sets up the WWW/CGI framework.

    $MINORIMPACT->www({ param1 => "one" });

### Parameters

- actions

    A hash defining which subs get called for a particular 'a=' parameter.

        # use test() when http://example.com/cgi-bin/index.cgi?a=test
        $MINORIMPACT->www({ actions => { test => \&test } });

        sub test() {
          print "Content-type: text/html\n\n";
          print "Test\n";
        }

# SUBROUTINES

## cgi()

Returns the global cgi object.

    my $CGI = MinorImpact::cgi();

## clearSession()

Clears the current session.

    MinorImpact::clearSession();

## db()

Returns the global database object.

    $DB = MinorImpact::db();

## debug($switch)

Turn debugging on or off by setting `$switch` to true or false.

    MinorImpact::debug(1);
    MinorImpact::log("debug", "This message will get logged.");
    MinorImpact::debug(0);
    MinorImpact::log("debug", "This message will not get logged.");

## log($severity\_level, $message)

Adds a message to the application log output.  Severity levels are, in order:
"debug", "info", "notice", "warning", "err", "crit", "alert" and "emerg".

    MinorImpact::log("crit", "There has been a critical error.");

Messages with the "debug" severity are only logged if the global `debug`
switch is enabled.  See ["::debug()"](#debug).

Application-wide logging is configured in ["/etc/minorimpact.conf"](./index.md#logging).

## userID()

Return the id of the current logged in user.

    my $user_id = MinorImpact::userID();

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
