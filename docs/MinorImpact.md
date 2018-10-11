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

# INSTALLATION

## Examples

### RedHat/CentOS

#### ...from git

$ git clone https://github.com/minorimpact/perl-minorimpact.git
$ export PERL5LIB=$PERL5LIB:$PWD/perl-minorimpact
$ yum -y install epel-release

#### ...from prebuilt packages

Add the Minor Impact repository information to /etc/yum.repos.d/minorimpact.repo:

    [minorimpact]
      name=Minor Impact Tools/Libraries
      baseurl=https://minorimpact.com/repo
      enabled=1
      gpgcheck=1
      gpgkey=https://minorimpact.com/RPM-GPG-KEY-minorimpact

Install the package:

    $ yum -y install epel-release perl-MinorImpact

### Database Configuration

Set up a database to use, if you don't already have one.  Included are basic instructions for installing a mysql database here, just for testing purposes.

    # yum install mariadb-server
    # systemctl mariadb start
    # mysql -e 'create database minorimpact;'
    # mysql -e "CREATE USER 'minorimpact'@'localhost' IDENTIFIED BY 'minorimpact';"
    # mysql -e "CREATE USER 'minorimpact'@'%' IDENTIFIED BY 'minorimpact';"
    # mysql -e "GRANT ALL PRIVILEGES ON minorimpact.* to 'minorimpact'@'localhost';"
    # mysql -e "GRANT ALL PRIVILEGES ON minorimpact.* to 'minorimpact'@'%';"

### Configuration File

Create /etc/minorimpact.conf, if it doesn't already exist, and add the following database connection information:

    db:
      database = minorimpact
      db_host = localhost
      db_port = 3306
      db_user = minorimpact
      db_password = minorimpact

See \[Configuration\](#configuration) for more information.

# CONFIGURATION

By default, MinorImpact will look for a configration file at /etc/minorimpact.conf.  There are multiple ways to define 
the configuration file for a given application, however.  Each one of the following will be checked, in order, until a 
valid configuration is discovered.

## Setting Configuration Options...

### ...from a Hash

You can embedd configuration options directly in your application by passing a hash pointer to the "config" parameter when
you create the MinorImpact object:

    $MINORIMPACT = new MinorImpact({
                        config => { 
                            log_method => "file, 
                            log_file => "/var/log/minorimpact.conf" 
                        }
                    });
    

### ...from a File

Similarly, you can pass a the name of a file that contains the configuration settings to the using the "config\_file"
when you create the MinorImpact object.

    $MINORIMPACT = new MinorImpact({config_file => "/etc/minorimpact.conf"});
    

### ...from an Environment Variable

You can also set the $MINORIMPACT\_CONFIG environment variable to the filename that contains the configuration options for
application.

    export MINORIMPACT_CONFIG="/etc/minorimpact.conf"
    

### ...from a Local Configuration File

If a file called "../conf/minorimpact.conf" exists, MinorImpact will read that for configuration information.  Specifically
for running applications where the main script is in a "bin" directory, parallel to "lib" and "conf".

### ...from a Global Configuration File

If none of the other methods result in a configuration, MinorImpact will look for a file called "/etc/minorimpact.conf."

## Settings

### Sections

Configuration options are grouped into multiple sections, the global, or "default" section, the
"db" section, which contains database configuration parameters, and "user\_db", which is
identical to the "db", but defines the connection properties for connecting to a separate
database for user authentication.  This is only useful for having multiple MinorImpact applications
that need to share a common userbase. Other sections are listed below.

#### default

- application\_id

    String used to differentiate log entries in multiple applications
    that might be writing to the same file or using syslog. 
    DEFAULT: minorimpact

- copyright

    Text to include at the bottom of every page.  YEAR is automatically translated to the current
    year.  For example:

        copyright = "&copy;YEAR Minor Impact"

- log\_file

    Name of the file to save log entries to.  Only valid when "log\_method" is 
    set to \*file\*.  Logging is disabled if "log\_method" is set to \*file\*
    and this value not set. DEFAULT: None.

- log\_method

    Method of logging output from [MinorImpact::log()](#log).  Valid options are \*file\*, 
    \*syslog\* and \*stderr\*.  DEFAULT: \*file\*

- pretty\_urls

    Set to \*true\* if MinorImpact should generate links as http://example.com/action 
    rather than http://example.com/cgi-bin/index.cgi?a=action. DEFAULT: false

- template\_directory

    Directory that contains template files for this application.  Can be also be set (or
    overridden) by the value of $MINORIMPACT\_TEMPLATE environment variable.

#### db/user\_db

- database

    Name of the database to use for storing MinorImpact application data.

- db\_host

    Name of the database server.

- db\_password

    Databse user password.

- db\_port

    Database connection port.

- db\_user

    Database user name.

#### site

WWW specific application settings.

- no\_search

    If true, do not display the search bar in the default header.

## Example

    application_id = minorimpact
    copyright = "&copy;YEAR Minor Impact"
    log_method = file
    log_file = /var/log/minorimpact.log

    [db]
      database = minorimpact
      db_host = localhost
      db_port = 3306
      db_user = minorimpact
      db_password = minorimpactpw

    [user_db]
      database = minorimpact_user
      db_host = remote
      db_port = 3306
      db_user = minorimpact
      db_password = minorimpactpw

    [site]
      no_search = true

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

## tt

- tt($page)
- tt($page, \\%vars)

A wrapper/shortcut function to the [Template Toolkit](https://metacpan.org/pod/Template.md) library.

    MinorImpact::tt('template_name');

See [MinorImpact::Manual::Templates](./MinorImpact_Manual_Templates.md).

### Variables

The following variables should work when calling most of the default templates.

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
forcing the user to add a password. (see [MinorImpact::User::validateUser()](./MinorImpact_User.md#validateuser))

### Parameters

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

# SUBROUTINES

## cgi

Returns the global cgi object.

    my $CGI = MinorImpact::cgi();

## clearSession

Clears the current session.

    MinorImpact::clearSession();

## db

Returns the global database object.

    $DB = MinorImpact::db();

## debug

- debug($switch)

Turn debugging on or off by setting `$switch` to true or false.

    MinorImpact::debug(1);
    MinorImpact::log("debug", "This message will get logged.");
    MinorImpact::debug(0);
    MinorImpact::log("debug", "This message will not get logged.");

## log

- log($severity\_level, $message)

Adds a message to the application log output.  Severity levels are, in order:
"debug", "info", "notice", "warning", "err", "crit", "alert" and "emerg".

    MinorImpact::log("crit", "There has been a critical error.");

Messages with the "debug" severity are only logged if the global `debug`
switch is enabled.  See [debug()](#debug).

Application-wide logging is configured in [/etc/minorimpact.conf](./MinorImpact.md#configuration).

## userID

Return the id of the current logged in user.

    my $user_id = MinorImpact::userID();

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>

# POD ERRORS

Hey! **The above document had some coding errors, which are explained below:**

- Around line 240:

    You forgot a '=back' before '=head2'
