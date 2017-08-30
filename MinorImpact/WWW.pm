package MinorImpact::WWW;

use strict;

use JSON;

use MinorImpact;
use MinorImpact::Util;

=item1 NAME

MinorImpact::WWW

=item1 SYNOPSIS

=item1 METHODS

=over 4

=cut

=item add()

=cut

sub about {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    MinorImpact::tt('about');
}

sub add {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log('debug', "starting");

    my $CGI = $self->cgi();
    my $user = $self->user({ force => 1 });

    my $script_name = MinorImpact::scriptName();
    my $action = $CGI->param('action') || $CGI->param('a') || $self->redirect();
    my $object_type_id = $CGI->param('type_id') || $CGI->param('type') || $CGI->param('id') || $self->redirect();
    $object_type_id = MinorImpact::Object::typeID($object_type_id) if ($object_type_id);
    $self->redirect() if (MinorImpact::Object::isReadonly($object_type_id));

    my $object;
    my @errors;
    if ($CGI->param('submit') || $CGI->param('hidden_submit')) {
        my $params = $CGI->Vars;
        if ($action eq 'add') {
            #MinorImpact::log('debug', "submitted action eq 'add'");
            $params->{user_id} = $user->id();
            $params->{object_type_id} = $object_type_id;

            # Add the booleans manually, since unchecked values don't get 
            #   submitted.
            my $fields = MinorImpact::Object::fields($object_type_id);
            foreach my $name (keys %$fields) {
                if ($fields->{$name}->type() eq 'boolean' && !defined($params->{$name})) {
                    $params->{$name} = 0;
                }
            }
            eval {
                $object = new MinorImpact::Object($params);
            };
            push(@errors, $@) if ($@);
        }
        if ($object && !scalar(@errors)) {
            my $back = $object->back() || "$script_name?a=home&id=" . $object->id();
            $self->redirect($back);
        }
    }

    my $type_name = MinorImpact::Object::typeName({ object_type_id => $object_type_id });
    my $local_params = { object_type_id=>$object_type_id, no_cache => 1 };
    #MinorImpact::log('debug', "\$type_name='$type_name'");
    my $form;
    eval {
        $form = $type_name->form($local_params);
    };
    if ($@) {
        $form = MinorImpact::Object::form($local_params);
    }

    MinorImpact::tt('add', {
                        errors           => [ @errors ],
                        form             => $form,
                        object_type_name => $type_name,
                        object_type_id   => $object_type_id,
                    });
}

sub add_reference {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    my $user = $MINORIMPACT->user({ force => 1 });
    my $CGI = MinorImpact::cgi();
    my $DB = MinorImpact::db();
    my $script_name = MinorImpact::scriptName();

    my $object_id = $CGI->param('object_id');
    my $object_text_id = $CGI->param('object_text_id');
    my $data = $CGI->param('data');

    my $object = new MinorImpact::Object($object_id) || $MINORIMPACT->redirect();

    print "Content-type: text/plain\n\n";
    if ($object_text_id && $data && $object && $object->user_id() eq $user->id()) {
        $DB->do("INSERT INTO object_reference(object_text_id, data, object_id, create_date) VALUES (?, ?, ?, NOW())", undef, ($object_text_id, $data, $object->id())) || die $DB->errstr;
    }
}

sub admin {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    my $user = $MINORIMPACT->user({ force => 1 });
    $MINORIMPACT->redirect() unless ($user->isAdmin());

    my $CGI = $MINORIMPACT->cgi();

    MinorImpact::tt('admin');
}

sub collections {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    my $user = $MINORIMPACT->user({ force => 1 });

    #my @collections = sort { $a->cmp($b); } $user->getCollections();
    my @collections = $user->getCollections();
    MinorImpact::tt('collections', { collections => [ @collections ], });
}

sub contact {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    MinorImpact::tt('contact');
}

sub css {
    my $self = shift || return;
    my $params = shift || {};

    MinorImpact::tt('css');
}

