package MinorImpact::User;

use strict;

use MinorImpact;
use MinorImpact::Util;

=head1 NAME

MinorImpact::User

=head1 SYNOPSIS

  use MinorImpact;
  
  my $MINORIMPACT = new MinorImpact();
  
  # Get the current user.
  my $user = $MINORIMPACT->user();
  if (!$user) {
      die "No currently logged in user.";
  }

=head1 DESCRIPTION

The object representing application users.

=head1 METHODS

=cut

sub new {
    my $package = shift;
    my $params = shift;

   #MinorImpact::log('info', "starting");

    my $self = {};

    $self->{DB} = $MinorImpact::SELF->{USERDB} || die "User database is not defined.";

    dbConfig($self->{DB});

    my $user_id = $params;
    #MinorImpact::log(8 "\$user_id='$params'");

    my $data = MinorImpact::cache("user_data_$user_id");
    unless ($data) {
        if ($user_id =~/^\d+$/) {
            $data = $self->{DB}->selectrow_hashref("SELECT * FROM user WHERE id   = ?", undef, ($user_id));
        } else {
            $data = $self->{DB}->selectrow_hashref("SELECT * FROM user WHERE name = ?", undef, ($user_id));
        }
        return unless $data;
        MinorImpact::cache("user_data_$user_id", $data);
    }
    $self->{data} = $data;
    bless($self, $package);

    #MinorImpact::log(8 "created user: '" .$self->name() . "'");
    return $self;
}

sub addUser {
    my $params = shift || return;
    
    #MinorImpact::log('info', "starting");

    my $DB = $MinorImpact::SELF->{USERDB};
    if ($DB && $params->{username}) {
        # Only the first 8 characters matter to crypt(); disturbing and weird.
        $DB->do("INSERT INTO user (name, password, create_date) VALUES (?, ?, NOW())", undef, ($params->{'username'}, crypt($params->{'password'}||"", $$))) || die $DB->errstr;
        my $user_id = $DB->{mysql_insertid};
        #MinorImpact::log('debug', "\$user_id=$user_id");
        return new MinorImpact::User($user_id);
    }
    die "Couldn't add user " . $params->{username};

    #MinorImpact::log('info', "ending");
    return;
}

