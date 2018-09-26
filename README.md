# perl-minorimpact

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