sub del {
    my $self = shift || return;
    my $params = shift || {};

    my $CGI = $self->cgi();
    my $user = $self->user({ force => 1 });

    my $object_id = $CGI->param('id') || $CGI->param('object_id') || $self->redirect();
    my $object = new MinorImpact::Object($object_id) || $self->redirect();
    my $back = $object->back();

    $object->delete();
    $self->redirect($back);
}

sub delete_collection {
    my $self = shift || return;
    my $params = shift || {};

    my $CGI = $self->cgi();
    my $user = $self->user({ force => 1 });

    my $collection_id = $CGI->param('cid') || $self->redirect();

    my $collection = new MinorImpact::Object($collection_id);
    if ($collection && $collection->user_id() eq $user->id()) {
        $collection->delete();
    }

    $self->redirect({ action => 'collections' });
}

sub edit {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log('debug', "starting");
    my $local_params = cloneHash($params);
    $local_params->{no_cache} = 1;
    my $CGI = $self->cgi();
    my $user = $self->user({ force => 1 });
    my $script_name = MinorImpact::scriptName();

    my $search = $CGI->param('search');

    my $object_id = $CGI->param('id') || $CGI->param('object_id') || $self->redirect();
    my $object = new MinorImpact::Object($object_id, $local_params) || $self->redirect();
    $self->redirect($object->back()) if ($object->isReadonly());

    my @errors;
    if ($CGI->param('submit') || $CGI->param('hidden_submit')) {
        my $params = $CGI->Vars;
        # Add the booleans manually, since unchecked values don't get 
        #   submitted.
        my $fields = $object->fields();
        foreach my $name (keys %$fields) {
            if ($fields->{$name}->type() eq 'boolean' && !defined($params->{$name})) {
                $params->{$name} = 0;
            }
        }
        eval {
            $object->update($params);
        };
        if ($@) {
            my $error = $@;
            $error =~s/ at .+ line \d+.*$//;
            push(@errors, $error) if ($error);
        }

        if ($object && scalar(@errors) == 0) {
            my $back = $object->back() || "$script_name?a=object&id=" . $object->id();
            $self->redirect($back);
        }
    }

    my $form = $object->form($local_params);
    $self->tt('edit', { 
                        errors  => [ @errors ],
                        form    => $form,
                        object   =>$object,
                    });
    #MinorImpact::log('debug', "ending");
}

sub edit_settings {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    my $CGI = $MINORIMPACT->cgi();
    my $user = $MINORIMPACT->user({ force => 1 });
    my $settings = $user->settings();

    my @errors;
    if ($CGI->param('submit') || $CGI->param('hidden_submit')) {
        my $cgi_params = $CGI->Vars;
        eval {
            $settings->update($cgi_params);
        };
        if ($@) {
            my $error = $@;
            MinorImpact::log('notice', $error);
            $error =~s/ at .+ line \d+.*$//;
            push(@errors, $error) if ($error);
        }

        if (scalar(@errors) == 0) {
            $MINORIMPACT->redirect({ action => 'settings' });
        }
    }
    my $form = $settings->form();

    MinorImpact::tt('edit_settings', { 
                        errors  => [ @errors ],
                        form => $form,
    });
}

=item edit_user()

=cut

sub edit_user {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    my $CGI = $MINORIMPACT->cgi();
    my $user = $MINORIMPACT->user({ force => 1 });

    my @errors;
    if ($CGI->param('submit') || $CGI->param('hidden_submit')) {
        my $params = $CGI->Vars;
        $user->update($params);
        if ($@) {
            my $error = $@;
            MinorImpact::log('notice', $error);
            $error =~s/ at .+ line \d+.*$//;
            push(@errors, $error) if ($error);
        }

        if (scalar(@errors) == 0) {
            $MINORIMPACT->redirect({ action => 'user' });
        }
    }

    my $form = $user->form();

    MinorImpact::tt('edit_user', { 
                        errors  => [ @errors ],
                        form => $form,
    });
}

