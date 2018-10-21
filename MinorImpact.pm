package MinorImpact;

use strict;

use Cache::Memcached;
use CGI;
use CHI;
use Cwd;
use Data::Dumper;
use DBI;
use Digest::MD5 qw(md5 md5_hex);
use File::Spec;
use JSON;
use MinorImpact::CLI;
use MinorImpact::Config;
use MinorImpact::Object;
use MinorImpact::User;
use MinorImpact::Util;
use MinorImpact::WWW;
use Sys::Syslog;
use Template;
use Time::HiRes qw(tv_interval gettimeofday);
use Time::Local;
use URI::Escape;


our $SELF;

=head1 NAME

MinorImpact - Application/object framework and utility library.

=head1 SYNOPSIS

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

=head1 DESCRIPTION

The main interface to the MinorImpact library, a personal application/object framework and utility collection.

=head2 Documenation

=head3 Manual Pages

=over

=item L<Installation|MinorImpact::Manual::Installation>

=item L<Configuration|MinorImpact::Manual::Configuration>

=item L<Templates |MinorImpact::Manual::Templates>

=back

=head3 Sub Modules

=over

=item L<CLI|MinorImpact::CLI>

=item L<Config|MinorImpact::Config>

=item L<Object|MinorImpact::Object>

=item L<Object::Field|MinorImpact::Object::Field>

=item L<Object::Search|MinorImpact::Object::Search>

=item L<Object::Type|MinorImpact::Object::Type>

=item L<User|MinorImpact::User>

=item L<Util|MinorImpact::Util>

=item L<WWW|MinorImpact::WWW>

=back

=head3 Default Objects

=over

=item L<MinorImpact::entry|MinorImpact::entry>

=back

=head1 INSTALLATION

See L<MinorImpact::Manual::Installation|MinorImpact::Manual::Installation> for more detailed
installation instructions.

=head2 Packages

=head3 ...from git

  $ git clone https://github.com/minorimpact/perl-minorimpact.git
  $ git clone https://github.com/minorimpact/minorimpact-util.git
  $ export PERL5LIB=$PERL5LIB:$PWD/perl-minorimpact
  $ export PATH=$PATH:$PWD/minorimpact-util/bin
  $ yum -y install epel-release

=head3 ...from prebuilt packages

Add the Minor Impact repository information to /etc/yum.repos.d/minorimpact.repo:

  [minorimpact]
    name=Minor Impact Tools/Libraries
    baseurl=https://minorimpact.com/repo
    enabled=1
    gpgcheck=1
    gpgkey=https://minorimpact.com/RPM-GPG-KEY-minorimpact

Install the package:

  $ yum -y install epel-release perl-MinorImpact minorimpact-util

=head2 Basic Configuration

=head3 Database

Set up a database to use, if you don't already have one.  Included are basic instructions for installing a mysql database here, just for testing purposes.

  # yum install mariadb-server
  # systemctl mariadb start
  # mysql -e 'create database minorimpact;'
  # mysql -e "CREATE USER 'minorimpact'@'localhost' IDENTIFIED BY 'minorimpact';"
  # mysql -e "CREATE USER 'minorimpact'@'%' IDENTIFIED BY 'minorimpact';"
  # mysql -e "GRANT ALL PRIVILEGES ON minorimpact.* to 'minorimpact'@'localhost';"
  # mysql -e "GRANT ALL PRIVILEGES ON minorimpact.* to 'minorimpact'@'%';"

=head3 Settings

Create /etc/minorimpact.conf, if it doesn't already exist, and add the following database connection information:

  db:
    database = minorimpact
    db_host = localhost
    db_port = 3306
    db_user = minorimpact
    db_password = minorimpact

See L<MinorImpact::Manual::Configuration|MinorImpact::Manual::Configuration> for more configuration options.

=head3 Users

Change the admin user password by running the update_user.pl script installed from minorimpact-util.

  # /opt/minorimpact/bin/update_user.pl -u admin -p admin 
  Enter password for admin: admin
  Enter new password for admin:
                         Again:

Add a new user for yourself:

  # /opt/minorimpact/bin/add_user.pl -u admin -a yes <user>
  Enter password for admin: 
  Enter new password for <user>:
                          Again:

=head1 METHODS

=head2 new

=over

=item new(\%options)

=back

Create a new MinorImpact object.

  $MINORIMPACT = new MinorImpact({ option1 => "value1", option2 => "value2" });

=head3 Options

=over

=item config

A hash containing configuration items.

=item config_file

The name of a file containing configuration options.

=back

=cut

