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

# INSTALLATION

See [MinorImpact::Manual::Installation](./MinorImpact_Manual_Installation.md) for more detailed
installation instructions.

## Packages

### ...from git

    $ git clone https://github.com/minorimpact/perl-minorimpact.git
    $ export PERL5LIB=$PERL5LIB:$PWD/perl-minorimpact
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

    $ yum -y install epel-release perl-MinorImpact

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

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
