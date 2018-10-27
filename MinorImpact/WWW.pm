package MinorImpact::WWW;

use strict;

use JSON;

use MinorImpact;
use MinorImpact::Util;

=head1 NAME

MinorImpact::WWW

=head1 SYNOPSIS

  use MinorImpact;

  MinorImpact::www({ actions => { index => \&index } });

  sub index {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    # Do some custom stuff.
    MinorImpact::WWW::index($MINORIMPACT, $params);
  }

=head1 SUBROUTINES

=cut

=head2 add

=over

=item add(\%params)

=back

=cut

sub add {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    #MinorImpact::debug(1);
    MinorImpact::log('debug', "starting");

    my $CGI = $MINORIMPACT->cgi();
    my $user = $MINORIMPACT->user({ force => 1 });

    my $script_name = MinorImpact::scriptName();
    my $action = $CGI->param('action') || $CGI->param('a') || $MINORIMPACT->redirect();
    my $object_type_id = $CGI->param('type_id') || $CGI->param('type') || $CGI->param('id') || $MINORIMPACT->redirect();
    my $type = new MinorImpact::Object::Type($object_type_id);
    MinorImpact::log('debug', "\$type->name()='" . $type->name() . "'");
    #$object_type_id = MinorImpact::Object::typeID($object_type_id) if ($object_type_id);
    $MINORIMPACT->redirect() if ($type->isReadonly());

    my $object;
    my @errors;
    if ($CGI->param('submit') || $CGI->param('hidden_submit')) {
        my $params = $CGI->Vars;
        if ($action eq 'add') {
            #MinorImpact::log('debug', "submitted action eq 'add'");
            $params->{user_id} = $user->id();
            $params->{object_type_id} = $type->id();

            # Add the booleans manually, since unchecked values don't get 
            #   submitted.
            my $fields = $type->fields();
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
            my $back = $object->back() || "$script_name?a=object&object_id=" . $object->id();
            $MINORIMPACT->redirect($back);
        }
    }

    #my $type_name = $type->name();
    #my $local_params = { object_type_id=>$type->id(), no_cache => 1 };
    #MinorImpact::log('debug', "\$type_name='$type_name'");
    my $form;
    eval {
        $form = $type->form({no_cache => 1}); #$local_params);
    };
    if ($@) {
        $form = MinorImpact::Object::form({ object_type_id=>$type->id(), no_cache => 1 }); #$local_params);
    }

    MinorImpact::tt('add', {
                        errors           => [ @errors ],
                        form             => $form,
                        object_type_name => $type->name(),
                        object_type_id   => $type->id(),
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

sub admin {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    my $user = $MINORIMPACT->user({ force => 1 });
    $MINORIMPACT->redirect() unless ($user->isAdmin());

    my $CGI = $MINORIMPACT->cgi();
    my $session = MinorImpact::session();

    MinorImpact::tt('admin', { session => $session });
}

sub collections {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    my $user = $MINORIMPACT->user({ force => 1 });

    #my @collections = sort { $a->cmp($b); } $user->getCollections();
    my @collections = $user->getCollections();
    MinorImpact::tt('collections', { collections => [ @collections ], });
}

sub del {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    my $CGI = $MINORIMPACT->cgi();
    my $user = $MINORIMPACT->user({ force => 1 });

    my $object_id = $CGI->param('id') || $CGI->param('object_id') || $MINORIMPACT->redirect();
    my $object = new MinorImpact::Object($object_id) || $MINORIMPACT->redirect();
    my $back = $object->back();

    $object->delete();
    $MINORIMPACT->redirect($back);
}

sub delete_search {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    my $CGI = $MINORIMPACT->cgi();
    my $user = $MINORIMPACT->user({ force => 1 });

    my $collection_id = $CGI->param('collection_id') || $CGI->param('cid') || $CGI->param('id') || $MINORIMPACT->redirect();

    #MinorImpact::debug(1);
    my $collection = new MinorImpact::Object($collection_id);
    MinorImpact::log('debug', "\$collection->user_id()='" . $collection->user_id() . "', \$user->id()='" . $user->id() . "'");
    if ($collection && $collection->user_id() == $user->id()) {
        MinorImpact::log('debug', "deleting collection '" . $collection->id() . "'");
        $collection->delete();
        MinorImpact::cache("user_collections_" . $user->id(), {});
    }

    $MINORIMPACT->redirect({ action => 'collections' });
}

=head2 edit

=over

=item edit($MINORIMPACT, [\%params])

=back

Edit an object.

  /cgi-bin/index.cgi?a=edit&id=<id>

=head3 URL Parameters

=over

=item id

=item object_id

=back

The id of the object to edit.

=cut

sub edit {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    #MinorImpact::log('debug', "starting");
    my $local_params = cloneHash($params);
    $local_params->{no_cache} = 1;
    my $CGI = $MINORIMPACT->cgi();
    my $user = $MINORIMPACT->user({ force => 1 });
    my $script_name = MinorImpact::scriptName();

    my $object_id = $CGI->param('id') || $CGI->param('object_id') || $MINORIMPACT->redirect();
    my $object = new MinorImpact::Object($object_id, $local_params) || $MINORIMPACT->redirect();
    $MINORIMPACT->redirect($object->back()) if ($object->isReadonly());

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

        if ($object->isType('public')) {
            $params->{public} = 0 if (!defined($params->{public}));
        }

        eval {
            $object->update($params);
        };
        if ($@) {
            my $error = $@;
            #$error =~s/ at .+ line \d+.*$//;
            MinorImpact::log('debug', $error);
            push(@errors, $error) if ($error);
        }

        if ($object && scalar(@errors) == 0) {
            my $back = $object->back() || "$script_name?a=object&id=" . $object->id();
            $MINORIMPACT->redirect($back);
        }
    }

    my $form = $object->form($local_params);
    $MINORIMPACT->tt('edit', { 
                        errors  => [ @errors ],
                        form    => $form,
                        object   =>$object,
                    });
    #MinorImpact::log('debug', "ending");
}

sub settings {
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

=head2 edit_user

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

=head2 home

=over

=item home($MINORIMPACT, [\%params])

=back

Display all the objects found by executing $params->{query}.  If query is not defined, 
pull a list of everything the user owns.  This action/page requires a currently
logged in user.

=cut

sub home {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    MinorImpact::log('debug', "starting");

    my $CGI = $MINORIMPACT->cgi();
    my $user = $MINORIMPACT->user({ force => 1 });
    my $settings = $user->settings();

    my $format = $CGI->param('format') || 'html';
    my $limit = $CGI->param('limit') || ($settings?$settings->get('results_per_page'):20);
    my $page = $CGI->param('page') || 1; 

    my $sort = $CGI->param('sort') || 1;
    my $tab_id = MinorImpact::session('tab_id');

    my $local_params = cloneHash($params);

    # The local home() sub should specify a query that defines list of objects that 
    # appear on this page.  If no query is specified, grab everything that belongs to the current user.
    if (!defined($local_params->{query})) {
        $local_params->{query} = {};
        $local_params->{query}{user_id} = $user->id();
    }
    $local_params->{query}{system} = 0;
    $local_params->{query}{readonly} = 0;
    $local_params->{query}{limit} = $limit;
    $local_params->{query}{page} = $page;
    $local_params->{query}{sort} = $sort;

    my @objects = MinorImpact::Object::Search::search($local_params);

    # Making a list of all possible types to so we can build a list of 'add new <type>'
    #   buttons on the template.
    my @type_ids = MinorImpact::Object::typeIDs({readonly => 0, system => 0});
    #foreach my $object_type_id (MinorImpact::Object::getTypeID()) {
    #    push(@types, MinorImpact::Object::getChildTypeIDs({ object_type_id=>$object_type_id}));
    #}

    MinorImpact::log('debug', "\$local_params->{search_placeholder}='". $local_params->{search_placeholder} . "'");
    MinorImpact::tt('home', {
                            action              => 'home',
                            objects             => [ @objects ],
                            query               => $local_params->{query},
                            sort                => $sort,
                            #tab_number          => $tab_number,
                            types               => [ @type_ids ],
                            });
    MinorImpact::log('debug', "ending");
}

=head2 index

=over

=item ::($MINORIMPACT, \%params)

=back

The main site page, what's displayed to the world.  By default, 

=cut

sub index {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    MinorImpact::log('debug', "starting");
    
    my $CGI = $MINORIMPACT->cgi();
    my $limit = $CGI->param('limit');
    my $page = $CGI->param('page');

    my $local_params = cloneHash($params);
    my @objects;
    unless (defined($local_params->{query})) {
        # Just grab whatever comes up as the default type and hope for
        #   the best.
        $local_params->{query} = {};
        $local_params->{query}{admin} = 1;
        $local_params->{query}{object_type_id} = MinorImpact::Object::getTypeID();
        $local_params->{query}{public} = 1;
    }

    $local_params->{query}{limit} = $limit if ($limit);
    $local_params->{query}{page} = $page if ($page);

    push(@objects, MinorImpact::Object::Search::search($local_params));

    MinorImpact::tt('index', {
        action => 'index',
        objects => [ @objects ],
        query => $local_params->{query},
    });
    MinorImpact::log('debug', 'ending');
}

sub login {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    MinorImpact::log('debug', "starting");

    my $user = $MINORIMPACT->user();

    $MINORIMPACT->redirect({ action => 'home' }) if ($user);

    my $CGI = $MINORIMPACT->cgi();
    my $username = $CGI->param('username');
    my $redirect = $CGI->param('redirect');
    my @errors;

    if ($username) {
        push(@errors, "Invalid username or password");
    }

    MinorImpact::tt('login', { errors => [ @errors ], redirect => $redirect, username => $username });
    MinorImpact::log('debug', "ending");
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
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    #MinorImpact::log('debug', "starting");

    my $CGI = $MINORIMPACT->cgi();
    my $user = $MINORIMPACT->user();
    my $settings;
    if ($user) {
        $settings = $user->settings();
    }

    my $format = $CGI->param('format') || 'html';
    my $limit = $CGI->param('limit') || 30;
    my $object_id = $CGI->param('object_id') || $CGI->param('id') || $MINORIMPACT->redirect();
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

    $MINORIMPACT->redirect() unless ($object);
    my $local_params = cloneHash($params);
    # Making a list of all possible types to so we can build a list of 'add new <type>'
    #   buttons on the template.
    my @types;
    push(@types, MinorImpact::Object::getChildTypeIDs({ object_type_id=>$object->typeID()}));

    my @objects;
    if ($format eq 'json') {
        # Handle the json stuff and get out of here early.
        my $data = $object->toData();
        print "Content-type: text/plain\n\n";
        print to_json($data);
        return;
    }
    viewHistory($object->typeName() . "_id", $object->id());


    #my $tab_number = 0;
    ## TODO: figure out some way for these to be alphabetized
    #$tab_id = MinorImpact::Object::typeID($tab_id) unless ($tab_id =~/^\d+$/);
    #foreach my $child_type_id (@types) {
    #    last if ($child_type_id == $tab_id);
    #    $tab_number++;
    #}

    @objects = $object->getChildren({ query => { limit => ($limit + 1), page => $page } });

    my $url_prev;
    my $url_next;
    if (scalar(@objects)) {
        $url_prev = ($page>1)?(MinorImpact::url({ action=>'object', object_id=>$object->id(), limit=>$limit, page=> $page?($page - 1):'' })):'';
        $url_next = (scalar(@objects)>$limit)?MinorImpact::url({ action=>'object', object_id=>$object->id(), limit=>$limit, page=> $page?($page + 1):'' }):'';
        pop(@objects) if ($url_next);
    }

    MinorImpact::tt('object', {
                            object      => $object,
                            objects     => [ @objects ],
                            #tab_number  => $tab_number,
                            types       => [ @types ],
                            url_prev    => $url_prev,
                            url_next    => $url_next,
                            });
}

sub object_types {
    my $MINORIMPACT = shift || return;

    print "Content-type: text/plain\n\n";
    my @json;
    foreach my $object_type (MinorImpact::Object::types({readonly => 0, system => 0})) {
        push(@json, {id=>$object_type->id(), name=>$object_type->name()});
    }
    print to_json(\@json);
}

sub register {
    my $MI = shift || return;
    my $params = shift || {};

    MinorImpact::log('debug', "starting");

    my $CGI = MinorImpact::cgi();

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
                $user = MinorImpact::User::addUser({ email=>$email, password=>$password, username=>$username });
            };
            if ($@) {
                my $error = $@;
                $error = "Duplicate entry for $username." if ($error =~/Duplicate entry/);
                push(@errors, $error);
            }
            if ($user) {
                $MI->redirect({ action => 'home' });
            } else {
                if (scalar(@errors)) { unshift(@errors, "Can't create new user:"); }
                else { unshift(@errors, "Can't create new user."); }
            }
        }
    }
    MinorImpact::tt('register', { email => $email, errors => [ @errors ], username => $username });
    MinorImpact::log('debug', "ending");
}

