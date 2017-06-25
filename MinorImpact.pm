package MinorImpact;

use DBI;
use CGI;
use Time::Local;
use Data::Dumper;
use Time::HiRes qw(tv_interval gettimeofday);
use URI::Escape;
use Template;
use Cwd;
use File::Spec;

use MinorImpact::BinLib;
use MinorImpact::Config;
use MinorImpact::Object;
use MinorImpact::User;
use MinorImpact::Util;

sub getDB { return $SELF->{DB}; }
sub getCGI { return $SELF->{CGI}; }
sub scriptName {
    my ($script_name) = $0 =~/\/([^\/]+.cgi)$/;
    return $script_name;
}

sub new {
    my $package = shift;
    my $options = shift || {};

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

        $SELF = $self;
        $self->{starttime} = [gettimeofday];
    }
    checkDatabaseTables($self->{DB});

    if ($options->{validUser} || $options->{user_id} || $options->{admin}) {
        my ($script_name) = scriptName();
        my $user = $self->getUser();
        if ($user) {
            if ($options->{user_id} && $user->id() != $options->{user_id}) {
                MinorImpact::log(3, "logged in user doesn't match");
                $self->redirect("login.cgi?redirect=$script_name");
            } elsif ($options->{admin} && !$user->isAdmin()) {
                MinorImpact::log(3, "not an admin user");
                $self->redirect("login.cgi?redirect=$script_name");
            }
        } else {
            MinorImpact::log(3, "no logged in user");
            $self->redirect("login.cgi?redirect=$script_name");
        }
    }
    if ($options->{https} && $ENV{HTTPS} ne 'on') {
        MinorImpact::log(3, "not https");
        $self->redirect();
    }

    #MinorImpact::log(8, "ending");
    return $self;
}

sub validUser {
    my $self = shift || return;
    my $params = shift || {};

    return $self->getUser($params);
}

sub getUser {
    #MinorImpact::log(7, "starting");
    my $self = shift || return;
    my $params = shift || {};

    my $CGI = $self->{CGI};

    my $user_id = $CGI->cookie("user_id") || MinorImpact::cache({key=>'user_id'});
    if ($user_id) {
        #MinorImpact::log(8, "user_id=$user_id");
        my $user = new MinorImpact::User($user_id);

        my $client_ip = MinorImpact::cache({key=>"client_ip:$user_id"});
        #MinorImpact::log(8, "client_ip=$client_ip");
        if ($user && $client_ip) {
            #MinorImpact::log(8, "\$ENV{REMOTE_ADDR}=$ENV{REMOTE_ADDR}");
            if ($client_ip && $ENV{REMOTE_ADDR} eq $client_ip) {
                #MinorImpact::log(7, "ending");
                return $user;
            } elsif ($client_ip && $ENV{SSH_CLIENT} eq $client_ip) {
                return $user;
            }
        }
    }

    my $username = $params->{username} || $CGI->param('username') || $ENV{USER};
    my $password = $params->{password} || $CGI->param('password');

    if ($username && $password) {
        MinorImpact::log(3, "validating " . $username);
        my $user = new MinorImpact::User($username);
        if ($user && $user->validate_user($password)) {
            my $user_id = $user->id();
            my $timeout = $self->{conf}{default}{user_timeout} || 86400;

            MinorImpact::cache({key=>"client_ip:$user_id", value=>$ENV{REMOTE_ADDR}||$ENV{SSH_CLIENT}, timeout=>$timeout});
            if ($ENV{REMOTE_ADDR}) {
                my $cookie =  $CGI->cookie(-name=>'user_id', -value=>$user_id);
                print "Set-Cookie: $cookie\n";
            } else {
                # TODO: This only supports a single command line connection at a time.  Might be a
                #   problem in the future.
                MinorImpact::cache({key=>"user_id", value=>$user_id, timeout=>$timeout});
            }
            #MinorImpact::log(7, "ending");
            return $user;
        }
    }

    if ($ENV{'USER'}) {
        #MinorImpact::log(8, "\$ENV{'user'}=$ENV{'user'}");
        my $user = new MinorImpact::User($ENV{'user'});
        #MinorImpact::log(7, "ending");
        return $user;
    }
    MinorImpact::log(3, "no user found");
    #MinorImpact::log(7, "ending");
    return;
}

