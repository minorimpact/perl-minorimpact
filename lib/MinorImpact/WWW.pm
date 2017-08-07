package MinorImpact::WWW;

use JSON;

use MinorImpact;
use MinorImpact::Util;

sub add {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "starting");

    my $CGI = $self->cgi();
    my $user = $self->user({ force => 1 });

    my $action = $CGI->param('action') || $CGI->param('a') || $self->redirect();
    my $object_type_id = $CGI->param('type_id') || $CGI->param('type') || $self->redirect();
    $object_type_id = MinorImpact::Object::typeID($object_type_id) if ($object_type_id);

    my $object;
    my @errors;
    if ($CGI->param('submit') || $CGI->param('hidden_submit')) {
        my $params = $CGI->Vars;
        if ($action eq 'add') {
            #MinorImpact::log(8, "submitted action eq 'add'");
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
        if ($object && !$error) {
            my $back = $object->back() || "$script_name?id=" . $object->id();
            $self->redirect($back);
        }
    }

    my $type_name = MinorImpact::Object::typeName({ object_type_id => $object_type_id });
    my $local_params = { object_type_id=>$object_type_id };
    #MinorImpact::log(8, "\$type_name='$type_name'");
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

    my $user = $MINORIMPACT->user({ force => 1 });

    #my @collections = sort { $a->cmp($b); } $user->getCollections();
    my @collections = $user->getCollections();
    MinorImpact::tt('collections', { collections => [ @collections ], });
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

    $self->redirect("?a=collections");
}

sub edit {
    my $self = shift || return;
    my $params = shift || {};

    my $CGI = $self->cgi();
    my $user = $self->user({ force => 1 });

    my $search = $CGI->param('search');

    my $object_id = $CGI->param('id') || $CGI->param('object_id') || $self->redirect();
    my $object = new MinorImpact::Object($object_id) || $self->redirect();
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
            my $back = $object->back() || "$script_name?id=" . $object->id();
            $self->redirect($back);
        }
    }

    my $form = $object->form($params);
    $self->tt('edit', { 
                        errors  => [ @errors ],
                        form    => $form,
                        no_name => $params->{no_name},
                        object   =>$object,
    });
}

sub home {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "starting");

    my $CGI = $self->cgi();
    my $user = $self->user({ force => 1 });

    my $collection_id = $CGI->param('collection_id') || $CGI->param('cid');
    my $format = $CGI->param('format') || 'html';
    my $limit = $CGI->param('limit') || 30;
    my $object_id = $CGI->param('object_id') || $CGI->param('id');
    my $page = $CGI->param('page') || 1;
    my $search = $CGI->param('search') || '';
    my $sort = $CGI->param('sort') || 1;
    my $tab_id = $CGI->param('tab_id') || 0;

    my @collections = sort { $a->cmp($b); } $user->getCollections();
    my $collection = new MinorImpact::Object($collection_id) if ($collection_id);
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
            #MinorImpact::log(8, "Looking for children of '" . $object->id() . "', \$types[0]='" . $types[0] . "'");
            @objects = $object->getChildren({ limit => ($limit + 1), object_type_id => $types[0], page => $page });
            #MinorImpact::log(8, "found: " . scalar(@objects));
        }
    } elsif ($params->{objects}) {
        @objects = @{$params->{objects}};
        $search ||= $collection->searchText() if ($collection);
    } elsif ($collection || $search || defined($params->{query}) ) {
        if ($search) {
            $local_params->{query}{search} = $search;
        } elsif ($collection) {
            #MinorImpact::log(8, "\$collection->id()='" . $collection->id() . "'");
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
        $url_last = $page>1?"$script_name?a=home&cid=$collection_id&search=$serac&sort=$sorth&page=" . ($page - 1):'';
        $url_next = (scalar(@objects)>$limit)?"$script_name?a=home&cid=$collection_id&sort=$sort&search=$search&page=" . ($page + 1):'';
        pop(@objects) if ($url_next);
    }

    MinorImpact::tt('home', {
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
                            });
    # For testing.
    #if ($object && $object->typeID() == 4) {
    #    $object->updateAllDates();
    #}
}

sub index {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "starting");

    my $user = $self->user();
    $self->redirect("?a=home") if ($user);

    my $CGI = $self->cgi();

    my $object_id = $CGI->param('object_id') || $CGI->param('id');

    if ($object_id) {
        eval {
            $object = new MinorImpact::Object($object_id);
        };
    }

    MinorImpact::tt('index');
}