sub save_search {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    MinorImpact::log('debug', 'starting');
    my $CGI = MinorImpact::cgi();
    my $user = MinorImpact::user({ force => 1 });

    my $name = $CGI->param('save_name') || $MINORIMPACT->redirect();
    my $search = $CGI->param('search') || $MINORIMPACT->redirect();
    MinorImpact::log('debug', "\$search='$search'");

    my $search_filter = $params->{search_filter} || {};
    $search_filter->{object_type_id} = $CGI->param('object_type_id') if ($CGI->param('object_type_id'));
    MinorImpact::cache("user_collections_" . $user->id(), {});
    foreach my $key (keys %$search_filter) {
        MinorImpact::log('debug', "\$search_filter->{$key}='" . $search_filter->{$key} . "'");
    }
    my $collection_data = { name => $name, search => $search, search_filter => $search_filter, user_id => $user->id() };
    my $collection = new MinorImpact::collection($collection_data);

    MinorImpact::log('debug', 'ending');
    if ($collection) {
        $MINORIMPACT->redirect( { action=>'search', collection_id => $collection->id() });
    } else {
        $MINORIMPACT->redirect( { action=>'home', });
    }
}

=head2 search

Search the system application.

=head3 URL parameters

=over

=item search

A string to search for.  See L<MinorImpact::Object::Search::parseSearchString()|MinorImpact::Object::Search/parseSearchString>.

  # search for objects tagged with 'test' that contain the word 'poop'.
  /cgi-bin/index.cgi?a=search&search=poop%tag:test