sub new {
    my $package = shift;
    my $options = shift || {};

    my $self = $SELF;
    MinorImpact::log('debug', "starting");

    unless ($self) {
        MinorImpact::log('notice', "creating new MinorImpact object") unless ($options->{no_log});

        my $config;
        if ($options->{config} && ref($options->{config}) eq 'HASH') {
            # TODO: Make this into a "merge," so that the user can chose to override a subset
            #   of values from the config file, rather than having to include an entire
            #   configuration.
            $config = $options->{config};
        } elsif ($options->{config_file}) {
            $config = readConfig($options->{config_file});
        } elsif (defined($ENV{MINORIMPACT_CONFIG}) && -f $ENV{MINORIMPACT_CONFIG}) {
            $config = readConfig($ENV{MINORIMPACT_CONFIG});
        } elsif (-f "../conf/minorimpact.conf") {
            $config = readConfig("../conf/minorimpact.conf");
        } elsif (-f "/etc/minorimpact.conf") {
            $config = readConfig("/etc/minorimpact.conf");
        }

        if (!$config) {
            die "No configuration";
        }
        $self = {};
        bless($self, $package);
        $SELF = $self;

        my $config_db_database = $config->{db}->{database} || '';
        my $config_db_db_host = $config->{db}->{db_host} || '';
        my $config_db_port = $config->{db}->{port} || '';
        my $dsn = "DBI:mysql:database=$config_db_database;host=$config_db_db_host;port=$config_db_port}";
        $self->{DB} = DBI->connect($dsn, $config->{db}->{db_user}, $config->{db}->{db_password}, {RaiseError=>1, mysql_auto_reconnect=>1}) || die("Can't connect to database");

        if ($config->{user_db}) {
            my $dsn = "DBI:mysql:database=$config->{user_db}->{database};host=$config->{user_db}->{db_host};port=$config->{user_db}->{port}";
            $self->{USERDB} = DBI->connect($dsn, $config->{user_db}->{db_user}, $config->{user_db}->{db_password}, {RaiseError=>1, mysql_auto_reconnect=>1}) || die("Can't connect to database");
        } else {
            $self->{USERDB} = $self->{DB};
        }
        $self->{CGI} = new CGI;
        $self->{conf} = $config;
        $self->{conf}{application} = $options;
        $self->{conf}{default}{application_id} ||= 'minorimpact';
        $self->{conf}{default}{home_script} ||= "index.cgi";
        $self->{conf}{default}{no_log} = 1 if ($options->{no_log});
        $self->{conf}{default}{log_method} ||= 'syslog';

        $self->{conf}{site}{header_color} ||= 'blue';

        $self->{starttime} = [gettimeofday];

        if ($self->{conf}{default}{log_method} eq 'syslog') {
            openlog($self->{conf}{default}{application_id}, 'nofatal,pid', 'local4');
        }

        dbConfig($self->{DB});
    }

    if ($self->{CGI}->param("a") ne 'login' && ($options->{valid_user} || $options->{user_id} || $options->{admin})) {
        my ($script_name) = scriptName();
        my $user = $self->user();
        if ($user) {
            if ($options->{user_id} && $user->id() != $options->{user_id}) {
                MinorImpact::log('notice', "logged in user doesn't match");
                $self->redirect({ action => 'login' });
            } elsif ($options->{admin} && !$user->isAdmin()) {
                MinorImpact::log('notice', "not an admin user");
                $self->redirect({ action => 'login' });
            }
        } else {
            MinorImpact::log('notice', "no logged in user");
            $self->redirect({ action => 'login' });
        }
    }
    if ($options->{https} && ($ENV{HTTPS} ne 'on' && !$ENV{HTTP_X_FORWARDED_FOR})) {
        MinorImpact::log('notice', "not https");
        $self->redirect();
    }

    MinorImpact::log('debug', "ending");
    return $self;
}

=head2 cache

=over

=item cache()

=item cache($name)

=item cache($name, $value)

=item cache($name, $value, $timeout)

=back

Store, retrieve or delete name/value pairs from the global cache.  If value is not specified,
the previous value for $name is returned.  $timeout is in seconds, and the default value is
3600.  Pass an empty hash pointer to clear the previous value.

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

Called with no values, cache() return the raw cache oject, either L<Cache::Memcached|https://metacpan.org/pod/Cache::Memcached>,
a memcached server is configured, or L<CHI|https://metacpan.org/pod/CHI>. (see 
L<MinorImpact::Manual::Configuration|MinorImpact::Manual::Configuration/Settings>) for more information on cache configuration.
=cut

sub cache {
    my $self = shift || return;

    MinorImpact::log('debug', "starting");

    if (!ref($self)) {
        unshift(@_, $self);
        $self = $MinorImpact::SELF;
    }

    my $cache;
    if ($self->{CACHE}) {
        $cache = $self->{CACHE};
    } else {
        if ($self->{conf}{default}{memcached_server}) {
            $cache = new Cache::Memcached({ servers => [ $self->{conf}{default}{memcached_server} . ":11211" ] });
        } else {
            $cache = new CHI( driver => "File", root_dir => "/tmp/cache/" );
        }
        die "Can't create cache\n" unless ($cache);
        $self->{CACHE} = $cache;
    }

    my $name = shift || return;
    my $value = shift;
    my $timeout = shift || 3600;

    $name = $self->{conf}{default}{application_id} . "_$name" if ($self->{conf}{default}{application_id});
    if (ref($value) eq 'HASH' && scalar(keys(%$value)) == 0) {
        #MinorImpact::log('debug', "removing '$name'");
        return $cache->remove($name);
    }
    if (!defined($value)) {
        $value = $cache->get($name);
        #MinorImpact::log('debug', "$name='" . $value . "'");
        return $value;
    }

    MinorImpact::log('debug', "setting $name='" . $value . "' ($timeout)");
    $cache->set($name, $value, $timeout);

    MinorImpact::log('debug', "ending");
    return $cache;
}

