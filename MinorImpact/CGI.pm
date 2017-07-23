package MinorImpact::CGI;

use JSON;

use MinorImpact;
use MinorImpact::collection;
use MinorImpact::Util;

sub add {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "starting");

    my $CGI = $self->getCGI();
    my $TT = $self->getTT();
    my $user = $self->getUser({ force => 1 });

    my $action = $CGI->param('action') || $CGI->param('a') || $self->redirect();
    my $type_id = $CGI->param('type_id') || $CGI->param('type') || $self->redirect();
    $type_id = MinorImpact::Object::typeID($type_id) if ($type_id && $type_id !~/^\d+$/);
    $type_id ||= MinorImpact::Object::getType();

    my $object;
    if ($CGI->param('submit') || $CGI->param('hidden_submit')) {
        my $params = $CGI->Vars;
        if ($action eq 'add') {
            #MinorImpact::log(8, "submitted action eq 'add'");
            $params->{user_id} = $user->id();
            $params->{type_id} = $type_id;
            eval {
                $object = new MinorImpact::Object($params);
            };
            MinorImpact::log(3, "error: $@");
            $error = $@ if ($@);
        }
        if ($object && !$error) {
            my $back = $object->back() || "$script_name?id=" . $object->id();
            $self->redirect($back);
        }
    }

    my $type_name = MinorImpact::Object::typeName({object_type_id=>$type_id});
    my $local_params = {object_type_id=>$type_id};
    MinorImpact::log(8, "\$type_name='$type_name'");
    my $form;
    eval {
        $form = $type_name->form($local_params);
    };
    if ($@) {
        $form = MinorImpact::Object::form($local_params);
    }

    $TT->process('add', {
                        error=>$error,
                        form => $form,
                        object=>$object,
                        type_name => $type_name,
                    }) || die $TT->error();
}

sub add_reference {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    my $user = $MINORIMPACT->getUser({ force => 1 });
    my $CGI = MinorImpact::getCGI();
    my $DB = MinorImpact::getDB();

    my $object_id = $CGI->param('object_id');
    my $object_text_id = $CGI->param('object_text_id');
    my $data = $CGI->param('data');

    my $object = new MinorImpact::Object($object_id) || $MINORIMPACT->redirect();

    print "Content-type: text/plain\n\n";
    if ($object_text_id && $data && $object && $object->user_id() eq $user->id()) {
        $DB->do("INSERT INTO object_reference(object_text_id, data, object_id, create_date) VALUES (?, ?, ?, NOW())", undef, ($object_text_id, $data, $object->id())) || die $DB->errstr;
    }
}

sub collections {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    my $local_params = cloneHash($params);
    my $user = $MINORIMPACT->getUser() || $MINORIMPACT->redirect();
    my $TT = $MINORIMPACT->getTT();

    my @collections = sort { $a->cmp($b); } $user->getCollections();
    $TT->process('collections', {
                                    collections => [ @collections ],
                        }) || die $TT->error();
}

sub css {
    my $self = shift || return;
    my $params = shift || {};

    my $TT = $self->getTT();
    $TT->process('css');
}

sub del {
    my $self = shift || return;
    my $params = shift || {};

    my $CGI = $self->getCGI();
    my $user = $self->getUser({ force => 1 });

    my $object_id = $CGI->param('id') || $CGI->param('object_id') || $self->redirect();
    my $object = new MinorImpact::Object($object_id) || $self->redirect();
    my $back = $object->back();

    $object->delete();
    $self->redirect($back);
}

sub delete_collection {
    my $self = shift || return;
    my $params = shift || {};

    my $CGI = $self->getCGI();
    my $user = $self->getUser({ force => 1 });

    my $collection_id = $CGI->param('cid') || $self->redirect();

    my $collection = new MinorImpact::Object($collection_id);
    if ($collection && $collection->user_id() eq $user->id()) {
        $collection->delete();
    }

    $self->redirect("?a=collections");
}

