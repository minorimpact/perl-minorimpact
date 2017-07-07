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

sub edit {
    my $self = shift || return;
    my $params = shift || {};

    my $CGI = $self->getCGI();
    my $TT = $self->getTT();
    my $user = $self->getUser({ force => 1 });

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

sub list {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "starting");

    my $CGI = $self->getCGI();
    my $TT = $self->getTT();
    my $user = $self->getUser();

    my $collection_id = $CGI->param('collection_id') || $CGI->param('cid');
    my $format = $CGI->param('format') || 'html';
    my $type_id = $CGI->param('type_id') || $CGI->param('type'); # || $self->redirect();
    my $object_id = $CGI->param('object_id') || $CGI->param('id');

    my $object;
    eval {
        $object = new MinorImpact::Object($object_id) if ($object_id);
        return view($self, $params) if ($object);
    };

    $type_id = MinorImpact::Object::typeID($type_id) if ($type_id && $type_id !~/^\d+$/);
    $type_id ||= MinorImpact::Object::getType();

    my $local_params = cloneHash($params);
       
    # If we're looking at a collection objects, then build out the search
    #   query from that.
    #MinorImpact::log(8, "\$collection_id=$collection_id");
    my $collection = new MinorImpact::Object($collection_id) if ($collection_id);
    if ($collection) {
        $local_params = $collection->searchParams();
    }

    $local_params->{object_type_id} = $type_id;
    $local_params->{sort} = 1;
    $local_params->{debug} .= "CGI::index(a=list);";
    $local_params->{user_id} = $user->id() if ($user);

    my @objects = MinorImpact::Object::Search::search($local_params);
    if (scalar(@objects) == 0) {
        #MinorImpact::log(7, "No objects found, redirecting.");
        unless ($user) {
            #MinorImpact::log(7, "No user found, redirecting to ?a=login.");
            $self->redirect("?a=login") unless ($user);
        }
        #MinorImpact::log(8, "User '" . $user->id() ."', redirecting to add");
        $self->redirect("?a=add&type_id=$type_id");
    }

    if ($format eq 'json') {
        my @data;
        foreach my $o (@objects) {
            push(@data, $o->toData());
        }
        print "Content-type: text/plain\n\n";
        print to_json(\@data);
    } else { # $format eq 'html'
        my $type_name = MinorImpact::Object::typeName($type_id);
        my @collections;
        if ($user) {
            @collections = $user->getCollections();
        }

        my @tags;
        my %tags;
        foreach my $object (@objects) {
            map { $tags{$_}++; } $object->getTags();
        }
        @tags = reverse(sort { $tags{$a} cmp $tags{$b}; } keys %tags);
        splice(@tags, 5);
        #@tags = map {- length($_); } @tags;
        $TT->process('list', {  
                                collection_id => $collection_id,
                                collections   => [ @collections ],
                                objects       => [ @objects ],
                                tags          => [ @tags ],
                                type_id       => $type_id,
                                type_name     => $type_name,
                            }) || die $TT->error();
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
        $MINORIMPACT->redirect($redirect);
    }
    
    $TT->process('login', {redirect=>$redirect, username=>$username}) || die $TT->error();
    #MinorImpact::log(7, "ending");
}

sub logout {
    my $MINORIMPACT = shift || return;

    my $CGI = $MINORIMPACT->getCGI();
    my $user = $MINORIMPACT->getUser();

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
    #??? MinorImpact::Object::Search::search($MINORIMPACT, $params);
    my $search = $CGI->param('search') || $MINORIMPACT->redirect();
    MinorImpact::log(8, "\$search='$search'");

    my $collection_data = {name => $name, search => $search, user_id => $user->id()};
    my $collection = new MinorImpact::collection($collection_data);

    MinorImpact::log(7, "ending");
    $MINORIMPACT->redirect("?cid=" . $collection->id());
}

sub search {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    my $local_params = cloneHash($params);
    delete($local_params->{tag});
    $local_params->{debug} .= "MinorImpact::CGI::search();";

    my $user = $MINORIMPACT->getUser();
    my $CGI = $MINORIMPACT->getCGI();
    my $TT = $MINORIMPACT->getTT();
    my $script_name = MinorImpact::scriptName();

    my $search = $CGI->param('search');

    my $objects;
    if ($search) {
        $local_params->{text} = $search;
        $local_params->{type_tree} = 1;
        $local_params->{sort} = 1;
        # Anything coming in through here is coming from a user, they 
        #   don't need to search system objects.
        $local_params->{system} = 0;
        $objects = MinorImpact::Object::Search::search($local_params);
    }
    $TT->process('search', {
                            objects  => $objects,
                            search   => $search,
                            typeName => sub { MinorImpact::Object::typeName(@_, {plural=>1}) },
                        }) || die $TT->error();
}