=back

=cut

sub search {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    #MinorImpact::debug(1);
    MinorImpact::log('debug', "starting");

    my $CGI = $MINORIMPACT->cgi();
    my $user = MinorImpact::user();

    my $format = $CGI->param('format') || 'html';
    my $list_type = $CGI->param('list_type') || '';
    my $limit = $CGI->param('limit') || 30;
    my $object_type_id = $CGI->param('object_type_id') || $CGI->param('type_id');
    my $page = $CGI->param('page') || 1; 
    my $sort = $CGI->param('sort');
    undef($sort) if ($sort eq '');

    my $admin = $CGI->param('admin');
    undef($admin) if ($admin eq '');
    my $public = $CGI->param('public');
    undef($public) if ($public eq '');
    my @tags = $CGI->param('tags');

    my $tab_id = MinorImpact::session('tab_id');

    #my $collection_id = MinorImpact::session('collection_id');
    my $collection_id = $CGI->param('collection_id') || $CGI->param('cid') || $CGI->param('id');
    my $search = $CGI->param('search') || '';

    my $collection = new MinorImpact::Object($collection_id) if ($collection_id);

    my $local_params = cloneHash($params);
    my @types;
    my @objects;

    $local_params->{query} = {} unless (defined($local_params->{query}));
    $local_params->{query}{tags} = [] unless (defined($local_params->{query}{tags}));
    # Override everything in the query with whatever is set in the URL
    #  parameters - the user has the final say over what they see.
    push(@{$local_params->{query}{tags}}, @tags);
    $local_params->{query}{page} = $page if ($page);
    $local_params->{query}{limit} = $limit + 1 if ($limit);
    $local_params->{query}{sort} = $sort if (defined($sort));

    $local_params->{query}{admin} = $admin if (defined($admin));
    $local_params->{query}{object_type_id} = $object_type_id if ($object_type_id);
    $local_params->{query}{public} = $public if (defined($public));
    $local_params->{query}{search} = $search;

    # Anything coming in through here is coming from a user, they 
    #   don't need to search system objects.
    $local_params->{query}{system} = 0;
    $local_params->{query}{debug} .= 'MinorImpact::WWW::search();';

    if ($params->{objects}) {
        @objects = @{$params->{objects}};
        $search ||= $collection->searchText() if ($collection);
    } elsif ($collection){ 
        $search = $collection->searchText();

        # Getting rid of the whole concept of the 'type-tree', for now, it just adds
        # complexity, and I decided that in all the current use cases, I just want to show
        # everyhing that comes up in a search, and it's up to the developer to make sure
        # that the 'list' output always works properly.  Besides, filtering the results by
        # type is pretty much the same thing, and the same mechanism can be used for other
        # criteria.
        ## TODO: INEFFICIENT AS FUCK.
        ##   We need to figure out  a search that just tells us what types we're
        ##   dealing with so we know how many tabs to create.
        ##   I feel like this is maybe where efficient caching would come in... maybe
        ##   we can... the problem is this is arbitrary searching, so we can't really
        ##   cache any numbers that make sense.  The total changes, the search string
        ##   changes... Maybe we can... have a separate search that just searches by
        ##   id, and then runs through the results... but to get the types, they still
        ##   have to create the objects.  Or hit the database for everyone to get the
        ##   type_id from object table.
        ##   Well, at least we only have to it once, since the tab list is a static
        ##   page.
        #$local_params->{query}{type_tree} = 1;
        #my $result = MinorImpact::Object::Search::search($local_params);
        #if ($result) {
        #    MinorImpact::log('debug', 'BAR');
        #    push(@types, keys %{$result});
        #}
        #if (scalar(@types) == 1) {
        #    $local_params->{query}{object_type_id} = $types[0];
        #    delete($local_params->{query}{type_tree});
        #    MinorImpact::log('debug', 'FOO');
        #    @objects = MinorImpact::Object::Search::search($local_params);
        #}
    }
    $local_params->{query}{search} = $search;
    @objects = MinorImpact::Object::Search::search($local_params);
    $page = $local_params->{query}{page};
    $limit = $local_params->{query}{limit};
    $search = $local_params->{query}{text};
    #MinorImpact::debug(0);

    my $tab_number = 0;
    # TODO: figure out some way for these to be alphabetized
    $tab_id = MinorImpact::Object::typeID($tab_id) unless ($tab_id =~/^\d+$/);
    foreach my $child_type_id (@types) {
        last if ($child_type_id == $tab_id);
        $tab_number++;
    }

    my $tt_variables = {
                        action              => 'search',
                        cid                 => $collection_id,
                        objects             => [ @objects ],
                        list_type           => $list_type,
                        query               => $local_params->{query},
                        #search              => $search,
                        search_placeholder  => "$local_params->{search_placeholder}",
                        typeIDs             => sub { MinorImpact::Object::typeIDs(shift); },
                        #url_prev            => $url_prev,
                        #url_next            => $url_next,
                    };

    if (defined($params->{tt_variables})) {
        foreach my $key (keys %{$params->{tt_variables}}) {
            MinorImpact::log('debug', "'$key' = '$params->{tt_variables}{$key}'");
            $tt_variables->{$key} = $params->{tt_variables}{$key};
        }
    }
    MinorImpact::tt('search', $tt_variables);
    MinorImpact::log('debug', "ending");
}

