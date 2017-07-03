package MinorImpact::User;

use MinorImpact;

sub new {
    my $package = shift;
    my $params = shift;

    MinorImpact::log(7, "starting");

    my $self = {};

    $self->{DB} = $MinorImpact::SELF->{USERDB} || die "User database is not defined.";

    checkDatabaseTables($self->{DB});

    my $user_id = $params;
    MinorImpact::log(8, "\$user_id='$params'");

    if ($user_id =~/^\d+$/) {
        $self->{data} = $self->{DB}->selectrow_hashref("SELECT * FROM user WHERE id = ?", undef, ($user_id)) || return;
    } else {
        $self->{data} = $self->{DB}->selectrow_hashref("SELECT * FROM user WHERE name = ?", undef, ($user_id)) || return;
    }
    bless($self, $package);

    MinorImpact::log(8, "created user: '" .$self->name() . "'");
    return $self;
}

sub checkDatabaseTables {
    my $DB = shift || return;

    eval {
        $DB->do("DESC `user`") || die $DB->errstr;
    };
    if ($@) {
        $DB->do("CREATE TABLE `user` (
                `id` int(11) NOT NULL AUTO_INCREMENT,
                `name` varchar(25) NOT NULL,
                `password` varchar(255) NOT NULL,
                `test` varchar(255) DEFAULT NULL,
                `admin` tinyint(1) DEFAULT NULL,
                `create_date` datetime NOT NULL,
                `mod_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (`id`)
            ) ENGINE=MyISAM AUTO_INCREMENT=3 DEFAULT CHARSET=latin1") || die $DB->errstr;
        $DB->do("create unique index idx_user_name on user(name)") || die $DB->errstr;
    }
}

sub validate_user {
    my $self = shift || return;

    my $password = shift || return;

    return (crypt($password, $self->{data}->{password}) eq $self->{data}->{password});
}

sub addUser {
    my $params = shift || return;
    
    MinorImpact::log(7, "starting");

    my $DB = $MinorImpact::SELF->{USERDB};
    if ($DB && $params->{username} && $params->{password}) {
        $DB->do("INSERT INTO user (name, password, create_date) VALUES (?, ?, NOW())", undef, ($params->{'username'}, crypt($params->{'password'}, $$))) || die $DB->errstr;
        my $user_id = $DB->{mysql_insertid};
        MinorImpact::log(8, "\$user_id=$user_id");
        return new MinorImpact::User($user_id);
    }
    die "Couldn't add user " . $params->{username};
    return;
}

sub id {
    my $self = shift || return;

    return $self->{data}->{id};
}

sub name {
    my $self = shift || return;

    return $self->{data}->{name};
}

sub get {
    my $self = shift || return;
    my $name = shift || return;

    return $self->{data}->{$name};
}

sub update {
    my $self = shift || return;
    my $params = shift || return;

    $self->{DB}->do("UPDATE user SET name=?, password=? WHERE id=?", undef, ($params->{'name'}, crypt($params->{'password'}, $$), $self->id()));
}

sub isAdmin {
    my $self = shift || return;
    #MinorImpact::log(7, "starting");
    #MinorImpact::log(7, "ending");
    return $self->get('admin');
}

1;
