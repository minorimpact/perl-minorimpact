package MinorImpact::CGI;

use JSON;

use MinorImpact;
use MinorImpact::Util;

sub index {
    my $self = shift || return;
    my $params = shift || {};

    my $user = $self->getUser();
    my $TT = $self->getTT();
    my $CGI = $self->getCGI();
    my $script_name = MinorImpact::scriptName();

    my $action = $CGI->param('action') || $CGI->param('a') || "list";
    my $tab_id = $CGI->param('tab_id') || 0;
    my $object_id = $CGI->param('id') || $CGI->param('object_id');
    my $last_object_id = $CGI->cookie("object_id");
    my $type_id = $CGI->param('type_id');
    my $format = $CGI->param('format') || 'html';

    my $object;
    my $error;

    $object = new MinorImpact::Object($object_id) if ($object_id);
    $action = "view" if ($action eq "list" && $object);

    if ($CGI->param('submit')) {
        my $params = $CGI->Vars;
        if ($action eq 'add') {
            MinorImpact::log(8, "submitted action eq 'add'");
            $params->{user_id} = $user->id();
            #my $type_name = $type->name();
            #$object = $type_name->new($params);
            $params->{type_id} = $type_id;
            eval {
                $object = new MinorImpact::Object($params);
            };
            $error = $@ if ($@);
        } elsif ($action eq 'edit') {
            MinorImpact::log(8, "submitted action eq 'edit'");
            eval {
                $object->update($params);
            };
            $error = $@ if ($@);
        }
        if ($object && !$error) {
            $self->redirect("$script_name?id=" . $object->id());
        }
    }
    if ($params->{actions}{$action}) {
        my $local_params = {}; #cloneHash($params);
        $local_params->{tab_id} = $tab_id;
        $local_params->{object} = $object;
        $local_params->{type_id} = $type_id;
        $local_params->{format} = $format;
        my $sub = $params->{actions}{$action};
        return $sub->($self, $local_params);
    } elsif ($action eq 'add') {
        my $form;
        $type_id ||= MinorImpact::Object::getType();
        my $type_name = MinorImpact::Object::typeName({object_type_id=>$type_id});
        my $params = {object_type_id=>$type_id};
        eval {
            $form = $type_name->form($params);
        };
        if ($@) {
            $form = MinorImpact::Object::form($params);
        }

        $TT->process('add', {
                            error=>$error,
                            form => $form,
                            object=>$object,
                            type_name => $type_name,
                        }) || die $TT->error();
    } elsif ($action eq 'edit' && $object) {
            my $form = $object->form();
            $TT->process('edit', { 
                                error=>$error,
                                form=>$form,
                                object=>$object,
                            }) || die $TT->error();
    } elsif ($action eq 'delete' && $object) {
        $type_id = $object->type_id();
        $object->delete() if ($object);
        $self->redirect();
    } elsif ($action eq 'tablist' && $object && $type_id) {
        # Show a list of objects of a certain type that refer to the current object.
        MinorImpact::log(8, "action=tablist");
        my @objects = $object->getChildren({object_type_id=>$type_id, sort=>1});
        #my @objects = MinorImpact::Object::search({object_type_id=>$type_id, sort=>1});
        my $type_name = MinorImpact::Object::typeName($type_id);
        $TT->process('tablist', {  
                                objects=>[@objects],
                                home=>$self->{conf}{default}{home_script},
                                script_name=>$script_name,
                                type_id=>$type_id,
                                type_name=>$type_name,
                                user=>$user,
                                }) || die $TT->error();
    } elsif ($object) { # $action eq 'view'
        # Display one particular object.
        my $tab_number = 0;
        MinorImpact::log(8, "action eq 'view'");

        # TODO: figure out some way for these to be alphabetized
        foreach my $child_type_id ($object->getChildTypes()) {
            last if ($child_type_id == $tab_id);
            $tab_number++;
        }
        MinorImpact::log(8, "action eq 'view'");

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

        MinorImpact::log(8, $object->name());
        $TT->process('index', {
                                    error=>$error,
                                    javascript=>$javascript,
                                    object=>$object,
                                    home=>$self->{conf}{default}{home_script},
                                    script_name=>$script_name,
                                    tab_number=>$tab_number,
                                    user=>$user,
                                }) || die $TT->error();
        MinorImpact::log(8, $object->name());
    } elsif ( $action eq 'logout' ) {
        logout($self);
    } elsif ($action eq 'user' ) {
        user($self);
    } else { # $action eq 'list'
        # Show all the objects of a certain type, or the default type.
        $type_id ||= MinorImpact::Object::getType();
        my @objects = MinorImpact::Object::search({object_type_id=>$type_id, sort=>1});
        if (scalar(@objects) == 0) {
            $self->redirect("$script_name?a=add&type_id=$type_id");
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
            $TT->process('list', {  
                                    home=>$self->{conf}{default}{home_script},
                                    objects=>[@objects],
                                    script_name=>$script_name,
                                    type_id=>$type_id,
                                    type_name=>$type_name,
                                    user=>$user,
                                }) || die $TT->error();
        }
    }
}