sub param {
    my $self = shift || return;
    my $param = shift;

    unless (ref($self) eq 'MinorImpact') {
        $param = $self;
        $self = $SELF;
    }
    my $CGI = $self->cgi();
    return $CGI->param($param);
}

sub redirect {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log('debug', "starting");

    if (ref($self) eq 'HASH') {
        $params = $self;
        undef($self);
    } elsif (!ref($self)) {
        $params->{redirect} = $self;
        undef($self);
    }

    if (ref($params) ne 'HASH') {
        my $redirect = $params;
        $params = {};
        $params->{url} = $redirect;
    }

    my $url = (defined($params->{url}) && $params->{url})?$params->{url}:MinorImpact::url($params);
    MinorImpact::log('info', "redirecting to $url");
    print "Location:$url\n\n";
    #MinorImpact::log('debug', "ending");
    exit;
}

sub scriptName {
    my ($script_name) = $0 =~/\/([^\/]+.cgi)$/;
    return $script_name;
}

sub session {
    my $name = shift;
    my $value = shift;

    my $MI = new MinorImpact();
    my $CGI = MinorImpact::cgi();

    my $timeout = $MI->{conf}{default}{user_timeout} || 2592000;
    my $session_id = MinorImpact::sessionID() || die "cannot get session ID";

    my $session = MinorImpact::cache("session:$session_id") || {};

    unless ($name) {
        return $session;
    }

    if ($name && !defined($value)) {
        return $session->{$name};
    }

    if ($name && defined($value)) {
        if (ref($value) eq 'HASH' && scalar(keys %$value) == 0) {
            delete($session->{$name});
        } else {
            $session->{$name} = $value;
        }
    }

    return MinorImpact::cache("session:$session_id", $session, $timeout);
}

sub sessionID {
    my $session_id;
    if ($ENV{REMOTE_ADDR}) {
        my $CGI = MinorImpact::cgi();
        $session_id = $CGI->cookie("session_id");
        unless ($session_id) {
            my $MI = new MinorImpact();
            my $timeout = $MI->{conf}{default}{user_timeout} || 2592000;
            $session_id = int(rand(10000000)) . "_" . int(rand(1000000));
            my $cookie =  $CGI->cookie(-name=>'session_id', -value=>$session_id, -expires=>"+${timeout}s");
            print "Set-Cookie: $cookie\n";
        }
    } else {
        $session_id = $ENV{SSH_CLIENT} . "-" . $ENV{USER};
    }
    
    return $session_id;
}

=head2 tt

=over

=item tt($page)

=item tt($page, \%vars)

=item tt($page, \%vars, \$string)

=back

A wrapper/shortcut function to the L<Template Toolkit|https://metacpan.org/pod/Template> library.
Called with a single string, processes the named template and sends the output to
STDOUT.

  MinorImpact::tt('template_name');

Adda hash pointer to pass variables to the template.

  MinorImpact::tt('template_name', {foo => 'bar' });

Variables can be accessed from within templates as C<[% foo %]>.

Pass a pointer as the third argument to write the output to a variable.

  MinorImpact::tt('template_name', {}, \$output );

See L<MinorImpact::Manual::Templates|MinorImpact::Manual::Templates> for more.

=head3 Variables

The following variables should be available in most of the default templates.

=over

=item errors

A list of strings to include as error messages to the user.
See L<error|/error>.

  push(@errors, "Invalid login.");
  MinorImpact::tt('login', { errors => [ @errors ] });

=item objects

A list of L<MinorImpact objects|MinorImpact::Object> to display on a page.

  MinorImpact::tt("index", { objects => [ @objects ] });

=item title

A page title.

  MinorImpact::tt($template_name, {title => "Page Name"});

=back

=cut

