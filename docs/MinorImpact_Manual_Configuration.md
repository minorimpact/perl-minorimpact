# NAME

MinorImpact::Manual::Configuration

# DESCRIPTION

By default, MinorImpact will look for a configration file at /etc/minorimpact.conf.  There are multiple ways to define 
the configuration file for a given application, however.  Each one of the following will be checked, in order, until a 
valid configuration is discovered.

## Configuration Methods

### Hash

You can embedd configuration options directly in your application by passing a hash pointer to the "config" parameter when
you create the MinorImpact object:

    $MINORIMPACT = new MinorImpact({
                        config => { 
                            log_method => "file, 
                            log_file => "/var/log/minorimpact.conf" 
                        }
                    });
    

### Configuration File

Similarly, you can pass a the name of a file that contains the configuration settings to the using the "config\_file"
when you create the MinorImpact object.

    $MINORIMPACT = new MinorImpact({config_file => "/etc/minorimpact.conf"});
    

### Environment Variable

You can also set the $MINORIMPACT\_CONFIG environment variable to the filename that contains the configuration options for
application.

    export MINORIMPACT_CONFIG="/etc/minorimpact.conf"
    

### Local File

If a file called "../conf/minorimpact.conf" exists, MinorImpact will read that for configuration information.  Specifically
for running applications where the main script is in a "bin" directory, parallel to "lib" and "conf".

### Global Configuration File

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

- default\_object\_type

    The package name of the object type that sits at the heart of your application, 
    if one exists.  The id of this object type is what will get returned by 
    [MinorImpact::Object::getTypeID()](./MinorImpact_Object.md#gettypeid), which is used
    extensively within MinorImpact to fill out random lists and miscellaneous
    pages.
    DEFAULT: none

- log\_file

    Name of the file to save log entries to.  Only valid when "log\_method" is 
    set to \*file\*.  Logging is disabled if "log\_method" is set to \*file\*
    and this value not set. 
    DEFAULT: None.

- log\_method

    Method of logging output from [MinorImpact::log()](#log).  Valid options are \*file\*, 
    \*syslog\* and \*stderr\*.
    DEFAULT: \*file\*

- memcached\_server

    Set this to the name of your memcached server to enable memcached caching.  If this is not
    set, MinorImpact will use the "/tmp/cache" directory.

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

- about = $string

    If set, $string will appear on the default [about](./MinorImpact_Manual_Template.md#about)
    page.

- copyright

    Text to include at the bottom of every page.  YEAR is automatically translated to the current
    year.  For example:

        copyright = "&copy;YEAR Minor Impact"

    NAME is automatically replaced with the 'name' configuration option from this same section.

- email = $string

    If set, $string will appear on the default [about](./MinorImpact_Manual_Template.md#about) page as a `mailto` tag.

- header\_color

    Header bar color.  Supports the default HTML color names: [https://www.w3schools.com/colors/colors\_names.asp](https://www.w3schools.com/colors/colors_names.asp.md).

- name = $string

    The name of the site. $string will appear as a link in the 
    deafult [header](./MinorImpact_Manual_Template.md#header), as a well as 
    on the default [about](./MinorImpact_Manual_Template.md#about) page.

- no\_login\_links

    If 'true', disables login links in the default header.  This doesn't disable 
    logins on the site, it just removes the links.  Setting this value also sets
    `no_register_links`.

- no\_register\_links

    If 'true', disables user registration links on the default header.  This doesn't disable registrations, it just removes the links.

- no\_search

    If true, do not display the search bar in the default header.

- no\_tags

    True or false - controls whether or not a 'Tags' link appears on the sidebar.

## Example

    application_id = minorimpact
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
      copyright = "&copy;YEAR NAME"
      name = "Minor Impact"
      no_search = true

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
