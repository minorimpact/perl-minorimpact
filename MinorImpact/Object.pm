package MinorImpact::Object;

=head1 NAME 

MinorImpact::Object - The base class for MinorImpact objects.

=cut

=head1 SYNOPSIS

    use MinorImpact::Object;

    $object = new MinorImpact::Object({ object_type_id => 'type', name => $name, description => 'bar' });
    $description = $object->get('description');
    print $object->name() . ": $description\n";
    # OUTPUT
    # foo: bar

    $object->update({description => "Bar."});
    # OUTPUT
    # foo: Bar.

    $object->delete();

=cut

=head1 DESCRIPTION

On the use of the terms "parent" and "child": In defiance of logic and common sense, perhaps, 
the terms "parent" and "child" are used the opposite of how one might expect.  For example: take a
"car" object and an "engine" object.  The car has an "engine" field from which one
can select from a list of engine objects which were defined elsewhere.  Since the engine
object can exist on its own, without reference to the car, the engine is the parent.  The
car I<requires> an engine, therefore it is the child, despite the logical and intutive
assumption that the car would be the parent, since the engine "belongs" to it.

A better example of where this I<does> (kind of) make sense is a "project" object and a "task" object.
The task must include a reference to the project - therefore the project is the parent and the
task is the child, since the project exists on its own, but the task requires a project as part of
its definition.

=cut

use strict;

use Data::Dumper;
use JSON;
use Text::Markdown 'markdown';

use MinorImpact;
use MinorImpact::collection;
use MinorImpact::entry;
use MinorImpact::Object::Field;
use MinorImpact::Object::Search;
use MinorImpact::settings;
use MinorImpact::User;
use MinorImpact::Util;

my $OBJECT_CACHE;

=head1 METHODS

=cut

=head2 new

=over

=item MinorImpact::Object::new( $id )

=item MinorImpact::Object::new( { field => value[, ...] })

=back

Create a new MinorImpact::Object.

=cut