sub tt {
    my $self = shift || return; 


    if (!ref($self)) {
        unshift(@_, $self);
        $self = new MinorImpact();
    }

    MinorImpact::log('debug', "starting(" . $_[0] . ")");

    my $TT;
    if ($self->{TT}) {
        $TT = $self->{TT};
    } else {
        my $CGI = cgi();
        my $collection_id = MinorImpact::session('collection_id');
        # TODO: Remove reference to the default section once the config changes go through.
        my $copyright = $self->{conf}{site}{copyright} || $self->{default}{conf}{copyright} || '';
        if ($copyright =~/YEAR/) {
            my $year = ((localtime(time))[5] + 1900);
            $copyright =~s/YEAR/$year/;
        }
        if ($copyright =~/NAME/ && $self->{conf}{site}{name}) {
            $copyright =~s/NAME/$self->{conf}{site}{name}/;
        }
        my $limit = $CGI->param('limit') || 30;
        my $limit = $CGI->param('limit') || 30;
        my $page = $CGI->param('page') || 1;
        my $search = MinorImpact::session('search');
        my $sort = MinorImpact::session('sort');
        my $tab_id = MinorImpact::session('tab_id');
        my $user = MinorImpact::user();

        my $template_directory = $ENV{MINORIMPACT_TEMPLATE} || $self->{conf}{default}{template_directory};
        #my @collections = ();
        #if ($user) {
        #    @collections = $user->getCollections();
        #}

        # The default package templates are in the 'template' directory 
        # in the libary.  Find it, and use it as the secondary template location.
        (my $package = __PACKAGE__ ) =~ s#::#/#g;
        my $filename = $package . '.pm';

        MinorImpact::log('debug', "\$INC{$filename}='" . $INC{$filename} . "'");
        (my $path = $INC{$filename}) =~ s#/\Q$filename\E$##g; # strip / and filename
        MinorImpact::log('debug', "\$path='$path'");
        my $global_template_directory = File::Spec->catfile($path, "$package/template");

        my $variables = {
            cid         => $collection_id,
            #collections => [ @collections ],
            copyright   => $copyright,
            ENV         => \%ENV,
            home        => $self->{conf}{default}{home_script},
            limit       => $limit,
            page        => $page,
            script_name => MinorImpact::scriptName(),
            #search      => $search,
            site_config => $self->{conf}{site},
            sort        => $sort,
            typeName    => sub { MinorImpact::Object::typeName(shift); },
            url         => sub { MinorImpact::url(shift); },
            user        => $user,
        };

        MinorImpact::log("debug", "INCLUDE_PATH: [ $template_directory, $global_template_directory ]");
        $TT = Template->new({
            INCLUDE_PATH => [ $template_directory, $global_template_directory ],
            INTERPOLATE => 1,
            VARIABLES => $variables,
        }) || die $TT->error();

        $self->{TT} = $TT;
    }
    $TT->process(@_) || die $TT->error();
    MinorImpact::log('debug', "ending");
}

=head2 url

=over

=item url(\%params)

=back

Generates a link to another part of the application.

  $url = $MINORIMPACT->url({ action => 'login'});
  # $url = "/cgi-bin/index.cgi?a=login";

If the pretty_urls config option is set, will generate "pretty" urls.

  $url = $MINORIMPACT->url({ action => 'login'});
  # $url = "/login";

=head3 Parameters

url() supports most of the standard application parameters, along with a few
switches that dictate the URL's format.

=head4 Query Parameters

=over

=item action

The page you want to link to.

=item collection_id

=item limit

=item object_id

You can also use 'id'.

=item object_type_id

=item page

=item search

=item sort

=back

=head4 Switches

=over

=item params

Adds arbitrary parameters to the generated URL.

  $url = MinorImpact::url({ action => 'add', object_type_id => 4, params => { foo => 'bar' }});
  # returns /cgi-bin/index.cgi?a=add&object_type_id=4&foo=bar

=item qualified

If true, will include a fully qualified domain name.

  $url = $MINORIMPACT->url({ action => 'login', qualified => 0 });
  # returns "/login"

  $url = $MINORIMPACT->url({ action => 'login', qualified => 1 });
  # return "https://<server>/login
 
=back

=cut

sub url {
    my $self = shift || return;
    my $params = shift || {};

    MinorImpact::log('debug', "starting");

    if (ref($self) eq 'HASH') {
        $params = $self;
        undef($self);
    } elsif (!ref($self)) {
        $params->{redirect} = $self;
        undef($self);
    }

    $self = new MinorImpact() unless ($self);

    my $CGI = MinorImpact::cgi();
    my $user = MinorImpact::user();

    my $action = $params->{action} || ($user?'home':'index');
    my $collection_id = $params->{collection_id} if (defined($params->{collection_id}));
    my $limit = $params->{limit};
    my $object_id = $params->{object_id} || $params->{id};
    my $object_type_id = $params->{object_type_id};
    my $page = $params->{page};
    my $search = $params->{search} if ($params->{search});
    my $sort = $params->{sort} if ($params->{sort});
    my $tab_id = $params->{tab_id} if ($params->{tab_id});

    my $pretty = isTrue($self->{conf}{default}{pretty_urls});
    my $qualified = isTrue($params->{qualified});

    my $url;
    my $domain = "https://$ENV{HTTP_HOST}";
    $url = $domain if ($qualified);

    # This is unintuitive, but in the cases where the action sub has a particular "main"
    #   parameter, it will accept it as "id", and it will work with the default pretty
    #   url format /<action>/<id>.
    if ($action eq 'add' && $object_type_id) {
        $object_id = $object_type_id;
        undef($object_type_id);
    } elsif (($action eq 'delete_search' || $action eq 'search') && $collection_id) {
        $object_id = $collection_id;
        undef($collection_id);
    }
    if ($pretty) {
        $url .= "/$action";
        if ($object_id) {
            $url .= "/$object_id" 
        } 
        $url .= "?";
    } else {
        my $script_name = MinorImpact::scriptName();
        $url .= "/cgi-bin/$script_name?a=$action";
        $url .= "&id=$object_id" if ($object_id); 
    }
    $url .= "&cid=$collection_id" if ($collection_id);
    $url .= "&page=$page" if ($page);
    $url .= "&limit=$limit" if ($limit);
    $url .= "&search=$search" if ($search);
    $url .= "&sort=$sort" if ($sort);
    $url .= "&tab_id=$tab_id" if ($tab_id);
    $url .= "&type_id=$object_type_id" if ($object_type_id);

    foreach my $key (keys %{$params->{params}}) {
        $url .= "&$key=" . $params->{params}{$key};
    }

    # Remove any extraneous characters.
    $url =~s/[\?\/]$//;
    MinorImpact::log('debug', "\$url='$url'");
    MinorImpact::log('debug', "ending");
    return $url;
}