sub login {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "starting");

    my $CGI = $MINORIMPACT->cgi();
    
    my $user = $MINORIMPACT->user();

    if ($user) {
        $MINORIMPACT->redirect("?a=home");
    }

    my $username = $CGI->param('username');
    my $redirect = $CGI->param('redirect');
    my @errors;

    if ($username) {
        push(@errors, "Invalid username or password");
    }

    MinorImpact::tt('login', { errors => [ @errors ], redirect => $redirect, username => $username });
    #MinorImpact::log(7, "ending");
}

sub logout {
    my $MINORIMPACT = shift || return;

    my $CGI = $MINORIMPACT->cgi();
    #my $user = $MINORIMPACT->user();

    my $user_cookie =  $CGI->cookie(-name=>'user_id', -value=>'', -expires=>'-1d');
    print "Set-Cookie: $user_cookie\n";
    $MINORIMPACT->redirect("?");
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

    #MinorImpact::log(7, "starting");

    my $CGI = $MI->cgi();

    my $username = $CGI->param('username');
    my $email = $CGI->param('email');
    my $password = $CGI->param('password');
    my $password2 = $CGI->param('password2');
    my $submit = $CGI->param('submit');

    MinorImpact::log(8, "\$submit='$submit'");
    my @errors;
    if ($submit) {
        #MinorImpact::log(8, "submit");
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
                #MinorImpact::log(8, "FUCK");
                MinorImpact::User::addUser({ email=>$email, password=>$password, username=>$username });
                $user  = $MI->user({ password=>$password, username=>$username });
            };
            push(@errors, $@) if ($@);
            if ($user) {
                $MI->redirect("?a=home");
            } else {
                push(@errors, "Can't create new user");
            }
        }
    }
    $tt->process('register', { email => $email, errors => [ @errors ], username => $username }) || die $tt->error();
    #MinorImpact::log(7, "ending");
}

sub save_search {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "starting");
    my $CGI = MinorImpact::cgi();
    my $user = MinorImpact::user({ force => 1 });

    my $name = $CGI->param('save_name') || $MINORIMPACT->redirect();
    my $search = $CGI->param('search') || $MINORIMPACT->redirect();
    #MinorImpact::log(8, "\$search='$search'");

    MinorImpact::cache("user_collections_" . $user->id(), {});
    my $collection_data = {name => $name, search => $search, user_id => $user->id()};
    my $collection = new MinorImpact::collection($collection_data);

    #MinorImpact::log(7, "ending");
    $MINORIMPACT->redirect("?cid=" . $collection->id());
}

sub tablist {
    my $self = shift || return;
    my $params = shift || {};

    my $CGI = $self->cgi();
    my $user = $self->user({ force => 1 });
    my $script_name = MinorImpact::scriptName();

    my $collection_id = $CGI->param('cid') || $CGI->param('collection_id');
    my $format = $CGI->param('format') || 'html';
    my $limit = $CGI->param('limit');
    if ($limit eq '') { $limit = 30; }
    elsif ($limit eq 0) { $limit = ''; }
    my $object_id = $CGI->param('id') || $CGI->param('object_id');
    my $page = $CGI->param('page') || 1;
    my $search = $CGI->param('search') || '';
    my $object_type_id = $CGI->param('object_type_id') || $CGI->param('type_id') || $CGI->param('type') || return;

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
    if ($collection) {
        $local_params->{query} = { %{$local_params->{query}}, %{$collection->searchParams()} };
    } elsif ($search) {
        $local_params->{query}{search} = $search;
    }
    $local_params->{query}{debug} .= "collection::searchParams();";
    $local_params->{query}{page} = $page;
    $local_params->{query}{limit} = $limit + 1 if ($limit);

    # TODO: Figure out how to get the maximum number of objects without having to do a complete search...
    #   Right now I know there's 'more' because I'm asking for one more than will fit on the page, but
    #   I can't do a proper 'X of Y' until I can get the whole caboodle.
    my $max;
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

    my $url_lasty;
    my $url_next;
    if ($limit) {
        $url_last = $page>1?"$script_name?a=tablist&id=$object_id&cid=$collection_id&type_id=$object_type_id&search=$search&&page=" . ($page - 1):'';
        if (scalar(@objects) > $limit) {
            $url_next = "$script_name?a=tablist&id=$object_id&cid=$collection_id&type_id=$object_type_id&search=$search&page=" . ($page + 1);
            pop(@objects);
        }
    }
    MinorImpact::tt('tablist', {  
                            collections    => [ @collections ],
                            object_type_id => $object_type_id,
                            objects        => [ @objects ],
                            readonly       => MinorImpact::Object::isReadonly($object_type_id),
                            search         => $search,
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

    $session->{view_history} = $history;
    MinorImpact::session('view_history', $history);
}

1;