sub edit {
    my $self = shift || return;
    my $params = shift || {};

    my $CGI = $self->getCGI();
    my $TT = $self->getTT();
    my $user = $self->getUser({ force => 1 });

    my $search = $CGI->param('search');

    my $object_id = $CGI->param('id') || $CGI->param('object_id') || $self->redirect();
    my $object = new MinorImpact::Object($object_id) || $self->redirect();

    if ($CGI->param('submit') || $CGI->param('hidden_submit')) {
        my $params = $CGI->Vars;
        eval {
            $object->update($params);
        };
        $error = $@ if ($@);

        if ($object && !$error) {
            my $back = $object->back() || "$script_name?id=" . $object->id();
            $self->redirect($back);
        }
    }

    my $form = $object->form($params);
    $TT->process('edit', { 
                        error   => $error,
                        form    => $form,
                        no_name => $params->{no_name},
                        object   =>$object,
                    }) || die $TT->error();
}

sub index {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "starting");

    my $CGI = $self->getCGI();
    my $TT = $self->getTT();
    my $user = $self->getUser();

    my $collection_id = $CGI->param('collection_id') || $CGI->param('cid');
    my $format = $CGI->param('format') || 'html';
    my $limit = $CGI->param('limit') || 30;
    my $object_id = $CGI->param('object_id') || $CGI->param('id');
    my $page = $CGI->param('page') || 1;
    my $search = $CGI->param('search') || '';
    my $sort = $CGI->param('sort') || 1;
    my $tab_id = $CGI->param('tab_id') || 0;

    my @collections = sort { $a->cmp($b); } $user->getCollections() if ($user);
    my $object;
    if ($object_id) {
        eval {
            $object = new MinorImpact::Object($object_id);
        };
    }

    my @types;
    my @objects;
    if ($object) {
        if ($format eq 'json') {
            # Handle the json stuff and get out of here early.
            my $data = $object->toData();
            print "Content-type: text/plain\n\n";
            print to_json($data);
            exit;
        }
        viewHistory($object->typeName() . "_id", $object->id());
        my $object_cookie =  $CGI->cookie(-name=>'object_id', -value=>$object->id());
        print "Set-Cookie: $object_cookie\n";

        @types = $object->getChildTypes();
        if (scalar(@types) == 1) {
            MinorImpact::log(8, "Looking for children of '" . $object->id() . "', \$types[0]='" . $types[0] . "'");
            @objects = $object->getChildren({ limit => ($limit + 1), object_type_id => $types[0], page => $page });
            MinorImpact::log(8, "found: " . scalar(@objects));
        }
    } elsif ($collection_id || $search || defined($params->{query}) ) {
        my $collection = new MinorImpact::Object($collection_id) if ($collection_id);
        my $local_params = cloneHash($params);
        if ($collection) {
            $local_params->{query} = { %{$local_params->{query}}, %{$collection->searchParams()} };
            $search = $collection->searchText();
        } else {
            $local_params->{query}{search} = $search;
        }
        # I still don't know if I need this or not.  In some cases, index is open to all, so limiting
        #   search to the current user doesn't make sense... but at the same time, this is specifically
        #   either a search or a collection, both of which *seem* like they should be limited to the currently
        #   logged in user... right?
        #$local_params->{query}{user_id} = $user->id();
        $local_params->{query}{debug} .= 'MinorImpact::CGI::index();';
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
            @objects = MinorImpact::Object::Search::search({ query => {  object_type_id => $types[0] } });
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
        $url_last = $page>1?"$script_name?cid=$collection_id&search=$serach&page=" . ($page - 1):'';
        $url_next = (scalar(@objects)>$limit)?"$script_name?cid=$collection_id&search=$search&page=" . ($page + 1):'';
        pop(@objects) if ($url_next);
    }

    $TT->process('index', {
                            cid         => $collection_id,
                            collections => [ @collections ],
                            object      => $object,
                            objects     => [ @objects ],
                            search      => $search,
                            sort        => $sort,
                            tab_number  => $tab_number,
                            types       => [ @types ],
                            url_last    => $url_last,
                            url_next    => $url_next,
                            }) || die $TT->error();

    # For testing.
    if ($object && $object->typeID() == 4) {
        $object->updateAllDates();
    }
}

