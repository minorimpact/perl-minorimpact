package MinorImpact;

use strict;

use Cache::Memcached;
use CHI;
use CGI;
use Cwd;
use Data::Dumper;
use DBI;
use Digest::MD5 qw(md5 md5_hex);
use File::Spec;
use JSON;
use Sys::Syslog;
use Template;
use Time::HiRes qw(tv_interval gettimeofday);
use Time::Local;
use URI::Escape;

use MinorImpact::Config;
use MinorImpact::Object;
use MinorImpact::User;
use MinorImpact::Util;
use MinorImpact::WWW;

our $SELF;

=head1 NAME

=head1 METHODS

=over 4

=cut

sub new {
    my $package = shift;
    my $options = shift || {};

    my $self = $SELF;
    #MinorImpact::log('debug', "starting");

    unless ($self) {
        MinorImpact::log('notice', "creating new MinorImpact object") unless ($options->{no_log});

        my $config;
        if ($options->{config}) {
            $config = $options->{config};
        } elsif ($options->{config_file}) {
            $config = readConfig($options->{config_file});
        } elsif ($ENV{MINORIMPACT_CONFIG} && -f $ENV{MINORIMPACT_CONFIG}) {
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

        my $dsn = "DBI:mysql:database=$config->{db}->{database};host=$config->{db}->{db_host};port=$config->{db}->{port}";
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

    #MinorImpact::log('debug', "ending");
    return $self;
}

sub cache {
    my $self = shift || return;

    #MinorImpact::log('debug', "starting");
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

    #MinorImpact::log('debug', "setting $name='" . $value . "' ($timeout)");
    $cache->set($name, $value, $timeout);

    #MinorImpact::log('debug', "ending");
    return $cache;
}

sub cgi { 
    return $SELF->{CGI}; 
}

sub clearSession {
    my $session_id = MinorImpact::sessionID() || die "cannot get session ID";
    return MinorImpact::cache("session:$session_id", {});
}

sub db {
    return $SELF->{DB};
}

my $VERSION = 1;
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
            `public tinyint(1) default 0,
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
            `mod_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            `create_date` datetime NOT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `object_type_idx` (`name`)
        )");
        $DB->do("create index idx_object_type_id on object_field(object_type_id)");
        $DB->do("create unique index idx_object_field_name on object_field(object_type_id, name)");
    }

    eval {
        $DB->do("DESC `object_field`");
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
        )");
    }
    eval {
        $DB->do("DESC `object_data`");
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
        )");
    }

    eval {
        $DB->do("DESC `object_tag`");
    };
    if ($@) {
        $DB->do("CREATE TABLE `object_tag` ( `object_id` int(11) NOT NULL, `name` varchar(50) DEFAULT NULL) ENGINE=MyISAM DEFAULT CHARSET=latin1");
        $DB->do("create unique index idx_id_name on object_tag (object_id, name)");
    }

    eval {
        $DB->do("DESC `object_text`");
    };
    if ($@) {
        $DB->do("CREATE TABLE `object_text` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `object_id` int(11) NOT NULL,
            `object_field_id` int(11) NOT NULL,
            `value` text,
            `mod_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            `create_date` datetime NOT NULL,
            PRIMARY KEY (`id`),
            KEY `idx_object_text` (`object_id`),
            KEY `idx_object_field` (`object_id`,`object_field_id`)
        )");
    }
    eval {
        $DB->do("DESC `object_reference`");
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
            )");
    }

    MinorImpact::collection::dbConfig() unless (MinorImpact::Object::typeID("MinorImpact::collection"));
    MinorImpact::settings::dbConfig() unless (MinorImpact::Object::typeID("MinorImpact::settings"));
    #MinorImpact::log('debug', "ending");
}

sub debug {
    my $toggle = shift || 0;

    # I'm not sure if I'm ever going to use this, but it might come in handy.
    my $sub = (caller(1))[3];
    if ($sub =~/log$/) {
         $sub = (caller(2))[3];
    }
    $sub .= "()";

    $MinorImpact::debug = isTrue($toggle)?$sub:0;
}

=item log( $log_level, $message )

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
        my $file = $self->{conf}{default}{log_file} || return;;
        open(LOG, ">>$file") || die "Can't open $file";
        print LOG "$date " . $self->{conf}{default}{application_id} . "[$$]: $log\n";
        #my ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask, $hinthash) = caller;
        #print LOG "   caller: $package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask, $hinthash\n";
        #foreach $i (0, 1, 2, 3) {
        #    my ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask, $hinthash) = caller($i);
        #    print LOG "   caller($i): $package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask, $hinthash\n";
        #}
        close(LOG);
    } elsif ($self->{conf}{default}{log_method} eq 'syslog') {
        syslog($level, $log);
    }
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

sub tt {
    my $self = shift || return; 

    #MinorImpact::log('debug', "starting");

    if (!ref($self)) {
        unshift(@_, $self);
        $self = $MinorImpact::SELF;
    }

    my $TT;
    if ($self->{TT}) {
        $TT = $self->{TT};
    } else {
        my $CGI = cgi();
        my $collection_id = MinorImpact::session('collection_id');
        my $copyright = $self->{conf}{default}{copyright} || '';
        if ($copyright =~/YEAR/) {
            my $year = ((localtime(time))[5] + 1900);
            $copyright =~s/YEAR/$year/;
        }
        my $limit = $CGI->param('limit') || 30;
        my $page = $CGI->param('page') || 1;
        my $search = MinorImpact::session('search');
        my $sort = MinorImpact::session('sort');
        my $tab_id = MinorImpact::session('tab_id');
        my $user = MinorImpact::user();

        my $template_directory = $ENV{MINORIMPACT_TEMPLATE} || $self->{conf}{default}{template_directory};
        my @collections = ();
        if ($user) {
            @collections = $user->getCollections();
        }

        # The default package templates are in the 'template' directory 
        # in the libary.  Find it, and use it as the secondary template location.
        (my $package = __PACKAGE__ ) =~ s#::#/#g;
        my $filename = $package . '.pm';

        (my $path = $INC{$filename}) =~ s#/\Q$filename\E$##g; # strip / and filename
        my $global_template_directory = File::Spec->catfile($path, "$package/template");

        my $variables = {
            cid         => $collection_id,
            collections => [ @collections ],
            copyright   => $copyright,
            ENV         => \%ENV,
            home        => $self->{conf}{default}{home_script},
            limit       => $limit,
            page        => $page,
            script_name => MinorImpact::scriptName(),
            #search      => $search,
            sort        => $sort,
            typeName    => sub { MinorImpact::Object::typeName(shift); },
            url         => sub { MinorImpact::url(shift); },
            user        => $user,
        };

        $TT = Template->new({
            INCLUDE_PATH => [ $template_directory, $global_template_directory ],
            INTERPOLATE => 1,
            VARIABLES => $variables,
        }) || die $TT->error();

        $self->{TT} = $TT;
    }
    $TT->process(@_) || die $TT->error();
}

sub url {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log('debug', "starting");


    #MinorImpact::log('debug', "\$self='" . $self . "'");
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
    my $object_id = $params->{object_id};
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

    if ($pretty) {
        $url .= "/$action";
        if ($object_id) {
            $url .= "/$object_id" 
        } elsif ($action eq 'add' && $object_type_id) {
            $url .= "/$object_type_id";
            undef($object_type_id);
        }
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

    #print $self->{CGI}->header(-location=>$location);
    #MinorImpact::log('debug', "\$url='$url'");
    #MinorImpact::log('debug', "ending");
    return $url;
}

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
    my $username = $params->{username} || $CGI->param('username') || $ENV{USER};
    my $password = $params->{password} || $CGI->param('password');
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
        # ... or this username.
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
    if ($self->{USER} && $self->{USERHASH} && $user_hash eq $self->{USERHASH}) {
        return $self->{USER};
    }

    # If the username and password are provided, then validate the user.
    if ($username && $password && !$self->{USERHASH}) {
        MinorImpact::log('notice', "validating " . $username);

        $self->{USERHASH} = $user_hash;
        my $user = new MinorImpact::User($username);
        if ($user && $user->validateUser($password)) {
            #MinorImpact::log('debug', "password verified for $username");
            $self->{USER} = $user;
            MinorImpact::session('user_id', $user->id());
            return $user;
        }
        # We keep the login failure count for 7 minutes, which should be long enough to make
        #   a brute force attempt fail.
        $login_failures++;
        MinorImpact::cache("login_failures_$IP", $login_failures, 420);
        MinorImpact::cache("login_failures_$username", $login_failures, 4200);
    }

    # We only need to check the cache and validate once per session.  Now that we're doing
    #   permission checking per object, this will save us a shitload.
    return $self->{USER} if ($self->{USER});

    my $user_id = MinorImpact::session('user_id');
    if ($user_id) {
        #MinorImpact::log('debug', "cached user_id=$user_id");
        my $user = new MinorImpact::User($user_id);
        if ($user) {
            $self->{USER} = $user;
            return $user;
        }
    }

    # Not sure what this is supposed to do.  Maybe it auto validates from the command line
    #if ($ENV{'USER'}) {
    #   my $user = new MinorImpact::User($ENV{'user'});
    #    return $user;
    #}
    #MinorImpact::log('info', "no user found");
    MinorImpact::redirect({action => 'login' }) if ($params->{force});
    #MinorImpact::log('debug', "ending");
    return;
}

sub userID {
    return user()->id();
}

=item www()

=back

=cut

sub www {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log('debug', "starting");

    my $CGI = MinorImpact::cgi();
    my $action = $CGI->param('a') || $CGI->param('action') || 'index';

    # Update the session with any query overrides.  The rest of the
    #  application can just get them from the session and assume
    #  it's up to date.
    my $collection_id = $CGI->param('cid') || $CGI->param('collection_id');
    my $search = $CGI->param('search');
    my $sort = $CGI->param('sort');
    my $tab_id = $CGI->param('tab_id');

    if (defined($search)) {
        MinorImpact::session('search', $search );
        MinorImpact::session('collection_id', {});
    } elsif (defined($collection_id)) {
        MinorImpact::session('collection_id', $collection_id);
        MinorImpact::session('search', {} );
    }
    MinorImpact::session('sort', $sort ) if (defined($sort));
    MinorImpact::session('tab_id', $tab_id ) if (defined($tab_id));

    MinorImpact::log('debug', "\$action='$action'");
    #foreach my $key (keys %ENV) {
    #    MinorImpact::log('debug', "$key='$ENV{$key}'");
    #}

    if ($params->{actions}{$action}) {
        my $sub = $params->{actions}{$action};
        $sub->($self, $params);
    } elsif ( $action eq 'about') {
        MinorImpact::WWW::about($self, $params);
    } elsif ( $action eq 'add') {
        MinorImpact::WWW::add($self, $params);
    } elsif ( $action eq 'add_reference') {
        MinorImpact::WWW::add_reference($self, $params);
    } elsif ( $action eq 'admin') {
        MinorImpact::WWW::admin($self, $params);
    } elsif ( $action eq 'collections') {
        MinorImpact::WWW::collections($self, $params);
    } elsif ( $action eq 'contact') {
        MinorImpact::WWW::contact($self, $params);
    } elsif ( $action eq 'css') {
        MinorImpact::WWW::css($self, $params);
    } elsif ( $action eq 'delete') {
        MinorImpact::WWW::del($self, $params);
    } elsif ( $action eq 'delete_collection') {
        MinorImpact::WWW::delete_collection($self, $params);
    } elsif ( $action eq 'edit') {
        MinorImpact::WWW::edit($self, $params);
    } elsif ( $action eq 'edit_settings') {
        MinorImpact::WWW::edit_settings($self, $params);
    } elsif ( $action eq 'edit_user') {
        MinorImpact::WWW::edit_user($self, $params);
    } elsif ( $action eq 'home') {
        MinorImpact::WWW::home($self, $params);
    } elsif ( $action eq 'login') {
        MinorImpact::WWW::login($self, $params);
    } elsif ( $action eq 'logout') {
        MinorImpact::WWW::logout($self, $params);
    } elsif ( $action eq 'object') {
        MinorImpact::WWW::object($self, $params);
    } elsif ( $action eq 'object_types') {
        MinorImpact::WWW::object_types($self);
    } elsif ( $action eq 'register') {
        MinorImpact::WWW::register($self, $params);
    } elsif ( $action eq 'save_search') {
        MinorImpact::WWW::save_search($self, $params);
    } elsif ( $action eq 'search') {
        MinorImpact::WWW::search($self, $params);
    } elsif ( $action eq 'settings') {
        MinorImpact::WWW::settings($self, $params);
    } elsif ( $action eq 'tablist') {
        MinorImpact::WWW::tablist($self, $params);
    } elsif ( $action eq 'tags') {
        MinorImpact::WWW::tags($self, $params);
    } elsif ( $action eq 'user') {
        MinorImpact::WWW::user($self);
    } else {
        MinorImpact::WWW::index($self, $params);
    }
    #MinorImpact::log('debug', "ending");
}

=head1 AUTHOR

Patrick Gillan (pgillan@minorimpact.com)

=cut

1;
