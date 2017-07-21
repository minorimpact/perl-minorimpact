package MinorImpact;

use Cache::Memcached;
use CHI;
use CGI;
use Cwd;
use Data::Dumper;
use DBI;
use Digest::MD5 qw(md5 md5_hex);
use File::Spec;
use JSON;
use Template;
use Time::HiRes qw(tv_interval gettimeofday);
use Time::Local;
use URI::Escape;

use MinorImpact::BinLib;
use MinorImpact::CGI;
use MinorImpact::Config;
use MinorImpact::Object;
use MinorImpact::User;
use MinorImpact::Util;

sub getDB { 
    return $SELF->{DB}; 
}

sub getCGI { 
    return $SELF->{CGI}; 
}

sub scriptName {
    my ($script_name) = $0 =~/\/([^\/]+.cgi)$/;
    return $script_name;
}

sub new {
    my $package = shift;
    my $options = shift || {};

    #(my $p = __PACKAGE__ ) =~ s#::#/#g;
    #my $filename = $p . '.pm';
    #(my $path = $INC{$filename}) =~ s#/\Q$filename\E$##g; # strip / and filename
    #use lib "$path/$p";

    #my $global_template_directory = File::Spec->catfile($path, "$package/template");

    my $self = $SELF;
    #MinorImpact::log(8, "starting");

    unless ($self) {
        MinorImpact::log(3, "creating new MinorImpact object");

        my $config;
        if ($options->{config}) {
            $config = $options->{config};
        } elsif ($options->{config_file}) {
            $config = readConfig($options->{config_file});
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
        $self->{conf}{default}{home_script} ||= "index.cgi";
        $self->{conf}{application} = $options;

        $self->{starttime} = [gettimeofday];

        checkDatabaseTables($self->{DB});
    }

    if ($self->{CGI}->param("a") ne 'login' && ($options->{valid_user} || $options->{user_id} || $options->{admin})) {
        my ($script_name) = scriptName();
        my $user = $self->getUser();
        if ($user) {
            if ($options->{user_id} && $user->id() != $options->{user_id}) {
                MinorImpact::log(3, "logged in user doesn't match");
                $self->redirect("?a=login");
            } elsif ($options->{admin} && !$user->isAdmin()) {
                MinorImpact::log(3, "not an admin user");
                $self->redirect("?a=login");
            }
        } else {
            MinorImpact::log(3, "no logged in user");
            $self->redirect("?a=login");
        }
    }
    if ($options->{https} && $ENV{HTTPS} ne 'on') {
        MinorImpact::log(3, "not https");
        $self->redirect();
    }

    #MinorImpact::log(8, "ending");
    return $self;
}

sub getUser {
    my $self = shift || {};
    my $params = shift || {};

    #MinorImpact::log(7, "starting");

    if (ref($self) eq 'HASH') {
        $params = $self;
        undef($self);
    }
    if (!$self) {
        $self = new MinorImpact();
    }

    my $CGI = MinorImpact::getCGI();
    my $CACHE = MinorImpact::getCache({ method => 'memcached' });

    # If the username and password are provided, then validate the user.
    my $username = $params->{username} || $CGI->param('username') || $ENV{USER};
    my $password = $params->{password} || $CGI->param('password');
    if ($username && $password) {
        MinorImpact::log(3, "validating " . $username);
        my $user_hash = md5_hex("$username:$password");
        if ($self->{USER} && $self->{USERHASH} && $user_hash eq $self->{USERHASH}) {
            return $self->{USER};
        }
        my $user = new MinorImpact::User($username);
        if ($user && $user->validateUser($password)) {
            #MinorImpact::log(8, "password verified for $username");
            my $user_id = $user->id();
            my $timeout = $self->{conf}{default}{user_timeout} || 86400;

            my $client_ip = $CACHE->get("client_ip:$user_id");
            my $new_ip = $ENV{REMOTE_ADDR} || $ENV{SSH_CLIENT};
            $client_ip = "$client_ip,$new_ip";
            $client_ip =~s/^,?\d+\.\d+\.\d+\.\d+,// if (length($client_ip) > 128);
            $CACHE->set("client_ip:$user_id", $client_ip, $timeout);
            if ($ENV{REMOTE_ADDR}) {
                my $cookie =  $CGI->cookie(-name=>'user_id', -value=>$user_id);
                print "Set-Cookie: $cookie\n";
            } else {
                # TODO: This only supports a single command line connection at a time.  Might be a
                #   problem in the future.
                $CACHE->set($client_ip, $user_id, $timeout);
            }
            #MinorImpact::log(8, "cache->user_id:'" . $CACHE->get('user_id') . "'\n");
            #MinorImpact::log(7, "ending");
            $self->{USER} = $user;
            $self->{USERHASH} = $user_hash;
            return $user;
        }
    }

    # We only need to check the cache and validate once per session.  Now that we're doing
    #   permission checking per object, this will save us a shitload.
    return $self->{USER} if ($self->{USER});


    # If the user has logged in before, and we can verify it's the same session,
    #   we can get the user_id from cache or cookie and don't require credentials
    #   again.
    my $user_id = $CGI->cookie("user_id") || $CACHE->get($ENV{SSH_CLIENT});
    #MinorImpact::log(8, "user_id=$user_id");
    if ($user_id) {
        #MinorImpact::log(8, "cached user_id=$user_id");
        my $user = new MinorImpact::User($user_id);
        my $ip_list = $CACHE->get("client_ip:$user_id");
        MinorImpact::log(8, "\$ip_list='$ip_list',count='" . length($ip_list) . "'");
        #MinorImpact::log(8, "client_ip=$client_ip");
        if ($user && $ip_list) {
            foreach my $client_ip ( split(",", $ip_list) ) {
                #MinorImpact::log(8, "\$ENV{REMOTE_ADDR}=$ENV{REMOTE_ADDR}");
                if ($client_ip && ($ENV{REMOTE_ADDR} eq $client_ip  || $ENV{SSH_CLIENT} eq $client_ip)) {
                    #MinorImpact::log(7, "ending - cached ip matched current ip");
                    $self->{USER} = $user;
                    return $user;
                }
            }
        }
    }

    # Not sure what this is supposed to do.  Maybe it auto validates from the command line
    #   if the logged in user is a valid user in the system?  Seems dangerous.
    #if ($ENV{'USER'}) {
    #   my $user = new MinorImpact::User($ENV{'user'});
    #    return $user;
    #}
    #MinorImpact::log(8, "no user found");
    #MinorImpact::log(7, "ending");
    MinorImpact::redirect("?a=login") if ($params->{force});
    return;
}

sub redirect {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "starting");

    my $CGI = MinorImpact::getCGI();

    #MinorImpact::log(8, "\$self='" . $self . "'");
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

    my $location = $params->{redirect} || $CGI->param('redirect') ||  'index.cgi';
    #MinorImpact::log(8, "\$location='$location'");

    my $domain = "https://$ENV{HTTP_HOST}";
    my $script_name = MinorImpact::scriptName();
    if ($location =~/^\?/) {
        $location = "$domain/cgi-bin/$script_name$location";
    } elsif ($location =~/^\//) {
        $location = "$domain/$location";
    } elsif ($location !~/^\//) {
        $location = "$domain/cgi-bin/$location";
    }

    #print $self->{CGI}->header(-location=>$location);
    MinorImpact::log(3, "redirecting to $location");
    print "Location:$location\n\n";
    #MinorImpact::log(7, "ending");
    exit;
}

