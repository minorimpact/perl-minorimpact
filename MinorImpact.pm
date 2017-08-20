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

use MinorImpact::BinLib;
use MinorImpact::Config;
use MinorImpact::Object;
use MinorImpact::User;
use MinorImpact::Util;
use MinorImpact::WWW;

my $VERSION = 1;
my $SELF;

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
                $self->redirect("?a=login");
            } elsif ($options->{admin} && !$user->isAdmin()) {
                MinorImpact::log('notice', "not an admin user");
                $self->redirect("?a=login");
            }
        } else {
            MinorImpact::log('notice', "no logged in user");
            $self->redirect("?a=login");
        }
    }
    if ($options->{https} && ($ENV{HTTPS} ne 'on' && !$ENV{HTTP_X_FORWARDED_FOR})) {
        MinorImpact::log('notice', "not https");
        $self->redirect();
    }

    #MinorImpact::log('debug', "ending");
    return $self;
}

sub cgi { 
    return $SELF->{CGI}; 
}

sub db {
    return $SELF->{DB};
}

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
    MinorImpact::page::dbConfig() unless (MinorImpact::Object::typeID("MinorImpact::page"));
    MinorImpact::settings::dbConfig() unless (MinorImpact::Object::typeID("MinorImpact::settings"));
    #MinorImpact::log('debug', "ending");
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

sub redirect {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log('debug', "starting");

    my $CGI = MinorImpact::cgi();
    my $user = MinorImpact::user();

    my $search = $CGI->param('search');
    my $cid = $CGI->param('cid');
    my $sort = $CGI->param('sort');

    #MinorImpact::log('debug', "\$self='" . $self . "'");
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
        $params->{redirect} = $redirect;
    }

    my $location = $params->{redirect} || $CGI->param('redirect') ||  ($user?'index.cgi?a=home':'index.cgi?');
    #MinorImpact::log('debug', "\$location='$location'");

    my $domain = "https://$ENV{HTTP_HOST}";
    my $script_name = MinorImpact::scriptName();
    if ($location =~/^\?/) {
        $location = "$domain/cgi-bin/$script_name$location";
    } elsif ($location =~/^\//) {
        $location = "$domain$location";
    } elsif ($location !~/^\//) {
        $location = "$domain/cgi-bin/$location";
    }
    $location .= ($location=~/\?/?"":"?") . "&search=$search&sort=$sort&cid=$cid";

    #print $self->{CGI}->header(-location=>$location);
    MinorImpact::log('info', "redirecting to $location");
    print "Location:$location\n\n";
    #MinorImpact::log('debug', "ending");
    exit;
}

sub scriptName {
    my ($script_name) = $0 =~/\/([^\/]+.cgi)$/;
    return $script_name;
}

sub session {
    my $name = shift || return;
    my $value = shift;

    my $self = new MinorImpact();
    my $CGI = MinorImpact::cgi();

    my $timeout = $self->{conf}{default}{user_timeout} || 2592000;
    my $session_id;
    if ($ENV{REMOTE_ADDR}) {
        $session_id = $CGI->cookie("user_id");
    } else {
        $session_id = $ENV{SSH_CLIENT} ."-$$" || $ENV{USER} . "-$$";
    }
    #MinorImpact::log('debug', "\$session_id='$session_id'\n");
    my $session;
    if ($session_id) {
        $session = cache("session:$session_id");
    } else {
        # ... otherwise, generate a new session_id.
        $session_id = int(rand(10000000)) . "_" . int(rand(1000000));
        if ($ENV{REMOTE_ADDR}) {
            my $cookie =  $CGI->cookie(-name=>'user_id', -value=>$session_id, -expires=>"+${timeout}s");
            print "Set-Cookie: $cookie\n";
        }
        $session = {};
    }

    if ($name && !defined($value)) {
        return $session->{$name};
    }

    if ($name && defined($value)) {
        $session->{$name} = $value;
    }
    
    return cache("session:$session_id", $session, $timeout);
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
        my $user = MinorImpact::user();
        my $cid = $CGI->param('cid');
        my $search = $CGI->param('search');
        my $sort = $CGI->param('sort');

        my $template_directory = $ENV{MINORIMPACT_TEMPLATE} || $self->{conf}{default}{template_directory};

        # The default package templates are in the 'template' directory 
        # in the libary.  Find it, and use it as the secondary template location.
        (my $package = __PACKAGE__ ) =~ s#::#/#g;
        my $filename = $package . '.pm';

        (my $path = $INC{$filename}) =~ s#/\Q$filename\E$##g; # strip / and filename
        my $global_template_directory = File::Spec->catfile($path, "$package/template");

        my $variables = {
            cid         => $cid,
            home        => $self->{conf}{default}{home_script},
            ENV         => \%ENV,
            script_name => MinorImpact::scriptName(),
            search      => $search,
            sort        => $sort,
            typeName    => sub { MinorImpact::Object::typeName(shift); },
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

    # If the username and password are provided, then validate the user.
    my $username = $params->{username} || $CGI->param('username') || $ENV{USER};
    my $password = $params->{password} || $CGI->param('password');
    if ($username && $password) {
        MinorImpact::log('notice', "validating " . $username);
        my $user_hash = md5_hex("$username:$password");
        # If this is the first page, the cookie hasn't been set, so if there are a ton of items
        #   we're gonna validate against the database over and over again... so just validate against
        #   a stored hash and return the cached user.
        if ($self->{USER} && $self->{USERHASH} && $user_hash eq $self->{USERHASH}) {
            return $self->{USER};
        }
        my $user = new MinorImpact::User($username);
        if ($user && $user->validateUser($password)) {
            #MinorImpact::log('debug', "password verified for $username");
            my $user_id = $user->id();

            MinorImpact::session('user_id', $user_id);
            $self->{USER} = $user;
            $self->{USERHASH} = $user_hash;
            return $user;
        }
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
    #MinorImpact::log('debug', "ending");
    MinorImpact::redirect("?a=login") if ($params->{force});
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

    my $CGI = MinorImpact::cgi();
    my $action = $CGI->param('a') || $CGI->param('action') || 'index';

    #$action = 'index' if ($object_id && ($action eq 'list' || $action eq 'view'));

    MinorImpact::log('debug', "\$action='$action'");

    if ($params->{actions}{$action}) {
        #MinorImpact::log('debug', "\$params->{actions}{$action}='" . $params->{actions}{$action} . "'");
        my $sub = $params->{actions}{$action};
        $sub->($self, $params);
    } elsif ( $action eq 'add') {
        MinorImpact::WWW::add($self, $params);
    } elsif ( $action eq 'add_reference') {
        MinorImpact::WWW::add_reference($self, $params);
    } elsif ( $action eq 'admin') {
        MinorImpact::WWW::admin($self, $params);
    } elsif ( $action eq 'collections') {
        MinorImpact::WWW::collections($self, $params);
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
    } elsif ( $action eq 'object_types') {
        MinorImpact::WWW::object_types($self);
    } elsif ( $action eq 'register') {
        MinorImpact::WWW::register($self, $params);
    } elsif ( $action eq 'save_search') {
        MinorImpact::WWW::save_search($self, $params);
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
}

=head1 AUTHOR

Patrick Gillan (pgillan@minorimpact.com)

=cut

1;