=head2 user

=over

=item user()

=item user(\%parameters)

=back

Returns the currently logged in user, or attempts to validate a user based on various
criteria.  This is the main mechanism by which everything in MinorImpact validates
the active user.

  $user = $MINORIMPACT->user();

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
has already been validated.

If $ENV{USER} does exist, and has a non-blank password, the user will be prompted 
to enter one.

=head3 Parameters

=over

=item force

Redirect to a login page if a valid user is not found in a CGI context.  Results are 
currently undefined on the command line.

  # Don't return unless the current user is valid.
  $user = MinorImpact::user({ force => });
  
=item username

The username of the user to validate.

=item password

The password of the user to validate.

=back

=cut

sub user {
    my $self = shift || {};
    my $params = shift || {};

    #MinorImpact::log('debug', "starting");

    if (ref($self) eq 'HASH') {
        $params = $self;
        undef($self);
    }
    if (!$self) {
        $self = new MinorImpact();
    }

    my $CGI = MinorImpact::cgi();
    my $username = $params->{username} || $CGI->param('username') || $ENV{USER} || '';
    my $password = $params->{password} || $CGI->param('password') || '';
    my $user_hash = md5_hex("$username:$password");

    # Check the number of login failures for this IP
    my $IP = $ENV{HTTP_X_FORWARDED_FOR} || $ENV{SERVER_ADDR} || $ENV{SSH_CONNECTION} || 'X';
    my $login_failures = MinorImpact::cache("login_failures_$IP") || 0;
    # Fail silently, so an attacker doesn't know they're not actually validating against anything.
    if ($login_failures >= 5) {
        MinorImpact::log('notice', "Excessive login failures from '$IP'");
        return;
    }

    if ($username) {
        # ... or number of failures for this username.
        $login_failures = MinorImpact::cache("login_failures_$username") || 0;
        if ($login_failures >= 5) {
            MinorImpact::log('notice', "Excessive login failures for '$username'");
            return;
        }
    }

    # If this is the first page, the cookie hasn't been set, so if there are a ton of items
    #   we'd have to validate against the database over and over again... so just validate against
    #   a stored hash and return the cached user.  Once USERHASH is set, we know we've already 
    #   checked this username/passsword combination, and if USER is set we already know it succeeded.
    if ($self->{USER} && $self->{USER}->name() eq $username && $self->{USERHASH} && $user_hash eq $self->{USERHASH}) {
        return $self->{USER};
    }

    # If the username and password are provided, then validate the user.
    if ($username && $password && !$self->{USERHASH}) {
        MinorImpact::log('debug', "validating " . $username);

        $self->{USERHASH} = $user_hash;
        my $user = new MinorImpact::User($username);
        if ($user && $user->validateUser($password)) {
            MinorImpact::log('debug', "password verified for $username");
            $self->{USER} = $user;
            MinorImpact::session('user_id', $user->id());
            return $user;
        } elsif ($user) {
            MinorImpact::log('debug', "unable to verify password for $username");
        }

        # We keep the login failure count for 7 minutes, which should be long enough to make
        #   a brute force attempt fail.
        $login_failures++;
        MinorImpact::cache("login_failures_$IP", $login_failures, 420);
        MinorImpact::cache("login_failures_$username", $login_failures, 420);
    }

    # We only need to check the cache and validate once per session.  Now that we're doing
    #   permission checking per object, this will save us a shitload.
    return $self->{USER} if ($self->{USER});

    # If the username and password are not provided, check the current session to see if the user_id has
    #   already been set.
    my $user_id = MinorImpact::session('user_id');
    if ($user_id) {
        #MinorImpact::log('debug', "cached user_id=$user_id");
        my $user = new MinorImpact::User($user_id);
        if ($user) {
            $self->{USER} = $user;
            return $user;
        }
    }

    # If ENV{USER} is set, it means we're being called from the command line.  For now,
    #   let's just trust that the system has taken care of validation.  Unfortunately,
    #   it opens up a HUGE security hole by allowing someone to change this variable to
    #   some other user and have access to all of their data - but only if the application
    #   is written without properly setting up users and logins in the first place, so...
    #   <shrug>. I don't know.  I'm just going to leave it for now and hope for the best.
    #
    if ($ENV{'USER'}) {
        my $user = new MinorImpact::User($ENV{'USER'});
        if (!$user) {
            # TODO: Make this a configuration option, so the developer can prevent
            #   new users from getting created randomly.
            # TODO: Add a 'shell' or 'local' parameter so we can queury all the accounts
            #   created using this method (I'm holding off on adding it because I still
            #   dan't have a mechanism for automating database updates).
            $user = MinorImpact::User::addUser({username => $ENV{'USER'}, password => '' });
        }
        # Check to see if the user has a blank password, the assumption being that this is
        #   some yahoo using the library for a simple command line script and doesn't care
        #   about users or security.
        if ($user) {
            MinorImpact::log('debug', "Trying out a blank password");
            if ($user->validateUser('')) {
                $self->{USER} = $user;
                return $user;
            }

            # If all else fails, prompt for a password on the command line.
            my $password = MinorImpact::CLI::passwordPrompt({username => $username});
            if ($user->validateUser($password)) {
                $self->{USER} = $user;
                return $user;
            }
        }
    }
    MinorImpact::log('debug', "no user found");
    MinorImpact::redirect({action => 'login' }) if ($params->{force});
    MinorImpact::log('debug', "ending");
    return;
}

