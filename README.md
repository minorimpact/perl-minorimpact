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

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
