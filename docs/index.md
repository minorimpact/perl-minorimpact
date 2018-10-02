# Introduction

## Table of Contents

[Installation](#installation)  
[Configuration](#configuration)  
[Logging](#logging)  
[Objects](#objects)  
[WWW](#www)  
[Templates](#templates)  

# Installation

## RedHat/CentOS

### ...from git

```
$ git clone https://github.com/minorimpact/perl-minorimpact.git
$ export PERL5LIB=$PERL5LIB:$PWD/perl-minorimpact
$ yum -y install epel-release
```

### ...from prebuilt packages

Add the Minor Impact repository information to /etc/yum.repos.d/minorimpact.repo:
```
[minorimpact]
  name=Minor Impact Tools/Libraries
  baseurl=https://minorimpact.com/repo
  enabled=1
  gpgcheck=1
  gpgkey=https://minorimpact.com/RPM-GPG-KEY-minorimpact
```
Install the package:
```
$ yum -y install epel-release perl-MinorImpact
```

## Database Configuration

Set up a database to use, if you don't already have one.  Included are basic instructions for installing a mysql database here, just for testing purposes.
```
# yum install mariadb-server
# systemctl mariadb start
# mysql -e 'create database minorimpact;'
# mysql -e "CREATE USER 'minorimpact'@'localhost' IDENTIFIED BY 'minorimpact';"
# mysql -e "CREATE USER 'minorimpact'@'%' IDENTIFIED BY 'minorimpact';"
# mysql -e "GRANT ALL PRIVILEGES ON minorimpact.* to 'minorimpact'@'localhost';"
# mysql -e "GRANT ALL PRIVILEGES ON minorimpact.* to 'minorimpact'@'%';"
```

## Condiguration File

Create /etc/minorimpact.conf, if it doesn't already exist, and add the following database connection information:
```
db:
    database = minorimpact
    db_host = localhost
    db_port = 3306
    db_user = minorimpact
    db_password = minorimpact
```	
See [Configuration](#configuration) for more information.

# Configuration

## Config Files
By default, MinorImpact will look for a configration file at /etc/minorimpact.conf.  There are multiple ways to define 
the configuration file for a given application, however.  Each one of the following will be checked, in order, until a 
valid configuration is discovered.

### ... from a Hash

You can embedd configuration options directly in your application by passing a hash pointer to the "config" parameter when
you create the MinorImpact object:

    $MINORIMPACT = new MinorImpact({
                        config => { 
                            log_method => "file, 
                            log_file => "/var/log/minorimpact.conf" 
                        }
                    });
    
### ... from a File

Similarly, you can pass a the name of a file that contains the configuration settings to the using the "config_file"
when you create the MinorImpact object.

    $MINORIMPACT = new MinorImpact({config_file => "/etc/minorimpact.conf"});
    
### ... from an Environment Variable

You can also set the $MINORIMPACT_CONFIG environment variable to the filename that contains the configuration options for
application.

    export MINORIMPACT_CONFIG="/etc/minorimpact.conf"
    
### ... from a Local Configuration File

If a file called "../conf/minorimpact.conf" exists, MinorImpact will read that for configuration information.  Specifically
for running applications where the main script is in a "bin" directory, parallel to "lib" and "conf".


### ... from a Global Configuration File

If none of the other methods result in a configuration, MinorImpact will look for a file called "/etc/minorimpact.conf."

## Options

### Sections

#### Default

    application_id  String used to differentiate log entries in multiple applications
                    that might be writing to the same file or using syslog. 
                    DEFAULT: minorimpact
    log_file        Name of the file to save log entries to.  Only valid when "log_method" is 
                    set to *file*.  Logging is disabled if "log_method" is set to *file*
                    and this value not set. DEFAULT: None.
    log_method      Method of logging output from MinorImpact::log().  Valid options are *file*, 
                    *syslog* and *stderr*.  DEFAULT: *file*
    pretty_urls     Set to *true* if MinorImpact should generate links as http://example.com/action 
                    rather than http://example.com/cgi-bin/index.cgi?a=action. DEFAULT: false

#### DB

    database        Name of the database to use for storing MinorImpact application data.
    db_host         Name of the database server.
    db_password     Databse user password.
    db_port         Database connection port.
    db_user         Database user name.
    
## Example

```
application_id = minorimpact
log_method = file
log_file = /var/log/minorimpact.log

db:
    database = minorimpact
    db_host = localhost
    db_port = 3306
    db_user = minorimpact
    db_password = minorimpactpw
```	

# Logging

Application-wide logging is configured in [/etc/minorimpact.conf](configuration).

    log_method = file
    log_file = \<filename\>

Valid log methods are "file" (which requires the additional log_file entry), "stderr", or "syslog".

Usage:

    MinorImpact::log("err", "There was an error, here, for some reason.");

[Severity levels](https://en.wikipedia.org/wiki/Syslog#Severity_level)

# Objects

# WWW

```
    use MinorImpact;

    MinorImpact::www({ actions => { index => \&hello, hello=> \&hello } });

    sub hello {
        print "Content-type: text/html\n\n";
        print "Hello world\n";
    }

```


URL:  
http://\<server\>/cgi-bin/index.cgi?a=hello  
http://\<server\>/cgi-bin/hello

Output:

    Hello World

# Templates