=head2 www

=over

=item www()

=item www(\%params)

=back

Sets up the WWW/CGI framework.

  use MinorImpact;

  $MINORIMPACT = new MinorImpact;

  $MINORIMPACT->www({ actions => { index => \&index } });

  sub index {
    print "Content-type: text/html\n\n";
    print "Hello world!\n";
  }

=head3 Parameters

=over

=item actions

A hash defining which subs get called for a particular 'a=' parameter.

  # use test() when calling http://example.com/cgi-bin/index.cgi?a=test
  $MINORIMPACT->www({ actions => { test => \&test } });

  sub test() {
    print "Content-type: text/html\n\n";
    print "Test\n";
  }

See L<MinorImpact::WWW|MinorImpact::WWW> for a list of default actions.

=item site_config

A hash containing a list of site settings.  Sets or overrides the values in the "site"
of the L<configuration|/CONFIGURATION>.

  # Turn off headers for the default templates.
  $MINORIMPACT->www({site_config => { no_search => 'true' }});

Note that once these values are altered, they override the global configuration for the
b<duration of the script>, so be aware if you use these values outside of subs referenced
by www().

=back

=cut

sub www {
    my $self = shift || {};
    my $params = shift || {};

    MinorImpact::log('debug', "starting");

    if (ref($self) eq 'HASH') {
        $params = $self;
        undef($self);
    }

    $self = new MinorImpact() unless ($self);

    my $local_params = cloneHash($params);
    if (defined($local_params->{site_config})) {
        foreach my $key (keys %{$local_params->{site_config}}) {
            $self->{conf}{site}{$key} = $local_params->{site_config}{$key};
        }
    }
    delete($local_params->{site_config});

    my $CGI = MinorImpact::cgi();
    my $action = $CGI->param('a') || $CGI->param('action') || 'index';

    # Update the session with any query overrides.  The rest of the
    #  application can just get them from the session and assume
    #  it's up to date.
    #my $collection_id = $CGI->param('cid') || $CGI->param('collection_id');
    #my $search = $CGI->param('search');
    my $sort = $CGI->param('sort');
    my $tab_id = $CGI->param('tab_id');

    #if (defined($search)) {
    #    MinorImpact::session('search', $search );
    #    MinorImpact::session('collection_id', {});
    #} elsif (defined($collection_id)) {
    #    MinorImpact::session('collection_id', $collection_id);
    #    MinorImpact::session('search', {} );
    #}
    MinorImpact::session('sort', $sort ) if (defined($sort));
    MinorImpact::session('tab_id', $tab_id ) if (defined($tab_id));

    MinorImpact::log('debug', "\$action='$action'");
    foreach my $key (keys %ENV) {
        MinorImpact::log('debug', "$key='$ENV{$key}'");
    }

    if ($local_params->{actions}{$action}) {
        my $sub = $local_params->{actions}{$action};
        $sub->($self, $local_params);
    } elsif ( $action eq 'add') {
        MinorImpact::WWW::add($self, $local_params);
    } elsif ( $action eq 'add_reference') {
        MinorImpact::WWW::add_reference($self, $local_params);
    } elsif ( $action eq 'admin') {
        MinorImpact::WWW::admin($self, $local_params);
    } elsif ( $action eq 'collections') {
        MinorImpact::WWW::collections($self, $local_params);
    } elsif ( $action eq 'delete') {
        MinorImpact::WWW::del($self, $local_params);
    } elsif ( $action eq 'delete_search') {
        MinorImpact::WWW::delete_search($self, $local_params);
    } elsif ( $action eq 'edit') {
        MinorImpact::WWW::edit($self, $local_params);
    } elsif ( $action eq 'edit_settings') {
        MinorImpact::WWW::edit_settings($self, $local_params);
    } elsif ( $action eq 'edit_user') {
        MinorImpact::WWW::edit_user($self, $local_params);
    } elsif ( $action eq 'home') {
        MinorImpact::WWW::home($self, $local_params);
    } elsif ( $action eq 'login') {
        MinorImpact::WWW::login($self, $local_params);
    } elsif ( $action eq 'logout') {
        MinorImpact::WWW::logout($self, $local_params);
    } elsif ( $action eq 'object') {
        MinorImpact::WWW::object($self, $local_params);
    } elsif ( $action eq 'object_types') {
        MinorImpact::WWW::object_types($self, $local_params);
    } elsif ( $action eq 'register') {
        MinorImpact::WWW::register($self, $local_params);
    } elsif ( $action eq 'save_search') {
        MinorImpact::WWW::save_search($self, $local_params);
    } elsif ( $action eq 'search') {
        MinorImpact::WWW::search($self, $local_params);
    } elsif ( $action eq 'settings') {
        MinorImpact::WWW::settings($self, $local_params);
    } elsif ( $action eq 'tablist') {
        MinorImpact::WWW::tablist($self, $local_params);
    } elsif ( $action eq 'tags') {
        MinorImpact::WWW::tags($self, $local_params);
    } elsif ( $action eq 'user') {
        MinorImpact::WWW::user($self);
    } else {
        eval { MinorImpact::tt($action, $local_params); };
        if ($@) {
            MinorImpact::log('debug', $@);
            MinorImpact::WWW::index($self, $local_params) if ($@);
        }
    }
    MinorImpact::log('debug', "ending");
}