sub home {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log('debug', "starting");

    my $CGI = $self->cgi();
    my $user = $self->user({ force => 1 });

    my $format = $CGI->param('format') || 'html';
    my $limit = $CGI->param('limit') || 30;
    my $page = $CGI->param('page') || 1; 
    my $script_name = MinorImpact::scriptName();

    my $collection_id = MinorImpact::session('collection_id');
    my $search = MinorImpact::session('search');
    my $sort = MinorImpact::session('sort');
    my $tab_id = MinorImpact::session('tab_id');

    my $collection = new MinorImpact::Object($collection_id) if ($collection_id);

    my $local_params = cloneHash($params);
    my @types;
    my @objects;
    if ($params->{objects}) {
        @objects = @{$params->{objects}};
        $search ||= $collection->searchText() if ($collection);
    } elsif ($collection || $search) {
        if ($search) {
            $local_params->{query}{search} = $search;
        } elsif ($collection) {
            #MinorImpact::log('debug', "\$collection->id()='" . $collection->id() . "'");
            $local_params->{query} ||= {};
            $local_params->{query} = { %{$local_params->{query}}, %{$collection->searchParams()} };
            $search = $collection->searchText();
        }

        $local_params->{query}{user_id} = $user->id();
        $local_params->{query}{debug} .= 'MinorImpact::www::index();';
        $local_params->{query}{page} = $page;
        $local_params->{query}{limit} = $limit + 1;

        $local_params->{query}{type_tree} = 1;
        $local_params->{query}{sort} = $sort;
        # Anything coming in through here is coming from a user, they 
        #   don't need to search system objects.
        $local_params->{query}{system} = 0;

        # TODO: INEFFICIENT AS FUCK.
        #   We need to figure out  a search that just tells us what types we're
        #   dealing with so we know how many tabs to create.
        #   I feel like this is maybe where efficient caching would come in... maybe
        #   we can... the problem is this is arbitrary searching, so we can't really
        #   cache any numbers that make sense.  The total changes, the search string
        #   changes... Maybe we can... have a separate search that just searches by
        #   id, and then runs through the results... but to get the types, they still
        #   have to create the objects.  Or hit the database for everyone to get the
        #   type_id from object table.
        #   Well, at least we only have to it once, since the tab list is a static
        #   page.
        my $result = MinorImpact::Object::Search::search($local_params);
        if ($result) {
            push(@types, keys %{$result});
        }
        if (scalar(@types) == 1) {
            $local_params->{query}{object_type_id} = $types[0];
            delete($local_params->{query}{type_tree});
            @objects = MinorImpact::Object::Search::search($local_params);
        }
    } else {
        push(@types, MinorImpact::Object::getType());
        #my $all_types = MinorImpact::Object::types();
        #foreach my $type (@$types) {
        #    push(@types, $type->{id});
        #}
        if (scalar(@types) == 1) {
            $local_params->{query}{object_type_id} = $types[0];
            $local_params->{query}{user_id} = $user->id();
            delete($local_params->{query}{type_tree});
            @objects = MinorImpact::Object::Search::search($local_params);
        }
    }

    my $tab_number = 0;
    # TODO: figure out some way for these to be alphabetized
    $tab_id = MinorImpact::Object::typeID($tab_id) unless ($tab_id =~/^\d+$/);
    foreach my $child_type_id (@types) {
        last if ($child_type_id == $tab_id);
        $tab_number++;
    }

    my $url_last;
    my $url_next;
    if (scalar(@objects)) {
        $url_last = ($page>1)?(MinorImpact::url({ page=> $page?($page - 1):''})):'';
        $url_next = (scalar(@objects)>$limit)?MinorImpact::url({ page=> $page?($page + 1):''}):'';
        pop(@objects) if ($url_next);
    }

    MinorImpact::log('debug', "\$local_params->{search_placeholder}='". $local_params->{search_placeholder} . "'");
    MinorImpact::tt('home', {
                            cid                 => $collection_id,
                            objects             => [ @objects ],
                            search              => $search,
                            search_placeholder  => "$local_params->{search_placeholder}",
                            sort                => $sort,
                            tab_number          => $tab_number,
                            types               => [ @types ],
                            url_last            => $url_last,
                            url_next            => $url_next,
                            });
    # For testing.
    #if ($object && $object->typeID() == 4) {
    #    $object->updateAllDates();
    #}
}

