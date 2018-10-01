# Configuration

## Config Files
By default, MinorImpact will look for a configration file at /etc/minorimpact.conf.  There are multiple ways to define 
the configuration file for a given application, however.  Each one of the following will be checked, in order, until a 
valid configuration is discovered.

### ... from a Hash

You can embedd configuration options directly in your application by passing a hash pointer to the "config" parameter when
you create the MinorImpact object:

    $MINORIMPACT = new MinorImpact({config => { log_method => "file, log_file => "/var/log/minorimpact.conf" }});
    
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

## Format
```
db:
    database = \<database name\>
    db_host = \<database server\>
    db_port = \<database port\>
    db_user = \<database user\>
    db_password = \<database user password\>
```	
