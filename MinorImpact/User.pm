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
  my $USER = $MINORIMPACT->user();
  if (!$USER) {
      die "No currently logged in user.";
  }

=head1 DESCRIPTION

The object representing application users.

=head1 METHODS

=cut

sub new {
    my $package = shift;
    my $params = shift;

    MinorImpact::log('debug', "starting");

    my $self = {};

    $self->{DB} = MinorImpact::userDB() || die "User database is not defined.";

    dbConfig($self->{DB});

    my $user_id = $params;
    MinorImpact::log('debug', "\$user_id='$params'");

    my $data = MinorImpact::cache("user_data_$user_id");
    MinorImpact::log('debug', "1 \$data->{name}='" . $data->{name} . "'");
    unless ($data->{id}) {
        if ($user_id =~/^\d+$/) {
            MinorImpact::log('debug', "searching database by id");
            $data = $self->{DB}->selectrow_hashref("SELECT * FROM user WHERE id   = ?", undef, ($user_id));
        } else {
            MinorImpact::log('debug', "searching database by name");
            $data = $self->{DB}->selectrow_hashref("SELECT * FROM user WHERE name = ?", undef, ($user_id));
        }
        MinorImpact::log('debug', "2 \$data->{name}='" . $data->{name} . "'");
        return unless $data;
        MinorImpact::cache("user_data_$user_id", $data);
    }
    return unless ($data->{id});

    $self->{data} = $data;
    bless($self, $package);

    MinorImpact::log('debug', "created user: '" . $self->name() . "'");
    return $self;
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

=head2 delete

=over

=item delete(\%params)

=back

Delete the user and all of the objects owned by that user.

  $USER->delete();

=cut

sub delete {
    my $self = shift || return;
    my $params = shift || {};
    
    MinorImpact::log('debug', "starting(" . $self->id() . ")");
    my $user = MinorImpact::user();
    die "Invalid user\n" unless ($user);
    die "Not an admin user\n" unless ($user->isAdmin());
    my $user_id = $self->id();
    my $username = $self->name();
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
        $DB->do("DELETE FROM user WHERE id=?", undef, ($user_id)) || die $DB->errstr;
    } else {
        die "object_count:$object_count does not match deleted count:$deleted";
    }

    MinorImpact::cache("user_data_$user_id", {});
    MinorImpact::cache("user_data_$username", {});
    MinorImpact::log('debug', "ending");
    return 1;
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

=head2 get

=over

=item get($field)

=back

Returns the value of $field.

  $address = $USER->get('address');

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

=head2 id

Returns the user's ID.

  $id = $USER->id();

=cut

sub id { 
    return shift->{data}->{id}; 
} 

=head2 isAdmin

Returns TRUE if the user has administrative priviledges for this application.

  if ($USER->isAdmin()) {
      # Go nuts
  } else {
      # Go away
  }

=cut

sub isAdmin {
    my $self = shift || return;
    #MinorImpact::log('info', "starting");
    #MinorImpact::log('info', "ending");
    return $self->get('admin');
}

=head2 name

Returns the user's 'name' field.  A shortcut to get('name').

  $name = $USER->name();
  # ... is equivalent to:
  $name = $USER->get('name');

=cut 

sub name { 
    return shift->get('name'); 
}

=head2 searchObjects

=over

=item searchObjects()

=item searchObjects(\%params)

=back

A shortcut to L<MinorImpact::Object::Search::search()|MinorImpact::Object::Search/search> that
adds the current user_id to the parameter list.

  @objects = $USER->searchObjects({name => '%panda% });
  # ... is equivalent to:
  @objects = MinorImpact::Object::Search::search({ name => '%panda%', user_id=>$USER->id() });

=cut

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

=head2 settings

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

=head2 update

=over

=item update(\%fields)

=back

Update one or more user fields.

  $USER->update({name => "Sting", address => "6699 Tantic Ave." });

=cut

sub update {
    my $self = shift || return;
    my $params = shift || return;

    MinorImpact::log('debug', "starting");
    MinorImpact::cache("user_data_" . $self->id(), {});
    MinorImpact::cache("user_data_" . $self->name(), {});

    my $user = MinorImpact::user();
    die "Invalid user\n" unless ($user->id() == $self->id() || $user->isAdmin());
    if (defined($params->{admin})) {
        MinorImpact::log('debug', "Updating admin priviledges");
        die "Not an admin user\n" unless ($user->isAdmin());
        $self->{DB}->do("UPDATE user SET admin=? WHERE id=?", undef, (isTrue($params->{admin}), $self->id())) || die $self->{DB}->errstr;
    }
    $self->{DB}->do("UPDATE user SET email=? WHERE id=?", undef, ($params->{email}, $self->id())) || die $self->{DB}->errstr if ($params->{email});
    $self->{DB}->do("UPDATE user SET name=?, password=? WHERE id=?", undef, ($params->{name}, $self->id())) || die $self->{DB}->errstr if ($params->{name});
    $self->{DB}->do("UPDATE user SET password=? WHERE id=?", undef, (crypt($params->{password}, $$), $self->id())) || die $self->{DB}->errstr if ($params->{password} && $params->{confirm_password} && $params->{password} eq $params->{confirm_password});

    MinorImpact::log('debug', "ending");
}

=head2 validateUser

=over

=item validateUser($password)

=back

Returns TRUE if $password is valid.

  # Check if the user's password is "password".
  if ($user->validateUser("password")) {
      print "This is a bad password\n";
  }

=cut

sub validateUser {
    my $self = shift || return;
    MinorImpact::log('debug', "starting");

    my $password = shift || '';

    my $crypt = crypt($password, $self->{data}->{password});
    my $valid = 1 if ($crypt eq $self->{data}->{password});
    MinorImpact::log('debug', "User is " . ($valid?"valid":"invalid"));
    MinorImpact::log('debug', "ending");
    return $valid;
}

=head1 SUBROUTINES

=cut

=head2 addUser

=over

=item addUser(\%params)

=back

Add a MinorImpact user.

  $new_user = MinorImpact::User::AddUser({username => 'foo', password => 'bar' });

=head3 Settings

=over

=item admin

Make the user an admin.

=item password

The new user's password.

=item username

The new user's login name.

=back

=cut

sub addUser {
    my $params = shift || return;
    
    MinorImpact::log('debug', "starting");

    my $DB = $MinorImpact::SELF->{USERDB};
    if ($DB && $params->{username}) {
        $params->{admin} ||= 0;
        # Only the first 8 characters matter to crypt(); disturbing and weird.
        if ($params->{admin}) {
            my $user = MinorImpact::user();
            unless ($user && $user->isAdmin()) {
                die "Only an admin user can add an admin user\n";
            }
        }
        $DB->do("INSERT INTO user (name, password, admin, create_date) VALUES (?, ?, ?, NOW())", undef, ($params->{'username'}, crypt($params->{'password'}||"", $$), $params->{admin})) || die $DB->errstr;
        my $user_id = $DB->{mysql_insertid};
        #MinorImpact::log('debug', "\$user_id=$user_id");
        return new MinorImpact::User($user_id);
    }
    die "Couldn't add user " . $params->{username};

    MinorImpact::log('debug', "ending");
    return;
}

=head2 count

=over

=item count()

=item count(\%params)

=back

A shortcut to L<MinorImpact::User::search()|MinorImpact::User/search>
that returns the number of results.  With no arguments, returns the 
total number of MinorImpact users.  With arguments, returns the number
of users matching the given criteria.

  # get the number of admin users
  $num_users = MinorImpact::Users::count({ admin => 1 });

=cut

sub count {
    my $params = shift || {};

    return scalar(search($params));
}


=head2 search

=over

=item search(\%params)

=back

Search the database for users that match.

=head3 Parameters

=over

=item admin

Return admin users.

  @users = MinorImpact::User::search({name => "% Smith" });

=item limit

Limit to X number of results.

  @users = MinorImpact::User::search({name => "% Smith", limit => 5 });

=item name

Search for users by name.  Supports MySQL wildcards.

  @users = MinorImpact::User::search({name => "% Smith" });

=item order_by

Return returns sorted by a particular columnn.

=back

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
    if (isTrue($params->{admin})) {
        $sql .= " AND admin IS TRUE";
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


=head1 AUTHOR

Patrick Gillan <pgillan@minorimpact.com>

=cut

1;
