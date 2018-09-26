# perl-minorimpact

## Usage

```
use MinorImpact;

$MINORIMPACT = new MinorImpact();
```

## Installation

### RedHat/CentOS

#### ...from git

```
$ git clone https://github.com/minorimpact/perl-minorimpact.git
$ export PERL5LIB=$PERL5LIB:$PWD/perl-minorimpact
$ yum -y install epel-release
```

#### ...from prebuilt packages

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

## Configuration

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

Create /etc/minorimpact.conf, if it doesn't already exist, and add the following database connection information:
```
db:
    database = minorimpact
    db_host = localhost
    db_port = 3306
    db_user = minorimpact
    db_password = minorimpact
```	