sub tablist {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    my $CGI = $MINORIMPACT->cgi();
    my $user = $MINORIMPACT->user();

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
    $MINORIMPACT->redirect() unless ($object_type_id);
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

    my $url_prev;
    my $url_next;
    if ($limit) {
        $url_prev = ($page > 1)?MinorImpact::url({ action => 'tablist', object_id => $object_id, collection_id => $collection_id, object_type_id => $object_type_id, search => $search, page => ($page - 1) }):'';
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
                            url_prev       => $url_prev,
                            url_next       => $url_next,
    });
}

=head2 tags

Display a list of the current user's tags - or the tags for all public objects
owned by 'admin' users, if no user is currenly logged in.

=cut

sub tags {
    my $MINORIMPACT = shift || return;
    my $params = shift || {};

    my $local_params = cloneHash($params);
    delete($local_params->{query}{tag}) if (defined($local_params->{query}));

    my $tags;
    map { $tags->{$_}++; } MinorImpact::Object::tags($local_params);
    MinorImpact::tt('tags', { tags => $tags, });
}

=head2 user

=over

=item ::user($MINORIMPACT, \%params)

=back

Display objects and information about a particular user.

=head3 params

=cut

sub user {
    my $MI = shift || return;
    my $params = shift || {};

    my $CGI = MinorImpact::cgi();
    my $page = $CGI->param('page') || 1;
    my $limit = $CGI->param('limit') || 5;
    my $sort = $CGI->param('sort') || 1;

    my $current_user = MinorImpact::user();

    my $user_id = $CGI->param('user_id') || $CGI->param('id') || $CGI->param('user') || ($current_user?$current_user->id():'') || MinorImpact::redirect();
    my $user = new MinorImpact::User($user_id) || MinorImpact::redirect();

    my $local_params = cloneHash($params);

    unless (defined($local_params->{query})) {
        $local_params->{query} = {};
        $local_params->{query}{sort} = 1;
    }

    $local_params->{query}{limit} = $limit;
    $local_params->{query}{page} = $page;
    $local_params->{query}{user_id} = $user->id();
    if (!$current_user || ($current_user->id() != $user->id())) {
        $local_params->{query}{public} = 1;
    }
    my @objects = MinorImpact::Object::Search::search($local_params);

    MinorImpact::tt('user', { action => 'user', objects => [ @objects ], query => $local_params->{query} });
}

=head2 viewHistory

=over

=item viewHistory()


=item viewHistory( $field )


=item viewHistory( $field, $value )

=back

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

=head1 AUTHOR

Patrick Gillan <pgillan@minorimpact.com>

=cut

1;
