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

The main interface to the MinorImpact library, a personal application/object framework and utility collection.

## Documenation

### Manual Pages

- [Installation](./MinorImpact_Manual_Installation.md)
- [Configuration](./MinorImpact_Manual_Configuration.md)
- [Templates ](./MinorImpact_Manual_Templates.md)

### Sub Modules

- [CLI](./MinorImpact_CLI.md)
- [Config](./MinorImpact_Config.md)
- [Object](./MinorImpact_Object.md)
- [Object::Field](./MinorImpact_Object_Field.md)
- [Object::Search](./MinorImpact_Object_Search.md)
- [Object::Type](./MinorImpact_Object_Type.md)
- [User](./MinorImpact_User.md)
- [Util](./MinorImpact_Util.md)
- [WWW](./MinorImpact_WWW.md)

### Default Objects

- [MinorImpact::entry](./MinorImpact_entry.md)

# INSTALLATION

See [MinorImpact::Manual::Installation](./MinorImpact_Manual_Installation.md) for more detailed
installation instructions.

## Packages

### ...from git

    $ git clone https://github.com/minorimpact/perl-minorimpact.git
    $ git clone https://github.com/minorimpact/minorimpact-util.git
    $ export PERL5LIB=$PERL5LIB:$PWD/perl-minorimpact
    $ export PATH=$PATH:$PWD/minorimpact-util/bin
    $ yum -y install epel-release

### ...from prebuilt packages

Add the Minor Impact repository information to /etc/yum.repos.d/minorimpact.repo:

    [minorimpact]
      name=Minor Impact Tools/Libraries
      baseurl=https://minorimpact.com/repo
      enabled=1
      gpgcheck=1
      gpgkey=https://minorimpact.com/RPM-GPG-KEY-minorimpact

Install the package:

    $ yum -y install epel-release perl-MinorImpact minorimpact-util

## Basic Configuration

### Database

Set up a database to use, if you don't already have one.  Included are basic instructions for installing a mysql database here, just for testing purposes.

    # yum install mariadb-server
    # systemctl mariadb start
    # mysql -e 'create database minorimpact;'
    # mysql -e "CREATE USER 'minorimpact'@'localhost' IDENTIFIED BY 'minorimpact';"
    # mysql -e "CREATE USER 'minorimpact'@'%' IDENTIFIED BY 'minorimpact';"
    # mysql -e "GRANT ALL PRIVILEGES ON minorimpact.* to 'minorimpact'@'localhost';"
    # mysql -e "GRANT ALL PRIVILEGES ON minorimpact.* to 'minorimpact'@'%';"

### Settings

Create /etc/minorimpact.conf, if it doesn't already exist, and add the following database connection information:

    db:
      database = minorimpact
      db_host = localhost
      db_port = 3306
      db_user = minorimpact
      db_password = minorimpact

See [MinorImpact::Manual::Configuration](./MinorImpact_Manual_Configuration.md) for more configuration options.

### Users

Change the admin user password by running the update\_user.pl script installed from minorimpact-util.

    # /opt/minorimpact/bin/update_user.pl -u admin -p admin 
    Enter password for admin: admin
    Enter new password for admin:
                           Again:

Add a new user for yourself:

    # /opt/minorimpact/bin/add_user.pl -u admin -a yes <user>
    Enter password for admin: 
    Enter new password for <user>:
                            Again:

# METHODS

## new

- new(\\%options)

Create a new MinorImpact object.

    $MINORIMPACT = new MinorImpact({ option1 => "value1", option2 => "value2" });

### Options

- config

    A hash containing configuration items.

- config\_file

    The name of a file containing configuration options.

## cache

- cache()
- cache($name)
- cache($name, $value)
- cache($name, $value, $timeout)

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