sub login {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "starting");

    my $CGI = $MINORIMPACT->getCGI();
    my $TT = $MINORIMPACT->getTT();
    
    my $username = $CGI->param('username');
    my $redirect = $CGI->param('redirect');
    
    my $user = $MINORIMPACT->getUser();

    if ($user) {
        $MINORIMPACT->redirect();
    }
    
    $TT->process('login', {redirect=>$redirect, username=>$username}) || die $TT->error();
    #MinorImpact::log(7, "ending");
}

sub logout {
    my $MINORIMPACT = shift || return;

    my $CGI = $MINORIMPACT->getCGI();
    #my $user = $MINORIMPACT->getUser();

    my $user_cookie =  $CGI->cookie(-name=>'user_id', -value=>'', -expires=>'-1d');
    my $object_cookie =  $CGI->cookie(-name=>'object_id', -value=>'', -expires=>'-1d');
    my $view_cookie =  $CGI->cookie(-name=>'view_history', -value=>'', -expires=>'-1d');
    print "Set-Cookie: $user_cookie\n";
    print "Set-Cookie: $object_cookie\n";
    print "Set-Cookie: $view_cookie\n";
    $MINORIMPACT->redirect();
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

    MinorImpact::log(7, "starting");

    my $CGI = $MI->getCGI();
    my $tt = $MI->getTT();

    my $username = $CGI->param('username');
    my $email = $CGI->param('email');
    my $password = $CGI->param('password');
    my $password2 = $CGI->param('password2');
    my $submit = $CGI->param('submit');

    my $error;
    if ($submit) {
        MinorImpact::log(8, "submit");
        if (!$username) {
            $error = "'$username' is not a valid username";
        }
        if (!$password) {
            $error .= "Password cannot be blank";
        }
        if ($password ne $password2) {
            $error .= "Passwords don't match";
        }
        if (!$error) {
            eval {
                MinorImpact::log(8, "addUser");
                MinorImpact::User::addUser({username=>$username, password=>$password, email=>$email});
                my $user = $MI->getUser({username=>$username, password=>$password});
                if ($user) {
                    $MI->redirect();
                } else {
                    $error = "Can't create new user.";
                }
            };
            $error = $@ if ($@);
        }
    }
    $tt->process('register', {username=>$username, email=>$email, error=>$error}) || die $tt->error();
    MinorImpact::log(7, "ending");
}

sub save_search {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    MinorImpact::log(7, "starting");
    my $CGI = MinorImpact::getCGI();
    my $user = MinorImpact::getUser({ force => 1 });

    my $name = $CGI->param('save_name') || $MINORIMPACT->redirect();
    my $search = $CGI->param('search') || $MINORIMPACT->redirect();
    MinorImpact::log(8, "\$search='$search'");

    my $collection_data = {name => $name, search => $search, user_id => $user->id()};
    my $collection = new MinorImpact::collection($collection_data);

    MinorImpact::log(7, "ending");
    $MINORIMPACT->redirect("?cid=" . $collection->id());
}

