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

        if ($CGI->param('submit')) {
            my $params = $CGI->Vars;
            if ($action eq 'add') {
                $params->{user_id} = $user->id();
                #my $type_name = $type->name();
                #$object = $type_name->new($params);
                $params->{type_id} = $type_id;
                eval {
                    $object = new MinorImpact::Object($params);
                };
                $error = $@ if ($@);
            } elsif ($action eq 'edit') {
                eval {
                    $object->update($params);
                };
                $error = $@ if ($@);
            }
            if ($object && !$error) {
                $self->redirect("$script_name?id=" . $object->id());
            }
        }
        if ($action eq 'add') {
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
                                script_name=>$script_name,
                                type_name => $type_name,
                                user=>$user,
                            }) || die $TT->error();
        } elsif ($action eq 'edit' && $object) {
            my $form = $object->form();
            $TT->process('edit', { 
                                    error=>$error,
                                    form=>$form,
                                    object=>$object,
                                    script_name=>$script_name,
                                    user=>$user,
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
                                    script_name=>$script_name,
                                    type_id=>$type_id,
                                    type_name=>$type_name,
                                    user=>$user,
                                    }) || die $TT->error();
        } elsif ($object) { # $action eq 'view'
            # Display one particular object.
            my $view_params = {tab_id=>$tab_id, object=>$object};
            if ($params->{view}) {
                return &{$params->{view}}->($view_params);
            }
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
                                    script_name=>$script_name,
                                    tab_number=>$tab_number,
                                    user=>$user,
                                }) || die $TT->error();
        } else { # $action eq 'list'
            # Show all the objects of a certain type, or the default type.
            $type_id ||= MinorImpact::Object::getType();
            if ($params->{list}) {
                my $list_params = {type_id=>$type_id, format=>$format};
                my $list = $params->{list};
                return $list->($self, $list_params);
            }
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


sub view {
    my $self = shift || return;
    my $params = shift || {};

    my $user = $self->getUser();
    my $object = $params->{object} || return;
    my $tab_id = $params->{tab_id} || 0;
    my $error = $oarams->{error};

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

        $TT->process('index', {javascript=>$javascript,
                                user=>$user,
                                projects=>[@projects],
                                project=>$project,
                                object=>$object,
                                error=>$error,
                                tab_number=>$tab_number,
                                }) || die $TT->error();

}


1;