=head1 SUBROUTINES

=head2 cgi

Returns the global cgi object.

  my $CGI = MinorImpact::cgi();

=cut

sub cgi { 
    return $SELF->{CGI}; 
}

=head2 clearSession

Clears the current session.

  MinorImpact::clearSession();

=cut 

sub clearSession {
    my $session_id = MinorImpact::sessionID() || die "cannot get session ID";
    return MinorImpact::cache("session:$session_id", {});
}

=head2 db

Returns the global database object.

  $DB = MinorImpact::db();

=cut

sub db {
    my $MINORIMPACT = new MinorImpact();

    return $SELF->{DB};
}

my $VERSION = 2;
sub dbConfig {
    #MinorImpact::log('debug', "starting");
    my $DB = shift || return;

    eval {
        $DB->do("DESC `object`") || die $DB->errstr;
    };
    if ($@) {
        $DB->do("CREATE TABLE `object` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `user_id` int(11) NOT NULL,
            `name` varchar(50) NOT NULL,
            `description` text,
            `public` tinyint(1) default 0,
            `object_type_id` int(11) NOT NULL,
            `create_date` datetime NOT NULL,
            `mod_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        )") || die $DB->errstr;
        $DB->do("create index idx_object_user_id on object(user_id)") || die $DB->errstr;
        $DB->do("create index idx_object_user_type on object(user_id, object_type_id)") || die $DB->errstr;
    }
    eval {
        $DB->do("DESC `object_type`") || die $DB->errstr;
    };
    if ($@) {
        $DB->do("CREATE TABLE `object_type` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `name` varchar(50) DEFAULT NULL,
            `description` text,
            `default_value` varchar(255) NOT NULL,
            `plural` varchar(50) DEFAULT NULL,
            `url` varchar(255) DEFAULT NULL,
            `system` tinyint(1) DEFAULT 0,
            `version` int(11) DEFAULT 0,
            `readonly` tinyint(1) DEFAULT 0,
            `no_name` tinyint(1) DEFAULT 0,
            `public` tinyint(1) DEFAULT 0,
            `no_tags` tinyint(1) DEFAULT 0,
            `mod_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            `create_date` datetime NOT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `idx_object_type` (`name`)
        )") || die $DB->errstr;
    }

    eval {
        $DB->do("DESC `object_field`") || die $DB->errstr;
    };
    if ($@) {
        $DB->do("CREATE TABLE `object_field` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `object_type_id` int(11) NOT NULL,
            `name` varchar(50) NOT NULL,
            `description` varchar(255),
            `default_value` varchar(255),
            `type` varchar(15) DEFAULT NULL,
            `hidden` tinyint(1) DEFAULT '0',
            `readonly` tinyint(1) DEFAULT '0',
            `required` tinyint(1) DEFAULT '0',
            `sortby` tinyint(1) DEFAULT '0',
            `mod_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            `create_date` datetime NOT NULL,
            PRIMARY KEY (`id`)
        )") || die $DB->errstr;
        $DB->do("create unique index idx_object_field_name on object_field(object_type_id, name)") || die $DB->errstr;
        $DB->do("create index idx_object_field_type_id on object_field(object_type_id)") || die $DB->errstr;
    }
    eval {
        $DB->do("DESC `object_data`") || die $DB->errstr;
    };
    if ($@) {
        $DB->do("CREATE TABLE `object_data` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `object_id` int(11) NOT NULL,
            `object_field_id` int(11) NOT NULL,
            `value` varchar(50) NOT NULL,
            `mod_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            `create_date` datetime NOT NULL,
            PRIMARY KEY (`id`),
            KEY `idx_object_field` (`object_id`,`object_field_id`),
            KEY `idx_object_data` (`object_id`)
        )") || die $DB->errstr;
    }

    eval {
        $DB->do("DESC `object_tag`") || die $DB->errstr;
    };
    if ($@) {
        $DB->do("CREATE TABLE `object_tag` ( 
            `object_id` int(11) NOT NULL, 
            `name` varchar(50) DEFAULT NULL
          ) ENGINE=MyISAM DEFAULT CHARSET=latin1") || die $DB->errstr;
        $DB->do("create unique index idx_id_name on object_tag (object_id, name)") || die $DB->errstr;
    }

    eval {
        $DB->do("DESC `object_text`") || die $DB->errstr;
    };
    if ($@) {
        $DB->do("CREATE TABLE `object_text` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `object_id` int(11) NOT NULL,
            `object_field_id` int(11) NOT NULL,
            `value` mediumtext,
            `mod_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            `create_date` datetime NOT NULL,
            PRIMARY KEY (`id`),
            KEY `idx_object_text` (`object_id`),
            KEY `idx_object_field` (`object_id`,`object_field_id`)
        )") || die $DB->errstr;
    }
    eval {
        $DB->do("DESC `object_reference`") || die $DB->errstr;
    };
    if ($@) {
        $DB->do("CREATE TABLE `object_reference` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `object_text_id` int(11) NOT NULL,
            `data` varchar(255) NOT NULL,
            `object_id` int(11) NOT NULL,
            `mod_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            `create_date` datetime NOT NULL,
            PRIMARY KEY (`id`)
            )") || die $DB->errstr;
    }

    MinorImpact::collection::dbConfig() unless (MinorImpact::Object::typeID("MinorImpact::collection"));
    MinorImpact::settings::dbConfig() unless (MinorImpact::Object::typeID("MinorImpact::settings"));
    MinorImpact::entry::dbConfig() unless (MinorImpact::Object::typeID("MinorImpact::entry"));

    my $admin = new MinorImpact::User('admin');
    unless ($admin) {
        $DB->do("INSERT INTO user(name, password, admin) VALUES (?,?,?)", undef, ("admin", "92.96PWMq8Us.", 1)) || die $DB->errstr;
    }
    MinorImpact::log('debug', "ending");
}