sub tablist {
    my $self = shift || return;
    my $params = shift || {};

    my $CGI = $self->getCGI();
    my $TT = $self->getTT();
    my $user = $self->getUser();
    my $script_name = MinorImpact::scriptName();

    my $object_id = $CGI->param('id') || $CGI->param('object_id') || return;
    my $type_id = $CGI->param('type_id') || $CGI->param('type') || return;
    my $collection_id = $CGI->param('cid') || $CGI->param('collection_id');
    my $page = $CGI->param('page') || 1;
    my $limit = $CGI->param('limit') || 25;

    my $object = new MinorImpact::Object($object_id) || return;
    $type_id = MinorImpact::Object::typeID($type_id) if ($type_id && $type_id !~/^\d+$/);
    $self->redirect() unless ($type_id);
    my $type_name = MinorImpact::Object::typeName($type_id);

    # Show a list of objects of a certain type that refer to the current object.
    my $local_params = {object_type_id=>$type_id, sort=>1, debug=> "MinorImpact::CGI::index(a=tablist);"};
    my $collection = new MinorImpact::Object($collection_id) if ($collection_id);
    if ($collection) {
        $local_params = { %$local_params, %{$collection->searchParams()} };
    }
    $local_params->{debug} .= "collection::searchParams();";

    my $max = scalar($object->getChildren({ %$local_params, id_only => 1 }));
    $local_params->{page} = $page;
    $local_params->{limit} = $limit;
    my @objects = $object->getChildren($local_params);

    #my @tags;
    #my %tags;
    #foreach my $object (@objects) {
    #    map { $tags{$_}++; } $object->getTags();
    #}
    #@tags = reverse sort { $tags{$a} <=> $tags{$b}; } keys %tags;
    #splice(@tags, 5);

    # TODO: Figure out how to get the maximum number of objects without having to do a complete search...
    #   I ma
    my $url_last = $page>1?"$script_name?a=tablist&id=$object_id&cid=$collection_id&type_id=$type_id&page=" . ($page - 1):'';
    my $url_next = ($page<=int($max/$limit))?"$script_name?a=tablist&id=$object_id&cid=$collection_id&type_id=$type_id&page=" . ($page + 1):'';
    $TT->process('tablist', {  
                            objects   => [ @objects ],
                            #tags      => [ @tags ],
                            type_id   => $type_id,
                            type_name => $type_name,
                            url_last  => $url_last,
                            url_next  => $url_next,
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

    my $search_tag = $CGI->param('search_tag');

    my $objects;
    if ($search_tag) {
        $local_params->{tag} = $search_tag;
        $local_params->{type_tree} = 1;
        $objects = MinorImpact::Object::Search::search($local_params);
    }
    $TT->process('tags', {
                            objects=>$objects, 
                            search_tag=>$search_tag,
                        }) || die $TT->error();
}

sub user {
    my $MI = shift || return;

    my $user = $MI->getUser({ force => 1 });
    my $TT = $MI->getTT();
    my $script_name = MinorImpact::scriptName();

    $TT->process('user') || die $TT->error();
}

sub view {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log(7, "starting");

    my $TT = $self->getTT();
    my $CGI = $self->getCGI();
    my $script_name = $self->scriptName();

    my $object_id = $CGI->param('object_id') || $CGI->param('id') || $self->redirect();
    my $collection_id = $CGI->param('collection_id') || $CGI->param('cid');
    my $format = $CGI->param('format') || 'html';
    my $tab_id = $CGI->param('tab_id') || 0;

    my $user = $self->getUser();
    my $object = new MinorImpact::Object($object_id) || $self->redirect();

    if ($format eq 'json') {
        my $data = $object->toData();
        print "Content-type: text/plain\n\n";
        print to_json($data);
        exit;
    }
    my $tab_number = 0;

    # TODO: figure out some way for these to be alphabetized
    $tab_id = MinorImpact::Object::typeID($tab_id) unless ($tab_id =~/^\d+$/);
    foreach my $child_type_id ($object->getChildTypes()) {
        last if ($child_type_id == $tab_id);
        $tab_number++;
    }

    my $javascript = <<JAVASCRIPT;
        \$(function () {
            \$("#tabs").tabs({
                active: $tab_number,
                beforeLoad: function( event, ui ) {
                    ui.panel.html("<div>Loading...</div>");
                }
            });
        });
JAVASCRIPT

    viewHistory($object->typeName() . "_id", $object->id());
    my $object_cookie =  $CGI->cookie(-name=>'object_id', -value=>$object->id());
    print "Set-Cookie: $object_cookie\n";

    $TT->process('index', {
                            cid        => $collection_id,
                            javascript => $javascript,
                            object     => $object,
                            tab_number => $tab_number,
                            }) || die $TT->error();

    #$object->updateAllDates();
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