sub index {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log('debug', "starting");
    
    my $CGI = $self->cgi();
    my $search = $CGI->param('search');
    my $sort = $CGI->param('sort');
    my $tab_id = $CGI->param('tab_id');

    if (!defined($search)) {
        $search = MinorImpact::session('search');
    } else {
        MinorImpact::session('search', $search || {});
    }
    if (!defined($sort)) {
        $sort = MinorImpact::session('sort');
    } else {
        MinorImpact::session('sort', $sort || {});
    }
    if (!defined($tab_id)) {
        $tab_id = MinorImpact::session('tab_id');
    } else {
        MinorImpact::session('tab_id', $tab_id || {});
    }


    #my $object_id = $CGI->param('object_id') || $CGI->param('id');
    #my $object;

    #if ($object_id) {
    #    eval {
    #        $object = new MinorImpact::Object($object_id);
    #    };
    #}

    MinorImpact::tt('index') ; #, { object => $object });
    #MinorImpact::log('debug', 'ending');
}

sub login {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    #MinorImpact::log('debug', "starting");

    my $CGI = $MINORIMPACT->cgi();
    my $user = $MINORIMPACT->user();

    $MINORIMPACT->redirect({ action => 'home' }) if ($user);

    my $username = $CGI->param('username');
    my $redirect = $CGI->param('redirect');
    my @errors;

    if ($username) {
        push(@errors, "Invalid username or password");
    }

    MinorImpact::tt('login', { errors => [ @errors ], redirect => $redirect, username => $username });
    #MinorImpact::log('debug', "ending");
}

sub logout {
    my $MINORIMPACT = shift || return;

    my $CGI = $MINORIMPACT->cgi();

    MinorImpact::clearSession();
    my $user_cookie =  $CGI->cookie(-name=>'user_id', -value=>'', -expires=>'-1d');
    print "Set-Cookie: $user_cookie\n";
    my $session_cookie =  $CGI->cookie(-name=>'session_id', -value=>'', -expires=>'-1d');
    print "Set-Cookie: $session_cookie\n";
    $MINORIMPACT->redirect({ action => 'index' });
}

sub object {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log('debug', "starting");

    my $CGI = $self->cgi();
    my $user = $self->user();
    my $settings;
    if ($user) {
        $settings = $user->settings();
    }

    my $format = $CGI->param('format') || 'html';
    my $limit = $CGI->param('limit') || 30;
    my $object_id = $CGI->param('object_id') || $CGI->param('id');
    my $page = $CGI->param('page') || 1;
    my $tab_id = $CGI->param('tab_id') || 0;

    my $object;
    if ($params->{object}) {
        $object = $params->{object};
    } elsif ($object_id) {
        eval {
            $object = new MinorImpact::Object($object_id);
        };
    }

    my $local_params = cloneHash($params);
    my @types;
    my @objects;
    if ($object) {
        if ($format eq 'json') {
            # Handle the json stuff and get out of here early.
            my $data = $object->toData();
            print "Content-type: text/plain\n\n";
            print to_json($data);
            return;
        }
        viewHistory($object->typeName() . "_id", $object->id());

        @types = $object->getChildTypes();
        if (scalar(@types) == 1) {
            #MinorImpact::log('debug', "Looking for children of '" . $object->id() . "', \$types[0]='" . $types[0] . "'");
            @objects = $object->getChildren({ query => { limit => ($limit + 1), object_type_id => $types[0], page => $page } });
            #MinorImpact::log('debug', "found: " . scalar(@objects));
        }
    }

    my $tab_number = 0;
    # TODO: figure out some way for these to be alphabetized
    $tab_id = MinorImpact::Object::typeID($tab_id) unless ($tab_id =~/^\d+$/);
    foreach my $child_type_id (@types) {
        last if ($child_type_id == $tab_id);
        $tab_number++;
    }

    my $url_last;
    my $url_next;
    #if (scalar(@objects)) {
    #    my $script_name = MinorImpact::scriptName();
    #    $url_last = $page>1?"$script_name?a=home&cid=$collection_id&search=$search&sort=$sort&page=" . ($page - 1):'';
    #    $url_next = (scalar(@objects)>$limit)?"$script_name?a=home&cid=$collection_id&sort=$sort&search=$search&page=" . ($page + 1):'';
    #    pop(@objects) if ($url_next);
    #}

    MinorImpact::tt('object', {
                            object      => $object,
                            tab_number  => $tab_number,
                            types       => [ @types ],
                            });
}