Called with no values, cache() return the raw cache oject, either [Cache::Memcached](https://metacpan.org/pod/Cache_Memcached.md),
a memcached server is configured, or [CHI](https://metacpan.org/pod/CHI.md). (see 
[MinorImpact::Manual::Configuration](./MinorImpact_Manual_Configuration.md#settings)) for more information on cache configuration.

## facebook

- ::facebook(\[$access\_token\])
- ->facebook(\[$access\_token\])

Returns a [Net::Facebook::Oauth2](./Net_Facebook_Oauth2.md) object.

    $FB = MinorImpact::facebook();

## redirect

- ::redirect()
=item ::redirect($string)
=item ::redirect(\\%params)
=item ->redirect()
=item ->redirect($string)
=item ->redirect(\\&params)

Redirects an application to a new location; does not return.  

With no value, will redirect to the index page - this is a proper way
to handle an unexpected error or security violation.

If called with $string, will redirect directly to that value.  

Otherwise, sends \\&params to [MinorImpact::url()](./MinorImpact.md#url) and redirects
to the value returned.

    # send them to the login page.
    MinorImpact::redirect({ action => 'login' });

Must be called before any other output, obviously, since relocation is done
via `Location` http header.

### params

- url => $string

    Redirect to $string.

        # send this punk to learn something
        MinorImpact::redirect("http://google.com");

## session

- ::session($name)
- ::session($name, $value)

Get or set a value for this particular session.  For CGI applications,
the session is based on a random value set in the cookie, and expires
after 30 days unless [clearSession()](./MinorImpact.md#clearsession) is called
explicitly.  For command line users, the session is based on the IP and
username.  session() uses [cache()](./MinorImpact.md#cache) for persistence
across instances.

    # set the page color for the user
    $page_color = 'red';
    MinorImpact::session('page_color', $page_color);

    # retrieve the previously set color
    $page_color = MinorImpact::session('page_color');

## tt

- tt($page)
- tt($page, \\%vars)
- tt($page, \\%vars, \\$string)

A wrapper/shortcut function to the [Template Toolkit](https://metacpan.org/pod/Template.md) library.
Called with a single string, processes the named template and sends the output to
STDOUT.

    MinorImpact::tt('template_name');

Adda hash pointer to pass variables to the template.

    MinorImpact::tt('template_name', {foo => 'bar' });

Variables can be accessed from within templates as `[% foo %]`.

Pass a pointer as the third argument to write the output to a variable.

    MinorImpact::tt('template_name', {}, \$output );

See [MinorImpact::Manual::Templates](./MinorImpact_Manual_Templates.md) for more.

### Variables

The following variables should be available in most of the default templates.

- errors

    A list of strings to include as error messages to the user.
    See [error](#error).

        push(@errors, "Invalid login.");
        MinorImpact::tt('login', { errors => [ @errors ] });

- objects

    A list of [MinorImpact objects](./MinorImpact_Object.md) to display on a page.

        MinorImpact::tt("index", { objects => [ @objects ] });

- title

    A page title.

        MinorImpact::tt($template_name, {title => "Page Name"});

## url

- url(\\%params)

Generates a link to another part of the application.

    $url = $MINORIMPACT->url({ action => 'login'});
    # $url = "/cgi-bin/index.cgi?a=login";

If the pretty\_urls config option is set, will generate "pretty" urls.

    $url = $MINORIMPACT->url({ action => 'login'});
    # $url = "/login";

### Parameters

url() supports most of the standard application parameters, along with a few
switches that dictate the URL's format.

#### Query Parameters

- action

    The page you want to link to.

- collection\_id
- limit
- object\_id

    You can also use 'id'.

- object\_type\_id
- page
- search
- sort

#### Switches

- params

    Adds arbitrary parameters to the generated URL.

        $url = MinorImpact::url({ action => 'add', object_type_id => 4, params => { foo => 'bar' }});
        # returns /cgi-bin/index.cgi?a=add&object_type_id=4&foo=bar

- qualified

    If true, will include a fully qualified domain name.

         $url = $MINORIMPACT->url({ action => 'login', qualified => 0 });
         # returns "/login"

         $url = $MINORIMPACT->url({ action => 'login', qualified => 1 });
         # return "https://<server>/login
        

## user

- user()
- user(\\%parameters)

Returns the currently logged in user, or attempts to validate a user based on various
criteria.  This is the main mechanism by which everything in MinorImpact validates
the active user.

    $user = $MINORIMPACT->user();

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
has already been validated.

If $ENV{USER} does exist, and has a non-blank password, the user will be prompted 
to enter one.

### Parameters

- admin => true/false

    Redirect to a login page (or die) if the user is not an 'admin' user.

- force => true/false

    Redirect to a login page (or die) if a valid user is not found.
    currently undefined on the command line.

        # Don't return unless the current user is valid.
        $user = MinorImpact::user({ force => });
        

- username

    The username of the user to validate.

- password

    The password of the user to validate.

## www

- www()
- www(\\%params)

Sets up the WWW/CGI framework.

    use MinorImpact;

    $MINORIMPACT = new MinorImpact;

    $MINORIMPACT->www({ actions => { index => \&index } });

    sub index {
      print "Content-type: text/html\n\n";
      print "Hello world!\n";
    }

### Parameters

- actions

    A hash defining which subs get called for a particular 'a=' parameter.

        # use test() when calling http://example.com/cgi-bin/index.cgi?a=test
        $MINORIMPACT->www({ actions => { test => \&test } });

        sub test() {
          print "Content-type: text/html\n\n";
          print "Test\n";
        }

    See [MinorImpact::WWW](./MinorImpact_WWW.md) for a list of default actions.

- site\_config

    A hash containing a list of site settings.  Sets or overrides the values in the "site"
    of the [configuration](#configuration).

        # Turn off headers for the default templates.
        $MINORIMPACT->www({site_config => { no_search => 'true' }});

    Note that once these values are altered, they override the global configuration for the
    b<duration of the script>, so be aware if you use these values outside of subs referenced
    by www().

# SUBROUTINES

## cgi

Returns the global cgi object.

    my $CGI = MinorImpact::cgi();

## addSetting

- ::addSetting(\\%params)

Add a setting to the global [MinorImpact::settings](./MinorImpact_settings.md) object.  Takes
the same parameters as [MinorImpact::Object::Type::Field::add()](./MinorImpact_Object_Type_Field.md#add), 
aside from `object_type_id`.

    MinorImpact::addSetting({ name => 'lines_per_page', type => 'int', default_value => 20, required => 1 });

### params

- default\_value => $string

    The default value for this setting.

- name => $string

    Setting name.

- required => yes/no

    Whether or not this a required field.

- type => $string

    Setting type.

## cgi

Return the global [CGI](http://perldoc.perl.org/CGI.html.md) object.

## clearSession

Clears the current session.

    MinorImpact::clearSession();

## db

Returns the global database object.

    $DB = MinorImpact::db();

## dbConfig

- ::dbConfig()

Initial database setup.

    MinorImpact::dbConfig();

Gets run automatically every time a new MinorImpact object is
instantiated.

## debug

- debug($switch)

Turn debugging on or off by setting `$switch` to true or false.

    MinorImpact::debug(1);
    MinorImpact::log("debug", "This message will get logged.");
    MinorImpact::debug(0);
    MinorImpact::log("debug", "This message will not get logged.");

## deleteSetting

- ::deleteSetting(\\%params)

Delete a setting from the global [MinorImpact::settings](./MinorImpact_settings.md) object.
See [MinorImpact::Object::Field::delete()](./MinorImpact_Object_Field.md#delete).

    MinorImpact::deleteSetting({ name => 'lines_per_page' });

### params

- name => $string

    The setting name.

## log

- log($severity\_level, $message)

Adds a message to the application log output.  Severity levels are, in order:
"debug", "info", "notice", "warning", "err", "crit", "alert" and "emerg".

    MinorImpact::log("crit", "There has been a critical error.");

Messages with the "debug" severity are only logged if the global `debug`
switch is enabled.  See [debug()](#debug).

Application-wide logging is configured in [/etc/minorimpact.conf](./MinorImpact.md#configuration).

## userDB

Returns the global user database object.

    $USERDB = MinorImpact::userDB();

## userID

Return the id of the current logged in user.

    my $user_id = MinorImpact::userID();

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