sub param {
    my $self = shift || return;
    my $param = shift;

    unless (ref($self) eq 'MinorImpact') {
        $param = $self;
        $self = $SELF;
    }
    my $CGI = $self->{CGI};
    return $CGI->param($param);
}

sub log {
    my $level = shift || return;
    my $message = shift || return;

    my $date = toMysqlDate();
    my $file = "/tmp/debug.log";
    my $sub = (caller(1))[3];
    if ($sub =~/log$/) {
        $sub = (caller(2))[3];
    }
    $sub .= "()";
    chomp($message);

    my $log = "$date|$$|$level|$sub|$message\n";
    open(LOG, ">>$file") || die;
    print LOG $log;
    #my ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask, $hinthash) = caller;
    #print LOG "   caller: $package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask, $hinthash\n";
    #foreach $i (0, 1, 2, 3) {
    #    my ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask, $hinthash) = caller($i);
    #    print LOG "   caller($i): $package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask, $hinthash\n";
    #}
    close(LOG);

    #my $DB = MinorImpact::getDB();
    #my $hostname = `hostname`;
    #$DB->do("INSERT INTO log (hostname, pid, script, level, sub, message) VALUES (?, ?, ?, ?, ?, ?)", undef, ($hostname, $$, $0, $level, $sub, $message));
}