sub login {
    my $self = shift || return;

    my $CGI = $self->getCGI();
    my $TT = $self->getTT();
    
    my $username = $CGI->param('username');
    my $redirect = $CGI->param('redirect');
    
    my $user = $self->getUser();
    if ($user) {
        $self->redirect();
    }
    
    $TT->process('login', {redirect=>$redirect, username=>$username}) || die $TT->error();
}

sub logout {
    my $self = shift || return;

    my $CGI = $self->getCGI();

    my $user_cookie =  $CGI->cookie(-name=>'user_id', -value=>'', -expires=>'-1d');
    my $object_cookie =  $CGI->cookie(-name=>'object_id', -value=>'', -expires=>'-1d');
    print $CGI->header(-cookie=>[$object_cookie, $user_cookie], -location=>"login.cgi");
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

sub search {
    my $MINORIMPACT = shift || return;

    my $user = $MINORIMPACT->getUser();
    my $CGI = $MINORIMPACT->getCGI();
    my $TT = $MINORIMPACT->getTT();
    my $script_name = MinorImpact::scriptName();

    my $project_id = $CGI->param('project_id');
    my $object_id = $CGI->param('object_id') || $CGI->cookie('object_id');

    my $search = $CGI->param('search');

    my $objects = MinorImpact::Object::search({text=>$search, type_tree=>1, sort=>1});
    $TT->process('search', {
                            objects=>$objects,
                            search=>$search,
                            typeName => sub { MinorImpact::Object::typeName(@_, {plural=>1}) },
                        }) || die $TT->error();
}

sub tags {
    my $MINORIMPACT = shift || return;

    my $user = $MINORIMPACT->getUser();
    my $CGI = $MINORIMPACT->getCGI();
    my $TT = $MINORIMPACT->getTT();
    my $script_name = MinorImpact::scriptName();

    my $search_tag = $CGI->param('search_tag');

    my $objects;
    if ($search_tag) {
        $objects = MinorImpact::Object::search({tag=>$search_tag, type_tree=>1});
    }
    $TT->process('tags', {
                            objects=>$objects, 
                            search_tag=>$search_tag,
                        }) || die $TT->error();
}

sub user {
    my $MI = shift || return;

    my $user = $MI->getUser();
    my $TT = $MI->getTT();
    my $script_name = MinorImpact::scriptName();

    $TT->process('user') || die $TT->error();
}

sub view {
    my $self = shift || return;
    my $params = shift || {};

    my $user = $self->getUser();
    my $object = $params->{object} || return;
    my $tab_id = $params->{tab_id} || 0;
    my $error = $oarams->{error};
    my $script_name = MinorImpact::scriptName();

    my $tab_number = 0;

    # TODO: figure out some way for these to be alphabetized
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

    $TT->process('index', {
                            error=>$error,
                            javascript=>$javascript,
                            object=>$object,
                            projects=>[@projects],
                            project=>$project,
                            tab_number=>$tab_number,
                            }) || die $TT->error();

}


1;
