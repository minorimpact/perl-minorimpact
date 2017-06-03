package MinorImpact;

use DBI;
use CGI;
use Time::Local;
use Data::Dumper;
use Time::HiRes qw(tv_interval gettimeofday);
use URI::Escape;

use MinorImpact::BinLib;
use MinorImpact::Config;
use MinorImpact::Object;
use MinorImpact::User;
use MinorImpact::Util;

#$SELF = new MinorImpact;

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
    MinorImpact::log(8, "starting");

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

        if ($confg->{user_db}) {
            my $dsn = "DBI:mysql:database=$config->{db}->{database};host=$config->{db}->{db_host};port=$config->{db}->{port}";
            $self->{USERDB} = DBI->connect($dsn, $config->{db}->{db_user}, $config->{db}->{db_password}, {RaiseError=>1, mysql_auto_reconnect=>1}) || die("Can't connect to database");
        } else {
            $self->{USERDB} = $self->{DB};
        }
        $self->{CGI} = new CGI;

        $SELF = $self;
        $self->{starttime} = [gettimeofday];
    }


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
        $self->redirect("https://$ENV{HTTP_HOST}/cgi-bin/login.cgi");
    }

    MinorImpact::log(8, "ending");
    return $self;
}

sub validUser {
    my $self = shift || return;
    my $params = shift || {};

    return $self->getUser($params);
}

sub getUser {
    MinorImpact::log(7, "starting");
    my $self = shift || return;
    my $params = shift || {};

    my $CGI = $self->{CGI};

    my $user_id = $CGI->cookie("user_id");
    if ($user_id) {
        MinorImpact::log(8, "user_id=$user_id");
        my $user = new MinorImpact::User($user_id);

        my $client_ip = MinorImpact::cache({key=>"client_ip:$user_id"});
        MinorImpact::log(8, "client_ip=$client_ip");
        if ($user && $client_ip) {
            MinorImpact::log(8, "\$ENV{REMOTE_ADDR}=$ENV{REMOTE_ADDR}");
            if ($client_ip && $ENV{REMOTE_ADDR} eq $client_ip) {
                MinorImpact::log(7, "ending");
                return $user;
            }
        }
    }

    if ($CGI->param('username') && $CGI->param('password')) {
        MinorImpact::log(3, "validating " . $CGI->param('username'));
        my $user = new MinorImpact::User($CGI->param('username'));
        if ($user && $user->validate_user($CGI->param('password'))) {
            my $user_id = $user->id();
            my $cookie =  $CGI->cookie(-name=>'user_id', -value=>$user_id);
            foreach my $key (keys %ENV) {
                MinorImpact::log(8, "\$ENV{$key}='$ENV{$key}'");
            }
            MinorImpact::cache({key=>"client_ip:$user_id", value=>$ENV{REMOTE_ADDR}, timeout=>7200});
            #print "Content-type: text/html\n\n";
            #print $CGI->header(-cookie=>$cookie);
            print "Set-Cookie: $cookie\n";
            MinorImpact::log(7, "ending");
            return $user;
        }
    }

    if ($ENV{'USER'}) {
        MinorImpact::log(8, "\$ENV{'user'}=$ENV{'user'}");
        my $user = new MinorImpact::User($ENV{'user'});
        MinorImpact::log(7, "ending");
        return $user;
    }
    MinorImpact::log(3, "no user found");
    MinorImpact::log(7, "ending");
    return;
}

sub redirect {
    my $self = shift || return;

    MinorImpact::log(7, "starting");
    my $location = shift || $self->{CGI}->param('redirect') ||  'index.cgi';

    #$location =~s/[^a-z0-9.\-_?\/:=]//;
    #$location = uri_escape($location);
    if ($location !~/^\//) {
        $location = "/cgi-bin/$location";
    }

    #print $self->{CGI}->header(-location=>$location);
    MinorImpact::log(3, "redirecting to $location");
    print "Location: $location\n\n";
    MinorImpact::log(7, "ending");
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
    MinorImpact::log(8, "starting");

    my $title = $args->{title} || '';
    my $javascript = $args->{javascript} || '';
    my $css = $args->{css} || '';
    my $other = $args->{other} || '';

    unless ($title) {
        $title = $0;
        $title =~s/^.+\/([^\/]+).cgi$/$1/;
        $title = ucfirst($title);
    }

    MinorImpact::log(3, "getting user");
    my $user = $self->getUser();

    my $header = qq(Content-type: text/html\n\n

<!DOCTYPE html>
<head>
    <title>$title</title>
    <link rel="stylesheet" type="text/css" href="/minorimpact.css">
    <link rel="stylesheet" type="text/css" href="/jquery-ui-1.11.4/jquery-ui.css">
    <link rel="stylesheet" type="text/css" href="/jquery-ui-1.11.4/jquery-ui.structure.css">
    <link rel="stylesheet" type="text/css" href="/jquery-ui-1.11.4/jquery-ui.theme.css">
    <script src="/jquery-2.1.4.js"></script>
    <script src="/jquery-ui-1.11.4/jquery-ui.js"></script>
    <!-- start \$other -->
        $other
    <!-- end \$other -->
    <style type='text/css'>
        $css
    </style>
    <script>
        $javascript
    </script>
</head>
<body>
    <div id=header>
        <table width=100%>
        <tr>
            <td valign=top>
        <div id=section_menu>
    );
    if ($user) {
        $header .= qq(
                <a href=/cgi-bin/index.cgi>Projects</a>
        );
        if ($user->isAdmin()) {
            $header .= qq(
                    <a href=/cgi-bin/object_admin.cgi>Admin</a>
            );
        }
    }
    $header .= qq(
        </div> <!-- section_menu -->
        </td>
        <td valign=top>
        <div id=user_menu>
    );
    if ($user) {
        $header .= qq(
            <table>
                <tr>
                    <td valign=top><form id=search_form action="search.cgi" onsubmit="window.location='search.cgi?search=' + this.search.value;"><input type=text id=search name=search></form></td>
                    <td valign=top><a href="user.cgi?user_id=${\ $user->id(); }">${\ $user->get('name'); }</a><a href=logout.cgi>Logout</a></td>
                </tr>
            </table>
        );
    } else {
        $header .= qq(
            <a href=login.cgi>Log In</a>
        );
    }
    $header .= qq(
        </div> <!-- user_menu -->
        </td>
        </tr>
        </table>
    </div> <!-- header -->
    );
    MinorImpact::log(8, "ending");
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

    my $log = "$date: $$: $level: $sub: $message\n";
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
    if (-f "/tmp/debug" && $user->isAdmin()) {
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

1;