sub tablist {
    my $self = shift || return;
    my $params = shift || {};

    my $CGI = $self->getCGI();
    my $TT = $self->getTT();
    my $user = $self->getUser();
    my $script_name = MinorImpact::scriptName();

    my $object_id = $CGI->param('id') || $CGI->param('object_id');
    my $type_id = $CGI->param('type_id') || $CGI->param('type') || return;
    my $collection_id = $CGI->param('cid') || $CGI->param('collection_id');
    my $search = $CGI->param('search') || '';
    my $page = $CGI->param('page') || 1;
    my $limit = $CGI->param('limit') || 30;

    my $object;
    if ($object_id) {
        eval {
            $object = new MinorImpact::Object($object_id);
        };
    }
    $type_id = MinorImpact::Object::typeID($type_id) if ($type_id && $type_id !~/^\d+$/);
    $self->redirect() unless ($type_id);
    my $type_name = MinorImpact::Object::typeName($type_id);

    # Show a list of objects of a certain type that refer to the current object.
    my $local_params;
    $local_params->{query} = {object_type_id=>$type_id, sort=>1, debug=> "MinorImpact::CGI::tablist();"};
    $local_params->{query}{user_id} = $user->id() if ($user);

    my @collections = sort { $a->cmp($b); } $user->getCollections() if ($user);
    my $collection = new MinorImpact::Object($collection_id) if ($collection_id);
    if ($collection) {
        $local_params->{query} = { %{$local_params->{query}}, %{$collection->searchParams()} };
    } elsif ($search) {
        $local_params->{query}{search} = $search;
    }
    $local_params->{query}{debug} .= "collection::searchParams();";
    $local_params->{query}{page} = $page;
    $local_params->{query}{limit} = $limit + 1;

    # TODO: Figure out how to get the maximum number of objects without having to do a complete search...
    my $max;
    if ($object) {
        @objects = $object->getChildren($local_params);
    } else {
        @objects = MinorImpact::Object::Search::search($local_params);
    }

    my $url_last = $page>1?"$script_name?a=tablist&id=$object_id&cid=$collection_id&type_id=$type_id&search=$search&&page=" . ($page - 1):'';
    my $url_next;
    if (scalar(@objects) > $limit) {
        $url_next = "$script_name?a=tablist&id=$object_id&cid=$collection_id&type_id=$type_id&search=$search&page=" . ($page + 1);
        pop(@objects);
    }
    $TT->process('tablist', {  
                            collections => [ @collections ],
                            objects     => [ @objects ],
                            search      => $search,
                            type_id     => $type_id,
                            url_last    => $url_last,
                            url_next    => $url_next,
                            }) || die $TT->error();
}

sub tags {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    my $local_params = cloneHash($params);
    my $user = $MINORIMPACT->getUser();
    my $CGI = $MINORIMPACT->getCGI();
    my $TT = $MINORIMPACT->getTT();
    my $script_name = MinorImpact::scriptName();

    my $local_params = cloneHash($params);
    $local_params->{query}{user_id} = $user->id();
    delete($local_params->{query}{tag});
    my @objects = MinorImpact::Object::Search::search($local_params);
    my @tags;
    my $tags;

    foreach my $object (@objects) {
        push(@tags, $object->getTags());
    }
    map { $tags->{$_}++; } @tags;
    $TT->process('tags', {
                            tags       => $tags,
                        }) || die $TT->error();
}

sub user {
    my $MI = shift || return;

    my $user = $MI->getUser({ force => 1 });
    my $TT = $MI->getTT();
    my $script_name = MinorImpact::scriptName();

    $TT->process('user') || die $TT->error();
}

sub viewHistory {
    my $field = shift;
    my $value = shift;


    my $CGI = MinorImpact::getCGI();
    my $history;
    my $view_history = $CGI->cookie('view_history');
    #MinorImpact::log(8, "\$CGI->cookie('view_history') = '$view_history'"); 
    foreach my $pair (split(';', $view_history)) {
        my ($f, $v) = $pair =~/^([^=]+)=(.*)$/;
        $history->{$f} = $v if ($f);
    }

    if (!$field && !defined($value)) {
        return $history;
    } elsif ($field && !defined($value)) {
        return $history->{$field};
    }
    $history->{$field} = $value;

    $view_history = join(";", map { "$_=" . $history->{$_}; } keys %$history);
    #MinorImpact::log(8, "view_history='$view_history'");
    my $cookie =  $CGI->cookie(-name=>'view_history', -value=>$view_history);
    print "Set-Cookie: $cookie\n";
}

1;