sub object_types {
    my $self = shift || return;

    print "Content-type: text/plain\n\n";
    my @json;
    foreach my $object_type (@{MinorImpact::Object::types()}) {
        push(@json, {id=>$object_type->{id}, name=>$object_type->{name}});
    }
    print to_json(\@json);
}

sub register {
    my $MI = shift || return;
    my $params = shift || {};

    #MinorImpact::log('debug', "starting");

    my $CGI = $MI->cgi();

    my $username = $CGI->param('username');
    my $email = $CGI->param('email');
    my $password = $CGI->param('password');
    my $password2 = $CGI->param('password2');
    my $submit = $CGI->param('submit');

    #MinorImpact::log('debug', "\$submit='$submit'");
    my @errors;
    if ($submit) {
        #MinorImpact::log('debug', "submit");
        if (!$username) {
           push(@errors, "'$username' is not a valid username");
        }
        if (!$password) {
           push(@errors, "Password cannot be blank");
        }
        if ($password ne $password2) {
            push(@errors, "Passwords don't match");
        }
        if (!scalar(@errors)) {
            my $user;
            eval {
                #MinorImpact::log('debug', "FUCK");
                MinorImpact::User::addUser({ email=>$email, password=>$password, username=>$username });
                $user  = $MI->user({ password=>$password, username=>$username });
            };
            push(@errors, $@) if ($@);
            if ($user) {
                $MI->redirect({ action => 'home' });
            } else {
                push(@errors, "Can't create new user");
            }
        }
    }
    MinorImpact::tt('register', { email => $email, errors => [ @errors ], username => $username });
    #MinorImpact::log('debug', "ending");
}

sub save_search {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    #MinorImpact::log('debug', "starting");
    my $CGI = MinorImpact::cgi();
    my $user = MinorImpact::user({ force => 1 });

    my $name = $CGI->param('save_name') || $MINORIMPACT->redirect();
    my $search = $CGI->param('search') || $MINORIMPACT->redirect();
    #MinorImpact::log('debug', "\$search='$search'");

    MinorImpact::cache("user_collections_" . $user->id(), {});
    my $collection_data = {name => $name, search => $search, user_id => $user->id()};
    my $collection = new MinorImpact::collection($collection_data);

    #MinorImpact::log('debug', "ending");
    $MINORIMPACT->redirect( { collection_id => $collection->id() });
}