=head2 debug

=over

=item debug($switch)

=back

Turn debugging on or off by setting C<$switch> to true or false.

  MinorImpact::debug(1);
  MinorImpact::log("debug", "This message will get logged.");
  MinorImpact::debug(0);
  MinorImpact::log("debug", "This message will not get logged.");

=cut

sub debug {
    my $toggle = shift || 0;

    # I'm not sure if I'm ever going to use this, but it might come in handy.
    my $sub = (caller(1))[3];
    if (!$sub || $sub =~/log$/) {
         $sub = (caller(2))[3];
    }
    $sub .= "()";

    $MinorImpact::debug = isTrue($toggle)?$sub:0;
}

=head2 log

=over

=item log($severity_level, $message)

=back

Adds a message to the application log output.  Severity levels are, in order:
"debug", "info", "notice", "warning", "err", "crit", "alert" and "emerg".

  MinorImpact::log("crit", "There has been a critical error.");

Messages with the "debug" severity are only logged if the global C<debug>
switch is enabled.  See L<debug()|/debug>.

Application-wide logging is configured in L<E<sol>etcE<sol>minorimpact.conf|MinorImpact/CONFIGURATION>.

=cut

sub log {
    my $level = shift || return;
    my $message = shift || return;

    my $self = $MinorImpact::SELF;
    return unless ($self && !$self->{conf}{default}{no_log});

    my $sub = (caller(1))[3];
    if ($sub =~/log$/) {
        $sub = (caller(2))[3];
    }
    $sub .= "()";

    return if ($level eq 'debug' && !$MinorImpact::debug);
    chomp($message);
    my $log = "$level $sub $message";

    if ($self->{conf}{default}{log_method} eq 'file') {
        my $date = toMysqlDate();
        my $file = $self->{conf}{default}{log_file} || return;
        open(LOG, ">>$file") || die "Can't open $file";
        print LOG "$date " . $self->{conf}{default}{application_id} . "[$$]: $log\n";
        #my ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask, $hinthash) = caller;
        #print LOG "   caller: $package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask, $hinthash\n";
        #foreach $i (0, 1, 2, 3) {
        #    my ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask, $hinthash) = caller($i);
        #    print LOG "   caller($i): $package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask, $hinthash\n";
        #}
        close(LOG);
    } elsif ($self->{conf}{default}{log_method} eq 'stderr') {
        my $date = toMysqlDate();
        print STDERR  "$date " . $self->{conf}{default}{application_id} . "[$$]: $log\n";
    } elsif ($self->{conf}{default}{log_method} eq 'syslog') {
        syslog($level, $log);
    }
} 

=head2 userDB

Returns the global user database object.

  $USERDB = MinorImpact::userDB();

=cut

sub userDB {
    return $SELF->{USERDB};
}

 
=head2 userID

Return the id of the current logged in user.

  my $user_id = MinorImpact::userID();

=cut

sub userID {
    return user()->id();
}

=head1 AUTHOR

Patrick Gillan <pgillan@minorimpact.com>

=cut

1;
