# NAME

MinorImpact::Config

# DESCRIPTION

Subs for reading and writing configuration files.

# METHODS

## new

returns a new MinorImpact::Config object.

    $CONFIG = new MinorImpact::Config({ config_file=>"/etc/minorimpact.conf"});

# SUBS

## decode

- decode($string)
- decode(\\$string)

Returns a version of `$string` with special encoded/escaped converted
back to their unencoded values.  If `$string` is a reference, the data
will be modified directly.

    $decoded_string = MinorImpact::Config::decode("This is a colon_COLON_ _COLON_");
    # $decoded_string = "This is a colon: :" 

## readConfig

- readConfig($config\_file)

Reads configuration information from a given file and returns a hash containing
data.

    # cat /etc/minorimpact.conf
    # 
    # application_id = "minorimpact"
    #
    # [db]
    #   db_host = "localhost"

    $config = MinorImpact::Config::readConfig("/etc/minorimpact.conf");
    
    # $config = { 
    #   default => { 
    #     application_id => "minorimpact"
    #   },
    #   db => {
    #     db_host => "localhost"
    #   }
    # }

## writeConfig

- writeConfig($config\_file, \\%config)

Writes configuration data to a given file.

    MinorImpact::Config::writeConfig("/etc/minorimpact.conf", { 
      default => { 
        application_id => "minorimpact"
      },
      db => {
        db_host => "localhost"
      }
    });
    # cat /etc/minorimpact.conf
    # 
    # application_id = "minorimpact"
    #
    # [db]
    #   db_host = "localhost"

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