sub search {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log('debug', "starting");

    my $CGI = $self->cgi();
    my $user = MinorImpact::user();

    my $format = $CGI->param('format') || 'html';
    my $limit = $CGI->param('limit') || 30;
    my $page = $CGI->param('page') || 1; 
    my $script_name = MinorImpact::scriptName();

    my $collection_id = MinorImpact::session('collection_id');
    my $search = MinorImpact::session('search');
    my $sort = MinorImpact::session('sort');
    my $tab_id = MinorImpact::session('tab_id');

    my $collection = new MinorImpact::Object($collection_id) if ($collection_id);

    my $local_params = cloneHash($params);
    my @types;
    my @objects;
    if ($params->{objects}) {
        @objects = @{$params->{objects}};
        $search ||= $collection->searchText() if ($collection);
    } elsif ($collection || $search) {
        if ($search) {
            $local_params->{query}{search} = $search;
        } elsif ($collection) {
            #MinorImpact::log('debug', "\$collection->id()='" . $collection->id() . "'");
            $local_params->{query} ||= {};
            $local_params->{query} = { %{$local_params->{query}}, %{$collection->searchParams()} };
            $search = $collection->searchText();
        }

        $local_params->{query}{debug} .= 'MinorImpact::www::index();';
        $local_params->{query}{page} = $page;
        $local_params->{query}{limit} = $limit + 1;

        $local_params->{query}{type_tree} = 1;
        $local_params->{query}{sort} = $sort;
        # Anything coming in through here is coming from a user, they 
        #   don't need to search system objects.
        $local_params->{query}{system} = 0;

        # TODO: INEFFICIENT AS FUCK.
        #   We need to figure out  a search that just tells us what types we're
        #   dealing with so we know how many tabs to create.
        #   I feel like this is maybe where efficient caching would come in... maybe
        #   we can... the problem is this is arbitrary searching, so we can't really
        #   cache any numbers that make sense.  The total changes, the search string
        #   changes... Maybe we can... have a separate search that just searches by
        #   id, and then runs through the results... but to get the types, they still
        #   have to create the objects.  Or hit the database for everyone to get the
        #   type_id from object table.
        #   Well, at least we only have to it once, since the tab list is a static
        #   page.
        my $result = MinorImpact::Object::Search::search($local_params);
        if ($result) {
            push(@types, keys %{$result});
        }
        if (scalar(@types) == 1) {
            $local_params->{query}{object_type_id} = $types[0];
            delete($local_params->{query}{type_tree});
            @objects = MinorImpact::Object::Search::search($local_params);
        }
    } else {
        push(@types, MinorImpact::Object::getType());
        #my $all_types = MinorImpact::Object::types();
        #foreach my $type (@$types) {
        #    push(@types, $type->{id});
        #}
        if (scalar(@types) == 1) {
            $local_params->{query}{object_type_id} = $types[0];
            delete($local_params->{query}{type_tree});
            @objects = MinorImpact::Object::Search::search($local_params);
        }
    }

    my $tab_number = 0;
    # TODO: figure out some way for these to be alphabetized
    $tab_id = MinorImpact::Object::typeID($tab_id) unless ($tab_id =~/^\d+$/);
    foreach my $child_type_id (@types) {
        last if ($child_type_id == $tab_id);
        $tab_number++;
    }

    my $url_last;
    my $url_next;
    if (scalar(@objects)) {
        $url_last = ($page>1)?(MinorImpact::url({ page=> $page?($page - 1):''})):'';
        $url_next = (scalar(@objects)>$limit)?MinorImpact::url({ page=> $page?($page + 1):''}):'';
        pop(@objects) if ($url_next);
    }

    MinorImpact::tt('search', {
                            cid                 => $collection_id,
                            objects             => [ @objects ],
                            search              => $search,
                            search_placeholder  => "$local_params->{search_placeholder}",
                            sort                => $sort,
                            tab_number          => $tab_number,
                            types               => [ @types ],
                            url_last            => $url_last,
                            url_next            => $url_next,
                            });
    # For testing.
    #if ($object && $object->typeID() == 4) {
    #    $object->updateAllDates();
    #}
}

=item settings()

=cut

sub settings {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    my $user = $MINORIMPACT->user({ force => 1 });

    my $settings = $user->settings($params);

    MinorImpact::tt('settings', { settings => $settings });
}