sub redirect {
    my $self = shift || return;

    #MinorImpact::log(7, "starting");
    my $location = shift || $self->{CGI}->param('redirect') ||  'index.cgi';

    #$location =~s/[^a-z0-9.\-_?\/:=]//;
    #$location = uri_escape($location);
    my $domain = "https://$ENV{HTTP_HOST}";
    if ($location =~/^\//) {
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

# return standard page header
# args:
#   title - text for the <title> block. defaults to script name.
#   javascript - code for the <script> block
#   css - content for the <style> block
#   other - other miscellaneous output to be added to the <header> block
sub header {
    my $self = shift || return;
    my $args = shift || {};
    #MinorImpact::log(8, "starting");

    my $title = $args->{title} || '';
    my $javascript = $args->{javascript} || '';
    my $css = $args->{css} || '';
    my $other = $args->{other} || '';
    my $script_name = $args->{script_name} || scriptName();
    my $blank = $args->{blank};
    my $content_type = $args->{content_type} || "text/html";
    my $template = $args->{template} || 'header';

    unless ($title) {
        $title = $0;
        $title =~s/^.+\/([^\/]+).cgi$/$1/;
        $title = ucfirst($title);
    }

    MinorImpact::log(3, "getting user");
    my $user = $self->getUser();

    print qq(Content-type: $content_type\n\n);
    unless ($args->{blank}) {
        my $TT = MinorImpact::getTT({template_config_file=>$self->{conf}{default}{template_config_file}});
        $TT->process($template, {css=>$css, other=>$other, javascript=>$javascript, title=>$title, user=>$user}) || die $TT->error();
    }
    #MinorImpact::log(8, "ending");
    return $header;
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

sub getEntries {
    my $self = shift || return;
    my $user = $self->getUser() || return;

    my @entries = ();
    foreach my $entry_id (Journal::Entry::_search({user_id=>$user->id()})) {
        push(@entries, new Journal::Entry($entry_id));
    }
    return @entries;
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
    open(LOG, ">>$file");
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
        if (defined($value) && $value ne '') {
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
    }
    return $value;
}

# return standard page footer
sub footer {
    my $self = shift || return;

    my $user = $self->getUser();

    my $client_ip;
    if ($user) {
       $client_ip = MinorImpact::cache({key=>"client_ip:" . $user->id()});
    } else {
        $client_ip = $ENV{'REMOTE_ADDR'};
    }

    my $elapsed = sprintf("%.3f", tv_interval ($self->{starttime}));

    my $footer = <<FOOTER;
    <div id=footer>
        $0, $client_ip, ${elapsed}s<br />
FOOTER
    foreach my $key (keys %ENV) {
        #$footer .= "$key='$ENV{$key}'<br />\n";
    }
    if (-f "/tmp/debug.log" && $user && $user->isAdmin()) {
        $footer .= "<pre>\n";
        $footer .= `tail -n 40 /tmp/debug.log| grep "$$:"`;
        $footer .= "</pre>\n";
    }
    $footer .= <<FOOTER;
    </div>
</body>
FOOTER
    return $footer;
}

sub types {
    return ();
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
  KEY `idx_object_data` (`object_id`))");
    }

    eval {
        $DB->do("DESC `object_tag`");
    };
    if ($@) {
        $DB->do("CREATE TABLE `object_tag` (
  `object_id` int(11) NOT NULL,
  `name` varchar(50) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1");
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
  PRIMARY KEY (`id`)
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

# Return the templateToolkit object;
sub getTT {
    my $self = shift || return;
    my $params = shift || {};

    my $template_directory = $params->{template_directory} || $self->{conf}{default}{template_directory};

    if ($TT) {
        return $TT;
    }

    # The default package templates are in the 'template' directory 
    # in the libary.  Find it, and use it as the secondary template location.
    (my $package = __PACKAGE__ ) =~ s#::#/#g;
    my $filename = $package . '.pm';

    (my $path = $INC{$filename}) =~ s#/\Q$filename\E$##g; # strip / and filename
    my $global_template_directory = File::Spec->catfile($path, "$package/template");

    $TT = Template->new({
        INCLUDE_PATH=> [ $template_directory, $global_template_directory ],
        INTERPOLATE => 1,
    }) || die $TT->error();
    return $TT;
}

sub templateToolkit {
    my $self = shift || return;

    return $self->getTT();
}

1;