sub cache {
    my $params = shift || {};

    my $key = $params->{key} || return;
    my $timeout = $params->{timeout} || 300;
    my $method = $params->{method} || 'file';
    my $value = $params->{value};

    if ($method eq 'file') {
        my $cache_file = "/tmp/minorimpact.cache";
        my $config = readConfig($cache_file);
        if (defined($value)) { # && $value ne '') {
            # write cache
            $config->{$key}{value} = $value;
            $config->{$key}{timeout} = time() + $timeout;
            writeConfig($cache_file, $config);
        }  else {
            # read cache
            if ($config->{$key}{timeout} > time()) {
                $value = $config->{$key}{value};
            }
        }
    } elsif ($method eq 'memcached') {
        my $cache = MinorImpact::getMemcached();
        if (defined($value)) {
            $cache->set($key, $value, $timeout);
        } else {
            $value = $cache->get($key);
        }
    }
    return $value;
}

sub checkDatabaseTables {
    #MinorImpact::log(7, "starting");
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
            `object_type_id` int(11) NOT NULL,
            `create_date` datetime NOT NULL,
            `mod_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        )") || die $DB->errstr;
        $DB->do("create index idx_object_user_id on object(user_id)") || die $DB->errstr;
        $DB->do(" create index idx_object_user_type on object(user_id, object_type_id)") || die $DB->errstr;
    }
    eval {
        $DB->do("DESC `object_type`") || die $DB->errstr;
    };
    if ($@) {
        $DB->do("CREATE TABLE `object_type` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `name` varchar(50) DEFAULT NULL,
            `description` text,
            `plural` varchar(50) DEFAULT NULL,
            `url` varchar(255) DEFAULT NULL,
            `system` tinyint(1) DEFAULT 0,
            `mod_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            `create_date` datetime NOT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `object_type_idx` (`name`)
        )");
        $DB->do("create index idx_object_type_id on object_field(object_type_id)");
    }

    eval {
        $DB->do("DESC `object_field`");
    };
    if ($@) {
        $DB->do("CREATE TABLE `object_field` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `object_type_id` int(11) NOT NULL,
            `name` varchar(50) NOT NULL,
            `description` text,
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
    #MinorImpact::log(7, "ending");
}

sub getCache {
    my $self = shift || {};
    my $params = shift || {};

    #MinorImpact::log(7, "starting");
    if (ref($self) eq "HASH") {
        $params = $self;
        $self = $MinorImpact::SELF;
    }

    my $local_params = cloneHash($params);
    my $method = $local_params->{method} || 'file';

    #MinorImpact::log(8, "\$method='$method'");

    if ($self->{CACHE}{$method}) {
        return $self->{CACHE}{$method};
    }

    my $cache;
    if ($method eq 'file') {
        $cache = new CHI( driver => "File", root_dir => "/tmp/cache/" );
    } elsif ($method eq 'memcached') {
        delete($local_params->{method});
        return getCache($local_params) unless ($self->{conf}{default}{memcached_server});
        #MinorImpact::log(8, "memcached_server='" . $self->{conf}{default}{memcached_server} . "'");
        #$cache = new CHI( driver => "Memcached::libmemcached", servers => [ $self->{conf}{default}{memcached_server} . ":11211" ], #l1_cache => { driver => 'FastMmap', root_dir => '/path/to/root' }
        #$cache = new CHI( driver => "Cache::Memcached", servers => [ $self->{conf}{default}{memcached_server} . ":11211" ] );
        $cache = new Cache::Memcached({ servers => [ $self->{conf}{default}{memcached_server} . ":11211" ] });
    }

    $self->{CACHE}{$method} = $cache if ($cache);

    #MinorImpact::log(7, "ending");
    return $cache;
}

# Return the templateToolkit object;
sub getTT {
    my $self = shift || {};
    my $params = shift || {};

    #MinorImpact::log(7, "starting");

    if (ref($self) eq "HASH") {
        $params = $self;
        $self = $MinorImpact::SELF;
    }

    if ($self->{TT}) {
        return $self->{TT};
    }

    my $template_directory = $params->{template_directory} || $self->{conf}{default}{template_directory};

    # The default package templates are in the 'template' directory 
    # in the libary.  Find it, and use it as the secondary template location.
    (my $package = __PACKAGE__ ) =~ s#::#/#g;
    my $filename = $package . '.pm';

    (my $path = $INC{$filename}) =~ s#/\Q$filename\E$##g; # strip / and filename
    my $global_template_directory = File::Spec->catfile($path, "$package/template");

    my $variables = {
                        home => $self->{conf}{default}{home_script},
                        script_name => MinorImpact::scriptName(),
                        typeName => sub { MinorImpact::Object::typeName(shift); },
                        user => $self->getUser(),
                    };
    if ($params->{variables}) {
        foreach my $key (keys %{$params->{variables}}) {
            $variables->{$key} = $params->{variables}{$key};
        }
    }

    my $TT = Template->new({
        INCLUDE_PATH => [ $template_directory, $global_template_directory ],
        INTERPOLATE => 1,
        VARIABLES => $variables,
    }) || die $TT->error();

    $self->{TT} = $TT;
    
    #MinorImpact::log(7, "ending");
    return $TT;
}

sub templateToolkit {
    my $self = shift || return;

    return $self->getTT();
}

# TEST: Something I'm thinking about; some of the functionality of cgi scripts can be handled
#   by the MinorImpact object, reducing code reuse.
sub cgi {
    my $self = shift || return;
    my $params = shift || {};

    my $CGI = MinorImpact::getCGI();
    my $action = $CGI->param('a') || $CGI->param('action') || 'index';
    #my $script = $params->{script} || 'index';
    my $object_id = $CGI->param('id') || $CGI->param('object_id');

    #$action = 'index' if ($object_id && ($action eq 'list' || $action eq 'view'));

    MinorImpact::log(8, "\$action='$action'");

    if ($params->{actions}{$action}) {
        #MinorImpact::log(8, "\$params->{actions}{$action}='" . $params->{actions}{$action} . "'");
        my $sub = $params->{actions}{$action};
        $sub->($self, $params);
    } elsif ( $action eq 'add') {
        MinorImpact::CGI::add($self, $params);
    } elsif ( $action eq 'add_reference') {
        MinorImpact::CGI::add_reference($self, $params);
    } elsif ( $action eq 'collections') {
        MinorImpact::CGI::collections($self, $params);
    } elsif ( $action eq 'css') {
        MinorImpact::CGI::css($self, $params);
    } elsif ( $action eq 'delete') {
        MinorImpact::CGI::del($self, $params);
    } elsif ( $action eq 'edit') {
        MinorImpact::CGI::edit($self, $params);
    } elsif ( $action eq 'login') {
        MinorImpact::CGI::login($self, $params);
    } elsif ( $action eq 'logout') {
        MinorImpact::CGI::logout($self, $params);
    } elsif ( $action eq 'object_types') {
        MinorImpact::CGI::object_types($self);
    } elsif ( $action eq 'register') {
        MinorImpact::CGI::register($self, $params);
    } elsif ( $action eq 'save_search') {
        MinorImpact::CGI::save_search($self, $params);
    } elsif ( $action eq 'tablist') {
        MinorImpact::CGI::tablist($self, $params);
    } elsif ( $action eq 'tags') {
        MinorImpact::CGI::tags($self, $params);
    } elsif ( $action eq 'user') {
        MinorImpact::CGI::user($self);
    } else {
        MinorImpact::CGI::index($self, $params);
    }
}

1;
