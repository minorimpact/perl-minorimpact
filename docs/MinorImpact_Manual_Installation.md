# NAME

MinorImpact::Manual::Installation

# DESCRIPTION

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

See [MinorImpact::Manual::Configuration](./MinorImpact_Manual_Configuration.md) for more configuration options.

### Users

Change the admin user password by running the update\_user.pl script installed from minorimpact-util.

    # /usr/loca/bin/update_user.pl -u admin -p admin
    Enter Password for admin: admin
    Enter New Password for admin:
           again:

Add a new user for yourself:

    # /usr/loca/bin/add_user.pl -u admin -a yes <user>
    Enter Password for admin:
    Enter New Password for <user>:
           again:

By default, MinorImpact will create a passwordless user in the database for any local
user running a MinorImpact script, based on the value on the $USER environment varable.
You can set a password for one of these users by running:

    # /usr/local/bin/update_user.pl -u admin -p <user>

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