sub tablist {
    my $self = shift || return;
    my $params = shift || {};

    my $CGI = $self->cgi();
    my $user = $self->user();
    my $script_name = MinorImpact::scriptName();

    my $format = $CGI->param('format') || 'html';
    my $limit = $CGI->param('limit');
    if ($limit eq '') { $limit = 30; }
    elsif ($limit eq 0) { $limit = ''; }
    my $object_id = $CGI->param('id') || $CGI->param('object_id');
    my $page = $CGI->param('page') || 1;
    my $object_type_id = $CGI->param('object_type_id') || $CGI->param('type_id') || $CGI->param('type') || return;

    my $search = MinorImpact::session('search');
    my $collection_id = MinorImpact::session('collection_id');

    my $object;
    if ($object_id) {
        eval {
            $object = new MinorImpact::Object($object_id);
        };
    }
    $object_type_id = MinorImpact::Object::typeID($object_type_id) if ($object_type_id && $object_type_id !~/^\d+$/);
    $self->redirect() unless ($object_type_id);
    my $type_name = MinorImpact::Object::typeName($object_type_id);

    # Show a list of objects of a certain type that refer to the current object.
    my $local_params;
    $local_params->{query} = {object_type_id=>$object_type_id, sort=>1, debug=> "MinorImpact::www::tablist();"};
    $local_params->{query}{user_id} = $user->id() if ($user);

    my @collections = sort { $a->cmp($b); } $user->getCollections() if ($user);
    my $collection = new MinorImpact::Object($collection_id) if ($collection_id);
    unless ($object) {
        if ($collection) {
            $local_params->{query} = { %{$local_params->{query}}, %{$collection->searchParams()} };
            $local_params->{query}{debug} .= "collection::searchParams();";
        } elsif ($search) {
            $local_params->{query}{search} = $search;
        }
    }
    $local_params->{query}{page} = $page;
    $local_params->{query}{limit} = $limit + 1 if ($limit);

    # TODO: Figure out how to get the maximum number of objects without having to do a complete search...
    #   Right now I know there's 'more' because I'm asking for one more than will fit on the page, but
    #   I can't do a proper 'X of Y' until I can get the whole caboodle.
    my $max;
    my @objects;
    if ($object) {
        @objects = $object->getChildren($local_params);
    } else {
        @objects = MinorImpact::Object::Search::search($local_params);
    }
    if ($format eq 'json') {
        pop(@objects) if ($limit && scalar(@objects) > $limit);
        my @data;
        foreach my $object (@objects) {
            push(@data, $object->toData());
        }
        print "Content-type: text/plain\n\n";
        print to_json(\@data);
        return;
    }

    my $url_last;
    my $url_next;
    if ($limit) {
        $url_last = ($page > 1)?MinorImpact::url({ action => 'tablist', object_id => $object_id, collection_id => $collection_id, object_type_id => $object_type_id, search => $search, page => ($page - 1) }):'';
        if (scalar(@objects) > $limit) {
            $url_next = MinorImpact::url({ action => 'tablist', object_id => $object_id, collection_id => $collection_id, object_type_id => $object_type_id, search => $search, page => ($page + 1) });
            pop(@objects);
        }
    }
    MinorImpact::tt('tablist', {  
                            object_type_id => $object_type_id,
                            objects        => [ @objects ],
                            #readonly       => MinorImpact::Object::isReadonly($object_type_id),
                            #search         => $search,
                            url_last       => $url_last,
                            url_next       => $url_next,
    });
}

sub tags {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    my $user = $MINORIMPACT->user({ force => 1 });
    my $CGI = $MINORIMPACT->cgi();
    my $script_name = MinorImpact::scriptName();

    my $local_params = cloneHash($params);
    $local_params->{query}{user_id} = $user->id();
    delete($local_params->{query}{tag});
    my @objects = MinorImpact::Object::Search::search($local_params);

    my @tags;
    my $tags;
    foreach my $object (@objects) {
        push(@tags, $object->tags());
    }
    map { $tags->{$_}++; } @tags;
    MinorImpact::tt('tags', { tags => $tags, });
}

sub user {
    my $MI = shift || return;

    my $user = $MI->user({ force => 1 });
    my $script_name = MinorImpact::scriptName();

    MinorImpact::tt('user');
}

=item viewHistory()

=item viewHistory( $field )

=item viewHistory( $field, $value )

=cut

sub viewHistory {
    my $field = shift;
    my $value = shift;

    my $history = MinorImpact::session('view_history');

    if (!$field && !defined($value)) {
        return $history;
    } elsif ($field && !defined($value)) {
        return $history->{$field};
    }
    $history->{$field} = $value;

    MinorImpact::session('view_history', $history);
}

=back

=cut

=item1 AUTHOR

Patrick Gillan (pgillan@minorimpact.com)

=cut

1;