sub new {
    my $package = shift || return;
    my $id = shift || return;
    my $params = shift || {};

    MinorImpact::log('debug', "starting(" . $id . ")");
    my $DB = MinorImpact::db();
    my $object;

    # If we've created this object before, just return the cached version
    #   NOTE: This is local process cache, not a persistent external cache.
    return $OBJECT_CACHE->{$id} if ($OBJECT_CACHE->{$id} && $id =~/^\d+$/);

    eval {
        my $data;
        if (ref($id) eq "HASH") {
            die "Can't create a new object without an object type id." unless ($id->{object_type_id});
            MinorImpact::log('debug', "getting type_id for $id->{object_type_id}");
            my $object_type_id = typeID($id->{object_type_id});
            $data = MinorImpact::cache("object_type_$object_type_id") unless ($params->{no_cache});
            unless ($data) {
                $data = $DB->selectrow_hashref("SELECT * FROM object_type ot WHERE ot.id=?", undef, ($object_type_id)) || die $DB->errstr;
                MinorImpact::cache("object_type_$object_type_id", $data);
            }
        } else {
            $data = MinorImpact::cache("object_id_type_$id") unless ($params->{no_cache});
            unless ($data) {
                $data = $DB->selectrow_hashref("SELECT ot.* FROM object o, object_type ot WHERE o.object_type_id=ot.id AND o.id=?", undef, ($id)) || die $DB->errstr;
                MinorImpact::cache("object_id_type_$id", $data);
            }
        }
        my $type_name = $data->{name}; 
        my $version = $data->{version};
        my $package_version = version($type_name);

        if ($version < $package_version) {
            MinorImpact::log('notice', "Object/Database version mismatch: '$package_version' vs '$version'");
            eval {
                $type_name->dbConfig();
            };
            if ($@) {
                MinorImpact::log('err', $@);
            }
        }   
        #MinorImpact::log('info', "trying to create new '$type_name' with id='$id' (v$package_version)");
        $object = $type_name->new($id, $params) if ($type_name);
    };
    my $error = $@;
    if ($error && ($error =~/^error:/ || $error !~/Can't locate object method "new"/)) {
        $error =~s/ at \/.*$//;
        $error =~s/^error://;
        MinorImpact::log('crit', "id='$id',$error");
        die $error;
    }
    unless ($object) {
        $object = MinorImpact::Object::_new($package, $id, $params);
    }
    #
    MinorImpact::log('debug', "ending($id)");

    die "permission denied" unless ($object->validUser() || $params->{admin});

    $OBJECT_CACHE->{$object->id()} = $object if ($object);
    #MinorImpact::log('debug', "ending");
    return $object;
}

sub _new {
    my $package = shift;
    my $id = shift;
    my $params = shift || {};

    my $self = {};
    bless($self, $package);

    MinorImpact::log('debug', "starting(" . $id . ")");
    #MinorImpact::log('debug', "package='$package'");
    #MinorImpact::log('debug', "caching=" . ($params->{no_cache}?'off':'on'));
    $self->{DB} = MinorImpact::db() || die;
    $self->{CGI} = MinorImpact::cgi() || die;

    my $object_id;
    my $object_type_id;
    if (ref($id) eq 'HASH') {
        #MinorImpact::log('debug', "ref(\$id)='" . ref($id) . "'");

        $object_type_id = $id->{object_type_id} || $id->{type_id} || lc($package) || die "No object_type_id specified\n";
        MinorImpact::log('debug', "getting type_id for '$object_type_id'");
        $object_type_id = typeID($object_type_id);
        MinorImpact::log('debug', "got object_type_id='$object_type_id'");

        my $user_id = $id->{'user_id'} || MinorImpact::userID();
        die "invalid name" unless ($id->{name});
        die "invalid user id" unless ($user_id);
        die "invalid type id" unless ($object_type_id);

        $self->{DB}->do("INSERT INTO object (name, user_id, description, object_type_id, create_date) VALUES (?, ?, ?, ?, NOW())", undef, ($id->{'name'}, $user_id, $id->{'description'}, $object_type_id)) || die("Can't add new object:" . $self->{DB}->errstr);
        $object_id = $self->{DB}->{mysql_insertid};
        unless ($object_id) {
            MinorImpact::log('notice', "Couldn't insert new object record");
            die "Couldn't insert new object record";
        }
    } elsif ($id =~/^\d+$/) {
        $object_id = $id;
    } else {
        $object_id = $self->{CGI}->param("id") || MinorImpact::redirect();
    }

    # These two fields are the absolute minimum requirement to be considered a valid object.
    $self->{data} = {};
    $self->{data}{id} = $object_id;
    $self->{data}{object_type_id} = $object_type_id;

    if (ref($id) eq 'HASH') {
        my $fields = fields($id->{object_type_id});
        #MinorImpact::log('info', "validating fields: " . join(",", map { "$_=>'" . $fields->{$_} . "'"; } keys (%$fields)));
        validateFields($fields, $id);

        $self->update($id, $params);
    } else {
        $self->_reload($params);
    }

    #MinorImpact::log('debug', "ending(" . $self->id() . ")");
    return $self;
}

=head2 back

=over

=item back( \%options )

=back

Returns the url that makes the most sense when returning from viewing or editing this 
object. 

=head3 options

=over

=item url

Additional url parameters that you want to be included in the link.

=back

=cut

sub back {
    my $self = shift || return;
    my $params = shift || {};
    
    $params->{action} = 'home' unless(defined($params->{action}) && $params->{action});
    #my $CGI = MinorImpact::cgi();
    #my $cid = $CGI->param('cid');
    #my $search = $CGI->param('search');
    #my $sort = $CGI->param('sort');

    return MinorImpact::url($params);
}

sub churn {
    return;
}

=head2 id

=over

=item id() 

=back

Returns the id of the this objec.t

=cut

sub id { 
    return shift->{data}->{id}; 
}

=head2 name

=over

=item name( \%options )

=back

Returns the 'name' value for this object.   Shortcut for ->get('name', \%options). 

=cut

sub name { 
    return shift->get('name', shift); 
}

=head2 public

=over

=item ->public()

=back

Returns true if $OBJECT is marked "public".

  if ($OBJECT->public()) {
    # show the object
    return $OBJECT->toString();
  } else {
    # get bent
    return "DENIED";
  }

Equivilant to:

  $OBJECT->get('public');

=cut

sub public { 
    return shift->get('public'); 
}

=head2 user

=over

=item user()

=back

Return the user object of the owner of this object.  

  $user = $OBJECT->user();

... is a shortcut for:

  $user = new MinorImpact::User($OBJECT->get('user_id'));

=cut

sub user {
    my $self = shift || return;

    return new MinorImpact::User($self->get('user_id'));
}

=head2 userID

=over

=item userID()

=back

The ID of the user this object belongs to.

  $user_id = $OBJECT->userID();

=cut

sub userID { 
    return shift->get('user_id');
}   

sub user_id { 
    return shift->userID(); 
}

=head2 userName

=over

=item ->userName()

=back

Return the name of the user that owns this object.

  $name = $OBJECT->userName();

=cut

sub userName {
    return shift->user()->name();
}

sub selectList {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log('debug', "starting");
    my $local_params = cloneHash($params);
    $local_params->{query}{debug} .= "Object::selectList();";
    if (ref($self) eq 'HASH') {
        $local_params = cloneHash($self);
        $local_params->{query}{debug} .= "Object::selectList();";
        if ($local_params->{selected}) {
            $self = new MinorImpact::Object($local_params->{selected});
            $local_params->{query}{user_id} = $self->userID() if ($self && !$local_params->{query}{user_id});
            delete($local_params->{query}{user_id}) if ($self->isSystem());
        } else {
            undef $self;
        }
    } elsif (ref($self)) {
        $local_params->{query}{user_id} ||= $self->userID();
        $local_params->{selected} = $self->id() unless ($local_params->{selected});
    }

    my $select = "<select class='w3-select' id='$local_params->{fieldname}' name='$local_params->{fieldname}'";
    if ($local_params->{duplicate}) {
        $select .= " onchange='duplicateRow(this);'";
    }
    $select .= ">\n";
    $select .= "<option></option>\n" unless ($local_params->{required});
    $local_params->{query}{sort} = 1;
    if ($local_params->{query}{object_type_id} && $local_params->{query}{user_id}) {
        # TODO: I've added system objects, so I don't want to limit the results to just
        #   what's owned by the current user, so I need to query the database about this
        #   type and change my tune if these belong to everyone.
        delete($local_params->{query}{user_id}) if (MinorImpact::Object::isSystem($local_params->{query}{object_type_id}));
    }
    my @objects = MinorImpact::Object::Search::search($local_params);
    foreach my $object (@objects) {
        $select .= "<option value='" . $object->id() . "'";
        if ($local_params->{selected} && $local_params->{selected} == $object->id()) {
            $select .= " selected";
        }
        $select .= ">" . $object->name() . "</option>\n";
    }
    $select .= "</select>\n";
    #MinorImpact::log('debug', "ending");
    return $select;
}

=head2 get

=over

=item ->get($field)

=item ->get($field, \%params)

=back

Return the value of $name. Will return an @array if $field is 
defined as an array.  See L<MinorImpact::Object::Field::add()|MinorImpact::Object::Field/add>.

  # get the object's name
  $object_name = $OBJECT->get("name");
  # get the description, and convert it from markdown to HTML.
  $object_description = $OBJECT->get("description", { mardown => 1});

=head3 params

=over

=item markdown => true/false

Treat the field as a markdown field, and convert the data to HTML before returning it.

=item one_line => true/false

For text fields, only data up to the first CR.

  $OBJECT->update({ decription => "This is\ntwo lines." });
  # get the description
  $short_desc = $OBJECT->get('description', { one_line => 1});
  # RESULT: $sort_desc = "This is";

=item truncate => $count

Only return up to $count characters of data.

  $OBJECT->update({ decription => "This is\ntwo lines." });
  # get the description
  $short_desc = $OBJECT->get('description', { truncate => 5});
  # RESULT: $sort_desc = "This";

=back

=cut

sub get {
    my $self = shift || return;
    my $name = shift || return;
    my $params = shift || {};

    my @values;
    #MinorImpact::log('debug', "starting(" . $self->id() . ")");
    if (defined($self->{data}->{$name})) {
       return $self->{data}->{$name};
    }
    if (defined($self->{object_data}->{$name})) {
        my $field = $self->{object_data}->{$name};
        my @value = $self->{object_data}->{$name}->value();
        #MinorImpact::log('debug',"$name='" . join(",", @value) . "'");
        foreach my $value (@value) {
            if ($params->{one_line}) {
                ($value) = $value =~/^(.*)$/m;
            }
            if ($params->{truncate} =~/^\d+$/) {
                $value = trunc($value, $params->{truncate});
            }
            if ($params->{markdown}) {
                $value =  markdown($value);
            }
            push(@values, $value);
        }
        if ($field->isArray()) {
            return @values;
        }
        return $values[0];
    }
}   

sub validateFields {
    my $fields = shift;
    my $params = shift;

    #MinorImpact::log('debug', "starting");

    #if (!$fields) {
    #   dumper($fields);
    #}
    #if (!$params) {
    #   dumper($params);
    #}

    #die "No fields to validate." unless ($fields);
    #die "No parameters to validate." unless($params);

    foreach my $field_name (keys %$params) {  
        my $field = $fields->{$field_name};
        next unless ($field);
        MinorImpact::log('debug', "validating $field_name='$field'");
        $field->validate($params->{$field_name});
    }
    #MinorImpact::log('debug', "ending");
}

sub toData {
    my $self = shift || return;

    my $data = {};
    $data->{id} = $self->id();
    $data->{name} = $self->name();
    $data->{type_id} = $self->typeID();
    my $fields = $self->fields();
    foreach my $name (keys %$fields) {
        my $field = $fields->{$name};
        my @values = $field->value();
        if ($field->isArray()) {
            $data->{$name} = \@values;
        } else {
            $data->{$name} = $values[0];
        }
    }
    @{$data->{tags}} = ($self->tags());
    return $data;
}

=head2 toString

=over

=item toString(\%params)

=back

Output the object as a string in a specified format.

  foreach $OBJECT (@OBJECTS) {
      $object_list .= $OBJECT->toString({format => 'row'});
  }

If no formatting is specified, outputs using the C<object_link> template, 
which is the name of the object as a link to the "object" page - the equivilant
of either of:

  $OBJECT->toString({template => 'object_link'});
  $OBJECT->toString({format => 'link'});

=head3 params

=over

=item format

Which output format to use.

=over

=item page

Standard full page representation.  Each field is processed and then formatted
via the C<row_column> template, using the variables C<name> and C<value>.  You can
override the default template by passing a different tempalte name using
the C<template> parameter.

The 'column' output also includes a &lt;!-- CUSTOM --&gt; string at the end, suitable
for replacement later.

=item json

JSON data object.

=item link

Use the "object_link" template.  Equivilant to:

  $output = $OBJECT->toString({template=>'object_link'});

=item list

Use the "object_list" template.  Equivilant to:

  $output = $OBJECT->toString({template=>'object_list'});

Intended to fall somewhere between the 'page' format and the 'link' format.

=item row

A horizontal represenation, each field as a table row of cells.

=item text

Just the object's name, no formating or markup.  Equivilant to L<$object->name()|MinorImpact::Object/name>.

=back

=item no_references

If set, this prevents the 'column' format from displaying a list of objects
that reference this object.

=item template

Output the object using a template.

  $output = $OBJECT->toString({template => 'object_template'});

The template will have access to the object via the C<object> variable.

=back

=cut

sub toString {
    my $self = shift || return;
    my $params = shift || {};
    MinorImpact::log('debug', "starting");

    my $script_name = $params->{script_name} || MinorImpact::scriptName() || 'index.cgi';

    my $MINORIMPACT = new MinorImpact();

    my $string = '';
    if ($params->{column}) { $params->{format} = "column"; }
    elsif ($params->{row}) { $params->{format} = "row"; }
    elsif ($params->{json}) { $params->{format} = "json"; }
    elsif ($params->{text}) { $params->{format} = "text"; }

    if ($params->{format} eq 'column' || $params->{format} eq 'page') {
        #$tt->process('object_column', { object=> $self}, \$string) || die $tt->error();
        $string .= "<div class='w3-container'>\n";
        foreach my $name (keys %{$self->{object_data}}) {
            my $field = $self->{object_data}{$name};
            #MinorImpact::log('info', "processing $name");
            my $type = $field->type();
            next if ($field->get('hidden'));
            my $value;
            if ($type =~/object\[(\d+)\]$/) {
                foreach my $v ($field->value()) {
                    if ($v && $v =~/^\d+/) {
                        my $o = new MinorImpact::Object($v);
                        $value .= $o->toString() if ($o);
                    }
                }
            } elsif ($type =~/text$/) {
                foreach my $val ($field->toString()) {
                    my $id = $field->id();
                    my $references = $self->getReferences($id);
                    foreach my $ref (@$references) {
                        my $test_data = $ref->{data};
                        $test_data =~s/\W/ /gm;
                        $test_data = join("\\W+?", split(/[\s\n]+/, $test_data));
                        if ($val =~/($test_data)/mgi) {
                            my $match = $1;
                            my $url = MinorImpact::url({ action => 'object', object_id => $ref->{object_id}});
                            $val =~s/$match/<a href='$url'>$ref->{data}<\/a>/;
                        }
                    }
                    $value .= "<div onmouseup='getSelectedText($id);'>$val</div>\n";
                }
            } else {
                $value = $field->toString();
            }
            my $row;
            MinorImpact::tt($params->{template} || 'row_column', {name=>$field->displayName(), value=>$value}, \$row);
            $string .= $row;
        }
        $string .= "<!-- CUSTOM -->\n";
        $string .= "</div>\n";

        unless ($params->{no_references}) {
            my $references = $self->getReferences();
            if (scalar(@$references)) {
                $string .= "<h2>References</h2>\n";
                $string .= "<table>\n";
                foreach my $ref (@$references) {
                    my $object = new MinorImpact::Object($ref->{object_id});
                    $string .= "<tr><td>" . $object->toString(). "</td><td></td></tr>\n";
                    $string .= "<tr><td colspan=2>\"" . $ref->{data} . "\"</td></tr>\n";
                }
                $string .= "</table>\n";
            }
        }

        foreach my $tag ($self->tags()) {
            my $t;
            MinorImpact::tt('tag', {tag=>$tag}, \$t);
            $string .= $t;
        }
    } elsif ($params->{format} eq 'json') {
        $string = to_json($self->toData());
    } elsif ($params->{format} eq 'list') {
        MinorImpact::tt('object_list', { object => $self }, \$string);
    } elsif ($params->{format} eq 'row') {
        $string = "<tr>";
        foreach my $key (keys %{$self->{data}}) {
            $string .= "<td>$self->{data}{$key}</td>";
        }
        $string .= "</tr>\n";
    } elsif ($params->{format} eq 'text') {
        $string = $self->name();
    } else {
        my $template = $params->{template} || 'object_link';
        MinorImpact::tt($template, { object => $self }, \$string);
    }
    MinorImpact::log('debug', "ending");
    return $string;
}


sub getReferences {
    my $self = shift || return;
    my $object_text_id = shift;

    my $DB = MinorImpact::db();
    if ($object_text_id) {
        # Only return references to a particular 
        return $DB->selectall_arrayref("select object_id, data, object_text_id from object_reference where object_text_id=?", {Slice=>{}}, ($object_text_id));
    }
    # Return all references for this object.
    return $DB->selectall_arrayref("select object.id as object_id, object_reference.data from object_reference, object_text, object where object_reference.object_text_id=object_text.id and object_text.object_id=object.id and object_reference.object_id=?", {Slice=>{}}, ($self->id()));
}

=head2 update

=over

=item update( { field => value [,...] })

=back

Update the value of one or more of the object fields.

=cut

sub update {
    my $self = shift || return;
    my $data = shift || return;
    my $params = shift || {};

    #MinorImpact::log('debug', "starting(" . $self->id() . ")");
    my $object_id = $self->id();

    unless ($self->name() || $data->{name}) {
        # Every object needs a name, even if it's not user editable or visible.
        $data->{name} = $self->typeName() . "-" . $self->id();
    }
    $self->{DB}->do("UPDATE object SET name=? WHERE id=?", undef, ($data->{'name'}, $self->id())) if ($data->{name});
    $self->{DB}->do("UPDATE object SET public=? WHERE id=?", undef, (($data->{'public'}?1:0), $self->id())) if (defined($data->{public}));;
    $self->{DB}->do("UPDATE object SET description=? WHERE id=?", undef, ($data->{'description'}, $self->id())) if (defined($data->{description}));
    $self->log('crit', $self->{DB}->errstr) if ($self->{DB}->errstr);

    MinorImpact::cache("object_data_$object_id", {});

    my $fields = $self->fields();
    #MinorImpact::log('info', "validating parameters");
    validateFields($fields, $data);

    foreach my $field_name (keys %$data) {
        #MinorImpact::log('debug', "updating \$field_name='$field_name'");
        my $field = $fields->{$field_name};
        next unless ($field);
        $field->update($data->{$field_name});
    }

    foreach my $param (keys %$data) {
        if ($param =~/^tags$/) {
            $self->{DB}->do("DELETE FROM object_tag WHERE object_id=?", undef, ($self->id()));
            MinorImpact::log('crit', $self->{DB}->errstr) if ($self->{DB}->errstr);
            foreach my $tag (split(/\0/, $data->{$param})) {
                foreach my $tag (parseTags($tag)) {
                    next unless ($tag);
                    $self->{DB}->do("INSERT INTO object_tag (name, object_id) VALUES (?,?)", undef, ($tag, $self->id())) || die("Can't add object tag:" . $self->{DB}->errstr);
                }
            }
        }
    }
    $self->_reload();
    #MinorImpact::log('debug', "ending");
    return;
}

sub fields {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log('debug', "starting");

    my $object_type_id;
    if (ref($self) eq "HASH") {
        $object_type_id = $self->{object_type_id};
        undef($self);
    } elsif (ref($self)) {
        #MinorImpact::log('info', "returning \$self->{object_data}") if (defined($self->{object_data}) && scalar(keys %{$self->{object_data}}));
        return $self->{object_data} if (defined($self->{object_data}) && scalar(keys %{$self->{object_data}}));
        $object_type_id = $self->typeID();
    } else {
        $object_type_id = $self;
        undef($self);
    }
    #MinorImpact::log('debug', "\$self='" .$self."'");

    die "No type_id defined\n" unless ($object_type_id);

    my $local_params = cloneHash($params);
    $local_params->{object_type_id} = $object_type_id;
    $local_params->{object_id} = $self->id() if ($self);
    my $fields = MinorImpact::Object::Type::fields($local_params);

    #MinorImpact::log('debug', "ending");
    return $fields;
}

sub type_id { 
    return MinorImpact::Object::typeID(@_); 
}

sub typeID {
    my $self = shift || return;

    MinorImpact::log('debug', "starting");
    my $object_type_id;
    if (ref($self)) {
        #MinorImpact::log('debug', "ref(\$self)='" . ref($self) . "'");
        $object_type_id = $self->{data}->{object_type_id};
    } else {
        my $DB = MinorImpact::db();
        MinorImpact::log('debug', "\$self='$self'");
        if ($self =~/^[0-9]+$/) {
            # This seems stupid, but sometimes on the client I don't know whether or not
            #   I have a name or an ID, so I just throw whatever I have into here.  If it
            #   was a number, I just get that back.
            $object_type_id = $self;
        } else {
            $object_type_id = MinorImpact::cache("object_type_id_$self");
            unless ($object_type_id) {
                my $singular = $self;
                $singular =~s/s$//;
                $object_type_id = $DB->selectrow_array("select id from object_type where name=? or name=? or plural=?", undef, ($self, $singular, $self));
                MinorImpact::cache("object_type_id_$self", $object_type_id);
            }
        }
    }
    MinorImpact::log('debug', "\$object_type_id='$object_type_id'");
    MinorImpact::log('debug', "ending");
    return $object_type_id;
}

=head1 SUBROUTINES

=cut

=head2 getTypeID

=over

=item ::getTypeID()

=back

Returns the 'default' type id for the current application, for when we 
desperately need some kind of object, but we don't know what, and we
don't much care.  This is used extensively in MinorImpact to fill
random lists and miscellaneous pages.

By default it will return if the id of the package named in the
L<default_object_type|MinorImpact::Manual::Configuration/settings> configuration
setting.  If unset, it will look for an object that isn't referenced
by another object (i.e, a "top level" object), or, if barring that, any 
object type that's not designated as 'system' or 'readonly'.

  # Generate a list of objects to display on the index page.
  @objects = MinorImpact::Object::search({ object_type_id => MinorImpact::Object::getTypeID(), 
                                           public => 1
                                         });
  MinorImpact::tt('index', { objects => [ @objects ] });

=cut

sub getTypeID {
    #MinorImpact::log('debug', "starting");

    my $DB = MinorImpact::db();

    if ($MinorImpact::SELF->{conf}{default}{default_object_type}) {
        return MinorImpact::Object::typeID($MinorImpact::SELF->{conf}{default}{default_object_type});
    }
    #
    # If there's no glbal object type, return the first 'toplevel' object, something that no other object
    #   references.
    my $object_type_id = MinorImpact::cache("default_object_type_id");
    unless ($object_type_id) {
        my $nextlevel = $DB->selectall_arrayref("SELECT DISTINCT object_type_id FROM object_field WHERE type LIKE 'object[%]'");
        if (scalar(@$nextlevel) > 0) {
            my $sql = "SELECT id FROM object_type WHERE id NOT IN (" . join(", ", ('?') x @$nextlevel) . ")";
            #MinorImpact::log('debug', "sql=$sql, params=" . join(",", map { $_->[0]; } @$nextlevel));
            $object_type_id = $DB->selectrow_array($sql, {Slice=>{}}, map {$_->[0]; } @$nextlevel);
        } else {
            # Just grab anything that's not a system object or 'readonly'.
            my $sql = "SELECT id FROM object_type WHERE system = 0 AND readonly = 0";
            #MinorImpact::log('debug', "sql=$sql");
            $object_type_id = $DB->selectrow_array($sql, {Slice=>{}});
            #MinorImpact::log('debug', "\$object_type_id='$object_type_id'");
        }
        MinorImpact::cache("default_object_type_id", $object_type_id);
    }

    #MinorImpact::log('debug', "ending");
    return $object_type_id;
}

=head2 typeIDs

Returns an array of object type IDs.

  foreach $type_id (MinorImpact::Object::typeIDs()) {
    print $type_id . ": " . MinorImpact::Object::typeName($type_id) . "\n";
  }

=cut

sub typeIDs {
    my @type_ids = ();

    my @types = MinorImpact::Object::types();
    foreach my $type (@types) {
        push(@type_ids, $type->{id});
    }

    return @type_ids;
}

=head2 types

Returns an array of object_type records.

  foreach my $type (MinorImpact::Object::types()) {
    print  $type->{id} . ": " . $type->{name} . "\n";
  }

=cut

sub types {
    my $DB = MinorImpact::db();

    my $select = "SELECT * FROM object_type";
    my $where = "WHERE id > 0 AND system = 0 AND readonly = 0";
    return @{$DB->selectall_arrayref("$select $where", {Slice=>{}})};
}

sub typeName {
    my $self = shift || return;
    my $params = shift || {};

    MinorImpact::log('debug', "starting");

    my $object_type_id;
    if (ref($self) eq 'HASH') {
        $params = $self;
        undef($self);
        $object_type_id = $params->{object_type_id} || $params->{type_id};
    } elsif (ref($self)) {
        $object_type_id = $params->{object_type_id} || $params->{type_id} || $self->typeID();
    } elsif($self) {
        $object_type_id = $self;
        undef($self);
    }
    MinorImpact::log('debug', "\$object_type_id='$object_type_id'");

    my $type_name;
    my $plural_name;
    if ($self && $object_type_id == $self->typeID()) {
        $type_name = $self->{type_data}->{name};
        $plural_name = $self->{type_data}->{plural};
    } else {
        my $DB = MinorImpact::db();
        my $where = "name=?";
        if ($object_type_id =~/^[0-9]+$/) {
            $where = "id=?";
        }

        my $sql = "select name, plural from object_type where $where";
        #MinorImpact::log('debug', "sql=$sql, ($object_type_id)");
        ($type_name, $plural_name) = $DB->selectrow_array($sql, undef, ($object_type_id));
    }

    MinorImpact::log('debug', "type_name=$type_name");
    MinorImpact::log('debug', "ending");

    if ($params->{plural}) {
        if (!$plural_name) {
            $plural_name = $type_name . "s";
        }
        return $plural_name;
    }
    return $type_name;
}

sub _reload {
    my $self = shift || return;
    my $params = shift || {};

    my $object_id = $self->id() || die "Can't get object id";

    #MinorImpact::log('debug', "starting(" . $object_id . ")");

    my $object_data = MinorImpact::cache("object_data_$object_id") unless ($params->{no_cache});
    if ($object_data) {
        #MinorImpact::log('debug', "collecting object_data from cache");
        $self->{data} = $object_data->{data};
        $self->{type_data} = $object_data->{type_data};
        $self->{object_data} = $object_data->{object_data};
        $self->{tags} = $object_data->{tags};
        return 
    }

    $self->{data} = $self->{DB}->selectrow_hashref("select * from object where id=?", undef, ($object_id));
    $self->{type_data} = $self->{DB}->selectrow_hashref("select * from object_type where id=?", undef, ($self->typeID()));

    undef($self->{object_data});

    $self->{object_data} = $self->fields();

    $self->{tags} = $self->{DB}->selectall_arrayref("SELECT * FROM object_tag WHERE object_id=?", {Slice=>{}}, ($object_id)) || [];
    $object_data->{data} = $self->{data};
    $object_data->{type_data} = $self->{type_data};
    $object_data->{object_data} = $self->{object_data};
    $object_data->{tags} = $self->{tags};
    MinorImpact::cache("object_data_$object_id", $object_data, 3600);

    #MinorImpact::log('debug', "ending(" . $object_id . ")");
    return;
}

sub dbConfig {
    # Placeholder.
    #MinorImpact::log('debug', "starting");
    #MinorImpact::log('debug', "ending");
    return;
}

sub delete {
    my $self = shift || return;
    my $params = shift || {};

    MinorImpact::log('debug', "starting(" . $self->id() . ")");
    my $object_id = $self->id();
    my $DB = MinorImpact::db();

    # TODO: I just realized what this is doing: when an object is deleted, anything that references it
    #   is just having the reference value cleared, and not even doing anything to try and come up with
    #   a new value for the affected dependencies.  That's insane.  At the very least, if anything references
    #   an object I'm trying to delete, I shouldn't be able to delete it.
    my $data = $DB->selectall_arrayref("select * from object_field where type like '%object[" . $self->typeID() . "]'", {Slice=>{}}) || die $DB->errstr;
    die "Object has references." if (scalar(@$data));
    #foreach my $row (@$data) {
    #    $DB->do("DELETE FROM object_data WHERE object_field_id=? and value=?", undef, ($row->{id}, $object_id)) || die $DB->errstr;
    #}

    MinorImpact::log('debug', "deleting object text fields");
    $data = $DB->selectall_arrayref("select * from object_text where object_id=?", {Slice=>{}}, ($object_id)) || die $DB->errstr;
    foreach my $row (@$data) {
        MinorImpact::log('debug', "deleting object text field '" . $row->{id} . "'");
        $DB->do("DELETE FROM object_reference WHERE object_text_id=?", undef, ($row->{id})) || die $DB->errstr;
    }

    MinorImpact::log('debug', "deleting object data fields");
    $DB->do("DELETE FROM object_data WHERE object_id=?", undef, ($object_id)) || die $DB->errstr;
    $DB->do("DELETE FROM object_text WHERE object_id=?", undef, ($object_id)) || die $DB->errstr;
    $DB->do("DELETE FROM object_reference WHERE object_id=?", undef, ($object_id)) || die $DB->errstr;
    $DB->do("DELETE FROM object_tag WHERE object_id=?", undef, ($object_id)) || die $DB->errstr;
    $DB->do("DELETE FROM object WHERE id=?", undef, ($object_id)) || die $DB->errstr;

    MinorImpact::cache("object_data_$object_id", {});
    MinorImpact::log('debug', "ending");
}

sub log {
    my $self = shift || return;
    my $level = shift || return;
    my $message = shift || return;

    return MinorImpact::log($level, $message);
}

=head2 tags

=over

=item ::tags([\%params])

=item ->tags([\%params])

=item ->tags(@tags)

=back

Called as a package subroutine, returns a list of all the tags defined for all
objects owned by the logged in user, or tags for all public objects owned by 
all admin users if the no one is logged in.

  @all_tags = MinorImpact::Object::tags();

Called as an object method, returns the tags assigned to an object.

  @tags = $OBJECT->tags();

Called as an object method with an array of @tags, replaces the objects tags.

  @tags = ("tag1", "tag2");
  $OBJECT->tags(@tags);

=cut

sub tags {
    my $self = shift;
    my $params = shift || {};
   
    my @tags = ();

    if (ref($self) eq "HASH") {
        $params = $self;
        undef($self);
    }
    if ($params && !ref($params)) {
       unshift($params);
       $params = {};
   }
   if ($self && !ref($self)) {
      unshift($self);
      undef($self);
   }

    unless ($self) {
        unless (defined($params->{query})) {
            $params->{query} = {};
            my $user = MinorImpact::user();
            if ($user) {
                $params->{query}{user_id} = $user->id();
            } else {
                $params->{query}{public} = 1;
            }
        }

        foreach my $object (MinorImpact::Object::Search::search($params)) {
            push(@tags, $object->tags());
        }
        # Not sure if I want to return just the unique tags.  So far, the only thing
        #   that's using this sub (MinorImpact::WWW::tags()) counts of the number of 
        #   each tag and diplays it.
        @tags = uniq(@tags) if ($params->{unique});

        return @tags;  
    }
   
    if (scalar(@_)) {
        $self->update({ tags => join(",", uniq(@_)) });
    }

    foreach my $data (@{$self->{tags}}) {
        push @tags, $data->{name};
    }
    return @tags;
}

=head2 getChildTypeIDs

=over

=item ::getChildTypeIDs(\%params)

=item ->getChildTypeIDs()

=back

Returns a list of oject types ids that have fields of a particular object type.
If called as a subroutine, requires C<object_type_id> as a parameter.

  @type_ids = MinorImpact::Object::getChildTypeIDs({object_type_id => $object_type_id});

If called as an object method, uses that object's type_id.

  @type_ids = $OBJECT->getChildTypeIDs();

... is equivilant to:

  @type_ids = MinorImpact::Object::getChildTypeIDs({object_type_id => $OBJECT->type_id()});

=head3 params

=over

=item object_type_id

Get a list of types that reference this type of object.
REQUIRED

=back

=cut

sub getChildTypeIDs {
    my $self = shift;
    my $params = shift || {};

    MinorImpact::log('debug', "starting");

    if (ref($self) eq 'HASH') {
        $params = $self;
        undef $self;
    }

    my $local_params = cloneHash($params);
    if (ref($self)) {
        $local_params->{object_type_id} = $self->typeID();
    }
    $local_params->{object_type_id} = $local_params->{type_id} if ($local_params->{type_id} && !$local_params->{object_type_id});

    my @childTypeIDs;
    my $sql = "select DISTINCT(object_type_id) from object_field where type like '%object[" . $local_params->{object_type_id} . "]'";
    my $DB = MinorImpact::db();
    my $data = $DB->selectall_arrayref($sql, {Slice=>{}});
    foreach my $row (@$data) {
        push(@childTypeIDs, $row->{object_type_id});
    }
    MinorImpact::log('debug', "ending");
    return @childTypeIDs;
}

sub getChildren {
    my $self = shift || return;
    my $params = shift || {};

    #MinorImpact::log('debug', "starting(" . $self->id() . ")");
    my $local_params = cloneHash($params);
    $local_params->{query}{object_type_id} = $local_params->{query}{type_id} if ($local_params->{query}{type_id} && !$local_params->{query}{object_type_id});
    $local_params->{query}{debug} .= "Object::getChildren();";
    #my $user_id = $self->userID();

    $local_params->{query}{where} = " AND object_data.object_field_id IN (SELECT id FROM object_field WHERE type LIKE ?) AND object_data.value = ?";
    $local_params->{query}{where_fields} = [ "%object[" . $self->typeID() . "]", $self->id() ];

    return MinorImpact::Object::Search::search($local_params);
}

# Returns true if the object supports a particular output type.
sub stringType {
    my $self = shift || return;
    my $params = shift  || return;

    my $string_type = 'string';

    if (ref($params) eq 'HASH') {
        $string_type = $params->{string_type} || 'string';
    } else {
        $string_type = $params;
    }

    if ($string_type eq 'string') {
        return 1;
    }
    return;
}

sub form {
    my $self = shift || {};
    my $params = shift || {};
    #MinorImpact::log('debug', "starting");
    
    if (ref($self) eq "HASH") {
        $params = $self;
        undef($self);
    } elsif (!ref($self)) {
        undef($self);
    }

    my $CGI = MinorImpact::cgi();
    my $user = MinorImpact::user() || die "Invalid user.";
    my $user_id = $user->id();

    my $local_params = cloneHash($params);
    #$local_params->{query}{debug} .= "Object::form();";
    my $type;
    if ($self) {
        $local_params->{object_type_id} = $self->typeID();
    } elsif (!($local_params->{object_type_id} || $local_params->{type_id})) {
        die "Can't create a form with no object_type_id.\n";
    }
    my $object_type_id = $local_params->{object_type_id} || $local_params->{type_id};

    my $form;
 
    # Suck in any default values passed in the parameters.
    foreach my $field (keys %{$local_params->{default_values}}) {
        $CGI->param($field,$params->{default_values}->{$field});
    }

    # Add fields for the last things they were looking at.
    unless ($self) {
        my $view_history = MinorImpact::WWW::viewHistory();
        foreach my $field (keys %$view_history) {
            my $value = $view_history->{$field};
            #MinorImpact::log('debug', "\$view_history->{$field} = '$value'");
            $CGI->param($field, $value) unless ($CGI->param($field));
        }
    }

    my $fields;
    my $no_name;
    my $public;
    my $no_tags;
    if ($self) {
        $fields = $self->{object_data};
        $no_name = $self->isNoName($local_params);
        $no_tags = $self->isNoTags($local_params);
        $public = $self->isPublic($local_params);
    } else {
        #MinorImpact::log('debug', "caching is " . ($local_params->{no_cache}?"off":"on"));
        $fields = MinorImpact::Object::fields($object_type_id, $local_params);
        $no_name = isNoName($object_type_id, $local_params);
        $no_tags = isNoTags($object_type_id, $local_params);
        $public = isPublic($object_type_id, $local_params);
    }
    my $script;
    my $form_fields;
    foreach my $name (keys %$fields) {
        my $field = $fields->{$name};
        my $field_type = $field->type();
        #MinorImpact::log('debug', "\$field->{name}='$field->{name}'");
        next if ($field->get('hidden') || $field->get('readonly'));
        my @params = $CGI->param($name);
        my @values;
        if (scalar(@params) > 0) {
            foreach my $field (@params) {
                push (@values, $field) unless ($field eq '');
            }
        } else {
            @values = $field->value();
        }

        my $local_params = cloneHash($params);
        $local_params->{name} = $name;
        $local_params->{value} = \@values;
        $local_params->{query}{user_id} = $user->id();
        $local_params->{query}{debug} .= "Object::form();";
        $form_fields .= $field->rowForm($local_params);
    }

    my $name = $CGI->param('name') || ($self && $self->name());
    $name = htmlEscape($name);
    my $search = $CGI->param('search');
    my $tags = $CGI->param('tags') || ($self && join(' ', $self->tags()));
    MinorImpact::tt('form_object', {
                                    form_fields    => $form_fields,
                                    javascript     => $script,
                                    object         => $self,
                                    object_type_id => $object_type_id,
                                    name           => $name,
                                    no_name        => $no_name,
                                    no_tags        => $no_tags,
                                    public         => $public,
                                    tags           => $tags,
                                }, \$form);
    #MinorImpact::log('debug', "ending");
    return $form;
}

=head2 cmp

=over

=item ->cmp()

=item ->cmp($comparison_object)

=back

Used to compare one object to another for purposes of sorting.
Without an argument, return the $value of the sortby field.

  # @sorted_object_list = sort { $a->cmp() cmp $b->cmp(); } @object_list;

With an object parameter, returns 0 if the cmp() value from both
objects are the same, <0 if $comparison_object->cmp() is larger,
or <0 if it's smaller.

  # @sorted_object_list = sort { $a->cmp($b); } @object_list;

=cut

sub cmp {
    my $self = shift || return;
    my $b = shift;

    my $sortby = 'name';
    foreach my $field_name (keys %{$self->{object_data}}) {
        my $field = $self->{object_data}{$field_name};
        $sortby = $field->name() if ($field->get('sortby'));
    }
    if ($b && ref($b)) {
        return ($self->get($sortby) cmp $b->cmp());
    }

    return $self->get($sortby);
}

# Returns the object_field id from the type/field name.
# Convenience method so searching/filtering can be done by name rather than id.
sub fieldID {
    my $object_type = shift || return;
    my $field_name = shift || return;

    MinorImpact::log('debug', "starting()");
    my $object_type_id = MinorImpact::Object::type_id($object_type);
    #MinorImpact::log('debug', "object_type_id='$object_type_id',field_name='$field_name'");
    my $DB = MinorImpact::db();
    MinorImpact::log('debug', "SELECT id FROM object_field WHERE object_type_id='$object_type_id' AND name='$field_name'");
    my $data = $DB->selectall_arrayref("SELECT id FROM object_field WHERE object_type_id=? AND name=?", {Slice=>{}}, ($object_type_id, $field_name));

    MinorImpact::log('debug', "ending()");
    if (scalar(@{$data}) > 0) {
        MinorImpact::log('debug', "end()");
        return @{$data}[0]->{id};
    }
    MinorImpact::log('debug', "end()");
}

sub fieldIDs {
    my $field_name = shift || return;

    # TODO: Cache results
    MinorImpact::log('debug', "starting");
    MinorImpact::log('debug', "field_name='$field_name'");
    my $DB = MinorImpact::db();
    MinorImpact::log('debug', "SELECT id FROM object_field WHERE name='$field_name'");
    my $data = $DB->selectall_arrayref("SELECT id FROM object_field WHERE name=?", {Slice=>{}}, ($field_name));
    my @fieldIDs;
    foreach my $row (@$data) {
        push(@fieldIDs, $row->{id});
    }
    MinorImpact::log('debug', "ending");
    return @fieldIDs;
}

# This is stupid, it's always going to be '1' per tag for a given object. But I'm leaving it for the selectall_hashref example.
sub getTagCounts {
    my $self = shift || return;

    my $DB = MinorImpact::db();
    my $VAR1 = $DB->selectall_hashref("select name, count(*) as tag_count from object_tag where object_id=? group by name", 'name', undef, ($self->id())) || die $DB->errstr;
    #$VAR1 = {
    #      'friend' => {
    #                    'tag_count' => '1',
    #                    'name' => 'friend'
    #                  },
    #      'work' => {
    #                  'tag_count' => '1',
    #                  'name' => 'work'
    #                },
    #      'roommate' => {
    #                      'tag_count' => '1',
    #                      'name' => 'roommate'
    #                    }
    #    };
    return $VAR1;
}

sub hasTag {
    my $self = shift || return;
    my $tag = shift || return;

    return scalar(grep(/^$tag$/, $self->tags()));
}

sub isNoName {
    my $self = shift || return;
    return isType($self, 'no_name', shift || {});
}

sub isPublic {
    my $self = shift || return;
    return isType($self, 'public', shift || {});
}

sub isReadonly {
    my $self = shift || return;
    return isType($self, 'readonly', shift || {});
}

sub isSystem {
    my $self = shift || return;
    return isType($self, 'system', shift || {});
}

sub isNoTags {
    my $self = shift || return;
    return isType($self, 'no_tags', shift || {});
}

=head2 isType

=over

=item ::isType($object_type_id, $setting )

=item ->isType($setting)

=back

Return the value of a particular $setting for a specified object type.

  # check to see if the MinorImpact::entry type supports tags.
  if (isType('MinorImpact::entry', 'no_tags')) {
    # tag stuff
  }

See L<MinorImpact::Object::Type::add()|MinorImpact::Object::Type/add> for 
more information on various settings when creating new MinorImpact types.

=cut

sub isType {
    my $self = shift || return;
    my $thingie = shift || return;
    my $params = shift || {};

    # TODO: You know that point where you get too tired to care any more, and however good something ends
    #   up being depends entirely on how high you were able get before that point?  I think I'm there.
    #   This whole system relies on objects being both substantiated and unsubstantiated, using the same
    #   functions in both cases simply using context to work out whether or not I'm a real boy or a ghost.
    #   In this case, I'm getting meta information about the type of object that will be created based on...
    #   shit.  That's not even what's happening here, this is base object, so anything calling this doesn't
    #   event know what type of object it's *going* to be? Wait, that can't be true, right? What the fuck is
    #   going on here?!
    if (ref($self) && ref($self) ne 'HASH') {
        return ($self->{type_data}->{$thingie}?1:0);
    } elsif (ref($self)) {
        # No idea, just assume it's not whatever.
        return;
    } else {
        my $object_type_id = $self;
        unless ($object_type_id =~/^\d+$/) {
            $object_type_id = MinorImpact::Object::typeID($object_type_id);
        }
        MinorImpact::log('debug', "\$object_type_id='$object_type_id', \$thingie='$thingie'");
        MinorImpact::log('debug', "cache is turned " . ($params->{no_cache}?'off':'on'));
        my $DB = MinorImpact::db();
        my $data = MinorImpact::cache("object_type_$object_type_id") unless ($params->{no_cache});
        unless ($data) {
            $data = $DB->selectrow_hashref("SELECT * FROM object_type ot WHERE ot.id=?", undef, ($object_type_id)) || die $DB->errstr;
            MinorImpact::cache("object_type_$object_type_id", $data);
        }
        return $data->{$thingie};
    }
    return;
}

# Take the same search parameters generated by MinorImpact::Object::Search::parseSearchString()
#   and check the object to see if it matches.
sub match {
    my $self = shift || return;
    my $query = shift || {};

    MinorImpact::log('debug', "starting(" . $self->id() . ")");

    # Check tags first.
    if (defined($query->{tag})) {
        my @tags = $self->tags();
        foreach my $tag (split(/,/, $query->{tag})) {
            if ($tag =~/^!(\w+)$/) {
                # We found it - that's bad.
                return if (indexOf($1, @tags));
            }
            # We didn't find it - that's bad.
            return unless(indexOf($tag, @tags));
        }
    }

    if ($query->{text}) {
        my $test = $query->{text};
        my $match = 1;
        if ($test =~/^!(.*)$/) {
            $test = $1;
            $match = 0;
        }

        my $fields = $self->fields();
        foreach my $field_name (keys %{$fields}) {
            foreach my $value ($fields->{$field_name}->value()) {
                next if ($value =~/^\d+$/);
                # Once anything matches, the game's over.  We just have to 
                #   determine if that was a good thing or a bad (!) thing.
                if ($value =~/$test/) {
                    return $match;
                }
            }
        }
        # Return the opposite of whatever $match was, because that was
        #  set to whether we did or did not (!) want to find what
        #  we were looking for.
        return ($match?0:1);
    }

    MinorImpact::log('debug', "ending");
    return 1;
}

=head2 search

=over

=item ::search(\%params)

=back

Search for objects.

  # get a list of public 'car' objects for a particular users.
  @objects = MinorImpact::Object::search({query => {object_type_id => 'car',  public => 1, user_id => $user->id() } });

This documentation is incomplete, as this is a shortcut to L<MinorImpact::Object::Search::search()|MinorImpact::Object::Search/search>.
Please visit the documentation for that function for more information.

=head3 params

=head4 query

=over

=item id_only

Return an array of object IDs, rather than complete objects.

  # get just the object IDs of dogs named 'Spot'.
  @object_ids = MinorImpact::Object::search({query => {object_type_id => 'dog', name => "Spot", id_only => 1}});

=back

=cut

sub search {
    return MinorImpact::Object::Search::search(@_);
}


=head2 validUser

=over

=item validUser( \%options ) 

=back

Verify that a given user has permission to instantiate this object.  Returns true for "system"
object types. Options:

=head3 options

=over

=item user

A MinorImpact::User object.  Defaults to the the current logged 
in user if one exists.

=back

=cut

sub validUser {
    my $self = shift || return;
    my $params = shift || {};

    MinorImpact::log('debug', "starting(" . $self->id() . ")");

    return 1 if ($self->isSystem() || $self->get('public'));

    if ($params->{proxy_object_id} && $params->{proxy_object_id} =~/^\d+$/ && $params->{proxy_object_id} != $self->id()) {
        my $object = new MinorImpact::Object($params->{proxy_object_id}) || die "Cannot create proxy object for validation.";
        return $object->validUser($params);
    }

    my $test_user = $params->{user} || MinorImpact::user($params);
    return unless ($test_user && ref($test_user) eq 'MinorImpact::User');
    #MinorImpact::log('debug', "\$test_user->id()='" . $test_user->id() . "'");
    #MinorImpact::log('debug', "\$self->userID()='" . $self->userID() . "'");

    my $valid = $test_user->isAdmin() || ($test_user->id() && $self->userID() && ($test_user->id() == $self->userID()));
    #MinorImpact::log('debug', $test_user->name() . " is " . ($valid?"valid":"invalid") . " for " . $self->name());
    MinorImpact::log('debug', "ending (\$valid='$valid')");
    return $valid;
}

=head2 version

=over

=item version()

=back

The value of the $VERSION variable of the inherited class, or 0.

=cut

sub version {
    my $self = shift || return;

    no strict 'refs';
    my $class = ref($self) || $self;
    my $version = ${$class . "::VERSION"} || 0;
    #MinorImpact::log('debug', "${class}::VERSION='$version'");
    return $version;
}

=head1 AUTHOR

Patrick Gillan <pgillan@minorimpact.com>

=cut

1;