sub dbConfig {
    my $DB = shift || return;

    eval {
        $DB->do("DESC `user`") || die $DB->errstr;
    };
    if ($@) {
        MinorImpact::log('notice', $@);
        $DB->do("CREATE TABLE `user` (
                `id` int(11) NOT NULL AUTO_INCREMENT,
                `name` varchar(50) NOT NULL,
                `password` varchar(255) NOT NULL,
                `test` varchar(255) DEFAULT NULL,
                `admin` tinyint(1) DEFAULT NULL,
                `create_date` datetime NOT NULL,
                `mod_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (`id`)
            )") || die $DB->errstr;
        $DB->do("create unique index idx_user_name on user(name)") || die $DB->errstr;
    }
}

sub count {
    my $params = shift || {};

    my $DB = $MinorImpact::SELF->{USERDB} || die "User database is not defined.";

    my $sql = "SELECT count(*) FROM user WHERE id > 0";
    my @fields = ();
    if ($params->{name}) {
        $sql .= " AND name LIKE ?";
        push(@fields, $params->{name});
    }
    my $users = $DB->selectrow_array($sql, undef, @fields) || die $DB->errstr;
    return $users;
}

sub delete {
    my $self = shift || return;
    my $params = shift || {};
    
    #MinorImpact::log('debug', "starting(" . $self->id() . ")");
    my $user_id = $self->id();
    # This is the user object, note the MinorImpact object, so DB is already set to USERDB.
    my $DB = $self->{DB};
    my @object_ids = $self->searchObjects({ query => { id_only => 1, debug => 'MinorImpact::User::delete();' } });
    my $object_count = scalar(@object_ids);
    #MinorImpact::log('debug', "\$object_count='$object_count'");
    my $deleted = 0;
    foreach my $object_id (@object_ids) {
        my $object = new MinorImpact::Object($object_id);
        if ($object) {
             MinorImpact::log('info', "deleting object " . $object->name());
            $object->delete($params);
            $deleted++;
        }
    }
    if ($object_count == $deleted) {
        MinorImpact::log('info', "deleting user $user_id");
        MinorImpact::cache("user_data_$user_id", {});
        $DB->do("DELETE FROM user WHERE id=?", undef, ($user_id)) || die $DB->errstr;
    }
    #MinorImpact::log('debug', "ending");
}

sub form {
    my $self = shift || return;

    my $field;
    my $form;
   
    #MinorImpact::log('debug', "\$self->get('email')='" . $self->get('email') . "'");
    $field = new MinorImpact::Object::Field({ name => 'email', type => 'string', value => $self->get('email') });
    $form .= $field->rowForm();
    return $form;
}

=head2 get($field)

Returns the value of $field.

=cut

sub get {
    my $self = shift || return;
    my $name = shift || return;

    return $self->{data}->{$name};
}

sub getCollections {
    my $self = shift || return;
    my $params = shift || {};

    my $collections = MinorImpact::cache("user_collections_" . $self->id());
    unless ($collections) {
        my $local_params = cloneHash($params);
        $local_params->{query} ||= {};
        $local_params->{query} = { 
                            %{$local_params->{query}},
                            debug          => 'MinorImpact::User::getCollections();',
                            id_only        => 1,
                            object_type_id => MinorImpact::Object::typeID('MinorImpact::collection'), 
                            user_id        => $self->id(),
                        };
        my @collections = MinorImpact::Object::Search::search($local_params);
        $collections = \@collections;
        MinorImpact::cache("user_collections_" . $self->id(), $collections);
    }
    return map { new MinorImpact::Object($_); } @$collections; 
}

sub getObjects {
    my $self = shift || return;
    my $params = shift || {};

    my @objects = $self->searchObjects({ query => { 
                                            %{$params->{query}
                                         },
                                         debug => 'MinorImpact::User::getObjects();', 
                                         user => $self->id() 
                                       } 
                                   });
    return @objects;
}

=head2 id()

Returns the user's ID.

=cut

sub id { 
    return shift->{data}->{id}; 
} 

=head2 isAdmin()

Returns TRUE if the user has administrative priviledges for this application.

=cut

sub isAdmin {
    my $self = shift || return;
    #MinorImpact::log('info', "starting");
    #MinorImpact::log('info', "ending");
    return $self->get('admin');
}

=head2 name() 

Returns the user's 'name' field.  A shortcut to get('name').

=cut 

sub name { 
    return shift->get('name'); 
}

=head2 search(\%params)

A passthru function that appends the user_id of the user object to to the query 
hash of %params.

=cut

sub search {
    my $params = shift || {};

    my $DB = $MinorImpact::SELF->{USERDB} || die "User database is not defined.";

    my $sql = "SELECT id FROM user WHERE id > 0";
    my @fields = ();
    if ($params->{name}) {
        $sql .= " AND name LIKE ?";
        push(@fields, $params->{name});
    }

    if ($params->{order_by}) {
        $sql .= " ORDER BY " . $params->{order_by};
    }
    if ($params->{limit}) {
        $sql .= " LIMIT ?";
        push(@fields, $params->{limit});
    }
        
    MinorImpact::log('info', "$sql, (" . join(',', @fields) . ")");
    my $users = $DB->selectall_arrayref($sql, {Slice=>{}}, @fields) || die $DB->errstr;
    return map { $_->{id}; } @$users if ($params->{id_only});

    return map { new MinorImpact::User($_->{id}); } @$users;
}

sub searchObjects { 
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log('debug', "starting(" . $self->id() . ")");

    my $local_params = cloneHash($params);

    $local_params->{query} ||= {};
    $local_params->{query}{user_id} = $self->id();
    $local_params->{query}{debug} .= "MinorImpact::User::searchObjects();";

    my @results = MinorImpact::Object::Search::search($local_params);

    #MinorImpact::log('debug', "ending");
    return @results;
}

=head2 settings()

Returns the user's MinorImpact::settings object.

  $settings = $user->settings();

=cut

sub settings {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log('debug', "starting(" . $self->id() . ")");

    my $local_params = {};
    $local_params->{query} ||= {};
    $local_params->{query}{object_type_id} = MinorImpact::Object::typeID('MinorImpact::settings');
    $local_params->{query}{debug} .= "MinorImpact::User::settings();";
    my @settings = $self->searchObjects($local_params);
    my $settings = $settings[0];
    unless ($settings) {
        eval {
            $settings = new MinorImpact::settings({ name => $self->name(), user_id => $self->id() }) || die "Can't create settings object.";
        };
        MinorImpact::log('notice', $@) if ($@);
    }

    #MinorImpact::log('debug', "ending");
    return $settings;
}

=head2 update(\%fields)

Update one or more user fields.

=cut

sub update {
    my $self = shift || return;
    my $params = shift || return;

    MinorImpact::cache("user_data_" . $self->id(), {});
    $self->{DB}->do("UPDATE user SET name=?, password=? WHERE id=?", undef, ($params->{name}, $self->id())) || die $self->{DB}->errstr if ($params->{name});
    $self->{DB}->do("UPDATE user SET email=? WHERE id=?", undef, ($params->{email}, $self->id())) || die $self->{DB}->errstr if ($params->{email});
    $self->{DB}->do("UPDATE user SET password=? WHERE id=?", undef, (crypt($params->{password}, $$), $self->id())) || die $self->{DB}->errstr if ($params->{password} && $params->{confirm_password} && $params->{password} eq $params->{confirm_password});
}

=head2 validateUser($password)

Returns TRUE if $password is valid.

  # Check if the user's password is "password".
  if ($user->validateUser("password")) {
      print "This is a bad password\n";
  }

=cut

sub validateUser {
    my $self = shift || return;

    my $password = shift || '';

    return (crypt($password, $self->{data}->{password}) eq $self->{data}->{password});
}

=head1 AUTHOR

Patrick Gillan <pgillan@minorimpact.com>

=cut

1;
