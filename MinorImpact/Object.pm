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
use MinorImpact::Object::Field;
use MinorImpact::Object::Search;
use MinorImpact::User;
use MinorImpact::Util;
use MinorImpact::Util::String;

my $OBJECT_CACHE;

=head1 METHODS

=cut

=head2 new

=over

=item MinorImpact::Object::new( $id )

=item MinorImpact::Object::new( \%params )

=back

Create a new MinorImpact::Object.

=head3 params

=over

=item name => $string

=item object_type_id => $int

=item $field => $value

=back

=cut

sub new {
    my $package = shift || return;
    my $id = shift || return;
    my $params = shift || {};

    MinorImpact::log('debug', "starting(" . $id . ")");

    my $DB = MinorImpact::db();
    my $object;
    my $object_data;

    # If we've created this object before, just return the cached version
    #   NOTE: This is local process cache, not a persistent external cache.
    return $OBJECT_CACHE->{$id} if ($OBJECT_CACHE->{$id} && !ref($id));

    eval {
        my $type_data;
        if (ref($id) eq "HASH") {
            $object_data = $id;
            undef($id);
            die "Can't create a new object without an object type id." unless ($object_data->{object_type_id});
            MinorImpact::log('debug', "getting type_id for $object_data->{object_type_id}");
            my $object_type_id = typeID($object_data->{object_type_id});
            $type_data = MinorImpact::cache("object_type_$object_type_id") unless ($params->{no_cache});
            unless ($type_data) {
                $type_data = $DB->selectrow_hashref("SELECT * FROM object_type WHERE id=?", undef, ($object_type_id)) || die $DB->errstr;
                MinorImpact::cache("object_type_$object_type_id", $type_data);
            }
        } else {
            $type_data = MinorImpact::cache("object_id_type_$id") unless ($params->{no_cache});
            unless ($type_data) {
                if ($id =~/^[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}$/i) {
                    $type_data = $DB->selectrow_hashref("SELECT ot.* FROM object o, object_type ot WHERE o.object_type_id=ot.id AND o.uuid=?", undef, (lc($id)));
                } elsif ($id =~/^\d+/) {
                    $type_data = $DB->selectrow_hashref("SELECT ot.* FROM object o, object_type ot WHERE o.object_type_id=ot.id AND o.id=?", undef, ($id));
                }
                if ($DB->errstr) {
                    die $DB->errstr;
                } elsif (!$type_data) {
                    die "unknown id '$id'";
                }
                MinorImpact::cache("object_id_type_$id", $type_data);
            }
        }
        my $type_name = $type_data->{name}; 
        MinorImpact::log('debug', "\$type_data->{name}='" . $type_data->{name} . "'");
        my $version = $type_data->{version};
        MinorImpact::log('debug', "\$type_data->{version}='" . $type_data->{version} . "'");
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
        # Check to make sure this data works with our fields before we add the new type.
        if (ref($object_data) eq "HASH") {
            my $fields = fields($type_name);
            validateFields($fields, $object_data);
        }

        $object = $type_name->new($id || $object_data, $params) if ($type_name);
    };
    my $error = $@;
    if ($error && ($error =~/^error:/ || $error !~/Can't locate object method "new"/)) {
        #$error =~s/ at \/.*$//;
        #$error =~s/^error://;
        my $i = $id;
        if (ref($object_data) eq "HASH") {
            $i = $object_data->{object_type_id};
        } 

        # Some errors are worth dying for...
        if ($error =~/invalid object /) {
            die $error;
        }

        # ... others are not
        MinorImpact::log('notice', "133,id='$id',$error");
        #die $error;
        return;
    }

    unless ($object) {
        $object = MinorImpact::Object::_new($package, $id||$object_data, $params);
    }

    die "permission denied" unless ($object->validUser() || $params->{admin});

    $OBJECT_CACHE->{$object->id()} = $object if ($object);
    $OBJECT_CACHE->{$id} = $object if ($object && !ref($id));
    MinorImpact::log('debug', "ending");
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
    $self->{DB} = MinorImpact::db() || die "can't get DB object\n";
    $self->{CGI} = MinorImpact::cgi() || die "can't get CGI object\n";

    my $user = MinorImpact::user();

    my $object_id;
    my $object_type_id;
    if (ref($id) eq 'HASH') {
        $object_type_id = $id->{object_type_id} || $id->{type_id} || $package || die "No object_type_id specified\n";
        MinorImpact::log('debug', "getting type_id for '$object_type_id'");
        $object_type_id = typeID($object_type_id);
        die "invalid type id" unless ($object_type_id);
        MinorImpact::log('debug', "got object_type_id='$object_type_id'");


        $user = new MinorImpact::User($id->{user_id}) if ($id->{user_id});
        die "invalid user id:" . $id->{user_id} unless ($user);

        $id->{uuid} = lc($id->{uuid}) || lc($id->{id}) || uuid();
        $id->{name} = $id->{uuid} unless ($id->{name});
        $self->{DB}->do("INSERT INTO object (name, user_id, description, object_type_id, uuid, create_date) VALUES (?, ?, ?, ?, ?, NOW())", undef, ($id->{'name'}, $user->id(), $id->{'description'}, $object_type_id, $id->{uuid})) || die("Can't add new object:" . $self->{DB}->errstr);
        $object_id = $self->{DB}->{mysql_insertid};
        unless ($object_id) {
            MinorImpact::log('notice', "Couldn't insert new object record");
            die "Couldn't insert new object record";
        }
    } elsif ($id =~/^[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}$/i) {
        $object_id = ${$self->{DB}->selectrow_arrayref("SELECT * FROM object WHERE uuid=?", undef, (lc($id)))}[0];
    } elsif ($id =~/^\d+$/) {
        $object_id = $id;
    } else {
        $object_id = $self->{CGI}->param("id") || MinorImpact::redirect();
    }

    $self->{data} = {};
    # These two fields are the absolute minimum requirement to be considered a valid object.
    $self->{data}{id} = $object_id;
    $self->{data}{object_type_id} = $object_type_id;

    if (ref($id) eq 'HASH') {
        $self->{data}{user_id} = $user->id() if ($user);
        my $fields = fields($id->{object_type_id});
        #MinorImpact::log('info', "validating fields: " . join(",", map { "$_=>'" . $fields->{$_} . "'"; } keys (%$fields)));
        #validateFields($fields, $id);

        $self->update($id, $params);
    } else {
        $self->_reload($params);
    }

    die "permission denied" unless $self->validUser();
    MinorImpact::log('debug', "ending(" . $self->id() . ")");
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

=head2 children

=over

=item ->children(\%params)

=back

Returns a list of objects with fields that refer to $OBJECT.

  $OBJECT->children({ object_type_id => 'MinorImpact::comment' });

=head3 params

See L<MinorImpact::Object::Search::search()|MinorImpact::Object::Search/search> for
a complete list of suppoerted parameters.

=over

=item object_type_id => $string

Get childen of a particular type.

=back

=cut

sub children {
    my $self = shift || return;
    my $params = shift || {};

    MinorImpact::log('debug', "starting(" . $self->id() . ")");
    my $local_params = clone($params);
    $local_params->{query}{object_type_id} = $local_params->{query}{type_id} if ($local_params->{query}{type_id} && !$local_params->{query}{object_type_id});
    $local_params->{query}{debug} .= "Object::children();";
    #my $user_id = $self->userID();

    $local_params->{query}{where} = " AND ((object_data.object_field_id IN (SELECT id FROM object_field WHERE type LIKE ?) AND object_data.value = ?)";
    $local_params->{query}{where_fields} = [ "%object[" . $self->typeID() . "]", $self->id() ];

    # Uncomment these two lines if we don't want the generic 'object' field to count as a 
    #   'child' of a particular type.  I don't know how all that's going to work.
    $local_params->{query}{where} .= " OR (object_data.object_field_id IN (SELECT id FROM object_field WHERE type = 'object') AND object_data.value = ?)";
    push(@{$local_params->{query}{where_fields}}, $self->id());

    $local_params->{query}{where} .= ")";

    my @children = MinorImpact::Object::Search::search($local_params);
    MinorImpact::log('debug', "ending");
    return @children;
}

=head2 childTypeIDs

=over

=item ::childTypeIDs(\%params)

=item ->childTypeIDs()

=back

Returns a list of oject types ids that have fields of a particular object type.
If called as a subroutine, requires C<object_type_id> as a parameter.

  @type_ids = MinorImpact::Object::childTypeIDs({object_type_id => $object_type_id});

If called as an object method, uses that object's type_id.

  @type_ids = $OBJECT->childTypeIDs();

... is equivilant to:

  @type_ids = MinorImpact::Object::childTypeIDs({object_type_id => $OBJECT->type_id()});

=head3 params

=over

=item object_type_id

Get a list of types that reference this type of object.
REQUIRED

=back

=cut

sub childTypeIDs {
    my $self = shift || return;
    my $params = shift || {};

    if (ref($self) eq 'HASH') {
        $params = $self;
        undef $self;
    }

    MinorImpact::log('debug', "starting");
    $params->{object_type_id} = $self->typeID() if ($self);
    die "no object type id" unless ($params->{object_type_id});

    my @child_type_ids = MinorImpact::Object::Type::childTypeIDs($params);

    MinorImpact::log('debug', "ending");
    return @child_type_ids;
}


=head2 childTypes

Returns an array of MinorImpact::Object::Type objects that reference objects of
this particular object's type.

  @child_types = $OBJECT->childTypes()

=cut

sub childTypes {
    my $self = shift || return;
    my $params = shift || {};

    if (ref($self) eq 'HASH') {
        $params = $self;
        undef($self);
    }

    MinorImpact::log('debug', "starting");
    $params->{object_type_id} = $self->typeID() if ($self);
    die "no object type id" unless ($params->{object_type_id});

    my @child_types = MinorImpact::Object::Type::childTypes($params);
    MinorImpact::log('debug', "ending");
    return @child_types;
}

sub churn {
    return;
}

=head2 clearCache

Clear the cache of items related to $OBJECT.

  $OBJECT->clearCache();

=cut

sub clearCache {
    my $self = shift || return;

    my $object_id;
    my $object_uuid;

    if (ref($self)) {
        $object_id = $self->id();
        $object_uuid = $self->get('uuid');
    } else {
        $object_id = $self;
        undef($self);
    }

    delete($OBJECT_CACHE->{$object_id});
    MinorImpact::cache("object_data_$object_id", {});
    MinorImpact::cache("object_id_type_$object_id", {});

    if ($object_uuid) {
        delete($OBJECT_CACHE->{$object_uuid});
        MinorImpact::cache("object_data_$object_uuid", {});
        MinorImpact::cache("object_id_type_$object_uuid", {});
    }

    return;
}

=head2 field

=over

=item ->field($name)

=item ->field($id)

=back

Returns a particular field object, given the field's name or id.

=cut

sub field {
    my $self = shift || return;
    my $name = shift || return;

    my $fields = $self->fields();
    if (defined($fields->{$name})) {
        return $fields->{$name};
    }
    if ($name =~/^\d+$/) {
       foreach my $field_name (keys %{$fields}) {
           my $field = $fields->{$field_name};
           return $field if ($field->id() == $name);
       } 
    }
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

    MinorImpact::log('debug', "starting");
    my $local_params = cloneHash($params);
    $local_params->{query}{debug} .= "Object::selectList();";
    if (ref($self) eq 'HASH') {
        $local_params = cloneHash($self);
        $local_params->{query}{debug} .= "Object::selectList();";
        if ($local_params->{selected}) {
            $self = new MinorImpact::Object($local_params->{selected});
            #$local_params->{query}{user_id} = $self->userID() if ($self && !$local_params->{query}{user_id});
            delete($local_params->{query}{user_id}) if ($self->isSystem());
        } else {
            undef $self;
        }
    } elsif (ref($self)) {
        #$local_params->{query}{user_id} ||= $self->userID();
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
    MinorImpact::log('debug', "ending");
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

This always returns the 'raw' value of the field.

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

=item ptrunc => $count

Split the field into paragraphs, and only return the first $count.

  $OBJECT->get('content', { ptrunc => 2 });

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

    MinorImpact::log('debug', "starting(" . $self->id() . "-$name)");

    my @values;
    # Return attributes.  $self->{data} contains elements of the 
    #   "standard" object definition: user id, public, name, 
    #   creation date - that sort of thing.
    if (defined($self->{data}->{$name})) {
        my $value;
        if ($name eq 'uuid') {
            $value = lc($self->{data}->{uuid});
        } else {
            $value = $self->{data}->{$name};
        }
        MinorImpact::log('debug', "ending");
        return $value;
    } elsif (defined($self->{object_data}->{$name})) {
        my $field = $self->{object_data}->{$name};
        my @value = $field->value($params);
        #MinorImpact::log('debug',"$name='" . join(",", @value) . "'");
        foreach my $value (@value) {
            if ($params->{one_line}) {
                ($value) = $value =~/^(.*)$/m;
            }
            if ($params->{truncate} =~/^\d+$/) {
                $value = trunc($value, $params->{truncate});
            }
            if ($params->{ptrunc} =~/^\d+$/) {
                $value = ptrunc($value, $params->{ptrunc});
            }
            if ($params->{markdown}) {
                $value =  markdown($value);
            }
            if ($params->{references}) {
                $value = "<div onmouseup='getSelectedText(" . $self->id() . "," . $field->id() . ");'>$value</div>\n";
            }
            push(@values, $value);
        }
        if ($field->isArray()) {
            MinorImpact::log('debug', "ending");
            return @values;
        }
        MinorImpact::log('debug', "ending");
        return $values[0];
    }
    MinorImpact::log('debug', "ending");
}   

sub validateFields {
    my $fields = shift;
    my $params = shift;

    MinorImpact::log('debug', "starting");

    #if (!$fields) {
    #   dumper($fields);
    #}
    #if (!$params) {
    #   dumper($params);
    #}

    #die "No fields to validate." unless ($fields);
    #die "No parameters to validate." unless($params);

    foreach my $field_name (keys %$params) {  
        MinorImpact::log('debug', "looking for $field_name");
        my $field = $fields->{$field_name};
        next unless ($field);
        MinorImpact::log('debug', "unpacking $field_name");
        my @values = MinorImpact::Object::Field::unpackValues($params->{$field_name});
        foreach my $value (@values) {
            MinorImpact::log('debug', "validating $field_name='$value'");
            $field->validate($value);
        }
    }
    MinorImpact::log('debug', "ending");
}

=head2 toData

Returns an object as a pure hash.

=cut

sub toData {
    my $self = shift || return;

    my $data = {};
    $data->{id} = $self->id();
    $data->{create_date} = $self->get('create_date');
    $data->{name} = $self->name();
    $data->{public} = $self->get('public');
    $data->{object_type_id} = $self->type()->name();
    $data->{user_id} = lc($self->user()->get('uuid'));
    my $fields = $self->fields();
    foreach my $name (keys %$fields) {
        my $field = $fields->{$name};
        my @values = $field->value();
        $data->{$name} = [];
        foreach my $value (@values) {
            if (ref($value)) {
                push(@{$data->{$name}}, lc($value->get('uuid')));
            } else {
                push(@{$data->{$name}}, $value);
            }
        }
    }
    $data->{uuid} = lc($self->get('uuid'));
    $data->{tags} = join("\0", $self->tags());

    foreach my $reference ($self->references()) {
        my $object = new MinorImpact::Object($reference->{object_id});
        if ($object) {
            $reference->{object_uuid} = $object->get('uuid');
        }
    }
    $data->{references} = \@{$self->references()};
        
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

Calls L<MinorImpact::Object::toData()|MinorImpact::Object/todata> and returns the
result as a JSON formatted string.

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

    my $string = '';
    if ($params->{column}) { $params->{format} = "column"; }
    elsif ($params->{row}) { $params->{format} = "row"; }
    elsif ($params->{json}) { $params->{format} = "json"; }
    elsif ($params->{text}) { $params->{format} = "text"; }

    if ($params->{format} eq 'column' || $params->{format} eq 'page') {
        #$tt->process('object_column', { object=> $self}, \$string) || die $tt->error();
        $string .= "<div class='w3-container'>\n";
        $string .= "<h3>" . $self->name() . "</h3>\n" unless ($self->isNoName());
        foreach my $name (keys %{$self->{object_data}}) {
            my $field = $self->{object_data}{$name};
            #MinorImpact::log('info', "processing $name");
            my $field_type = $field->type();
            next if ($field->get('hidden'));
            my $value = $field->toString({references => 1});;
            my $row;
            MinorImpact::tt($params->{template} || 'row_column', {
                    name=>$field->displayName(), 
                    value=>$value
                }, \$row);
            $string .= $row;
        }
        $string .= "<!-- CUSTOM -->\n";
        $string .= "</div>\n";

        #unless ($params->{no_references}) {
        #    my @references = $self->references();
        #    if (scalar(@references)) {
        #        $string .= "<h2>References</h2>\n";
        #        $string .= "<table>\n";
        #        foreach my $ref (@references) {
        #            my $object = new MinorImpact::Object($ref->{object_id});
        #            $string .= "<tr><td>" . $object->toString(). "</td><td></td></tr>\n";
        #            $string .= "<tr><td colspan=2>\"" . $ref->{data} . "\"</td></tr>\n";
        #        }
        #        $string .= "</table>\n";
        #    }
        #}

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
        MinorImpact::log('debug', "depth='" . $params->{depth} . "'");
        MinorImpact::tt($template, { 
                depth => $params->{depth} || 0,
                object => $self 
            }, \$string);
    }
    MinorImpact::log('debug', "ending");
    return $string;
}

=head2 references

=over

=item ->references()

=back

Returns an array of hashes that contain all the object
references created for this object.

  @refs = $OBJECT->references();
  foreach $ref (@refs) {
    print $ref->{object_id} . ":" . $ref->{data} . "\n"; # 1:foo
  }

=head3 fields

=over

=item data

The actual text of the reference.

=item object_id

The id of the object the text belongs to.

=back

=cut

sub references {
    my $self = shift || die "no object";
    MinorImpact::log('debug', "starting");

    my @references = MinorImpact::Object::Search::search({
        query => {
            object_type_id => 'MinorImpact::reference',
            reference_object => $self->id()
        }
    });

    MinorImpact::log('debug', "ending");
    return @references;
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

    MinorImpact::log('debug', "starting(" . $self->id() . ")");

    die "Invalid user" unless ($self->validUser({mode => 'write'}));

    $self->clearCache();

    unless ($self->name() || $data->{name}) {
        # Every object needs a name, even if it's not user editable or visible.
        $data->{name} = $self->typeName() . "-" . $self->id();
    }
    $self->{DB}->do("UPDATE object SET create_date=? WHERE id=?", undef, ($data->{'create_date'}, $self->id())) if ($data->{create_date});
    $self->{DB}->do("UPDATE object SET description=? WHERE id=?", undef, ($data->{'description'}, $self->id())) if (defined($data->{description}));
    $self->{DB}->do("UPDATE object SET name=? WHERE id=?", undef, ($data->{'name'}, $self->id())) if ($data->{name});
    $self->{DB}->do("UPDATE object SET public=? WHERE id=?", undef, (($data->{'public'}?1:0), $self->id())) if (defined($data->{public}));;
    $self->{DB}->do("UPDATE object SET uuid=? WHERE id=?", undef, (lc($data->{'uuid'}), $self->id())) if ($data->{uuid});
    $self->log('crit', $self->{DB}->errstr) if ($self->{DB}->errstr);


    my $fields = $self->fields();
    #MinorImpact::log('info', "validating parameters");
    validateFields($fields, $data);

    foreach my $field_name (keys %$data) {
        my $field = $fields->{$field_name};
        next unless ($field);
        MinorImpact::log('debug', "updating \$field_name='$field_name'");
        $field->update($data->{$field_name});
    }

    foreach my $param (keys %$data) {
        if ($param =~/^tags$/) {
            $self->{DB}->do("DELETE FROM object_tag WHERE object_id=?", undef, ($self->id()));
            MinorImpact::log('crit', "tags:" . $self->{DB}->errstr) if ($self->{DB}->errstr);
            foreach my $tag (split(/\0/, $data->{$param})) {
                foreach my $tag (parseTags($tag)) {
                    next unless ($tag);
                    $self->{DB}->do("INSERT INTO object_tag (name, object_id) VALUES (?,?)", undef, ($tag, $self->id())) || die("Can't add object tag:" . $self->{DB}->errstr);
                }
            }
        }
    }
    $self->_reload();
    MinorImpact::log('debug', "ending");
    return;
}

sub fields {
    my $self = shift || return;
    my $params = shift || {};

    MinorImpact::log('debug', "starting");

    my $object_type_id;
    my $object_id;
    if (ref($self) eq "HASH") {
        $object_type_id = $self->{object_type_id};
        undef($self);
    } elsif (ref($self)) {
        #MinorImpact::log('info', "returning \$self->{object_data}") if (defined($self->{object_data}) && scalar(keys %{$self->{object_data}}));
        return $self->{object_data} if (defined($self->{object_data}) && scalar(keys %{$self->{object_data}}));
        $object_type_id = $self->typeID();
        $object_id = $self->id();
    } else {
        $object_type_id = $self;
        undef($self);
    }
    #MinorImpact::log('debug', "\$self='" .$self."'");

    die "No type_id defined\n" unless ($object_type_id);

    my $type = new MinorImpact::Object::Type($object_type_id);
    my $fields = $type->fields({object_id=>$object_id});

    MinorImpact::log('debug', "ending");
    return $fields;
}

sub type {
    my $self = shift || return;
    MinorImpact::log('debug', "starting");

    my $object_type_id;
    if (ref($self)) {
        $object_type_id = $self->typeID();
    } else {
        $object_type_id = $self;
        undef($self);
    }

    MinorImpact::log('debug', "\$object_type_id='" . $object_type_id . "'");
    my $type = new MinorImpact::Object::Type($object_type_id);
    MinorImpact::log('debug', "\$type->name()='" . $type->name() . "'");

    MinorImpact::log('debug', "ending");
    return $type;
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
            if ($object_type_id) {
                MinorImpact::log('debug', "from cache: \$object_type_id='$object_type_id'");
            } else {
                my $singular = $self;
                $singular =~s/s$//;
                my $sql = "SELECT id FROM object_type WHERE name=? OR name=? OR plural=? OR uuid=?";
                MinorImpact::log('debug', "\$sql='$sql', ($self, $singular, $self, $self)");
                $object_type_id = $DB->selectrow_array($sql, undef, ($self, $singular, $self, lc($self)));
                MinorImpact::cache("object_type_id_$self", $object_type_id) if ($object_type_id);
            }
        }
    }

    MinorImpact::log('debug', "\$object_type_id='$object_type_id'");
    MinorImpact::log('debug', "ending");
    return $object_type_id;
}

=head1 SUBROUTINES

=cut

sub getType {
    return MinorImpact::Object::type(@_);
}

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

=over

=item ::typeIDs()

=item ::typeIDs(\%params)

=back

Returns an array of object type IDs.

  foreach $type_id (MinorImpact::Object::typeIDs()) {
    print $type_id . ": " . MinorImpact::Object::typeName($type_id) . "\n";
  }

=head3 params

=over

=item admin => true/false

Only return types that are or are not 'admin' types.

=item system => true/false

Only return types that are or are not 'system' types.

=back

=cut

sub typeIDs {
    my $params = shift || {};

    my @type_ids = ();
    my @types = MinorImpact::Object::types($params);
    foreach my $type (@types) {
        push(@type_ids, $type->id());
    }

    return @type_ids;
}

=head2 types

=over

=item ::types()

=item ::types(\%params)

=back

Returns an array of object_type records.

  foreach my $type (MinorImpact::Object::types()) {
    print  $type->{id} . ": " . $type->{name} . "\n";
  }

=head3 params

=over

=item admin => true/false

Return only types that are or are not 'admin' types.

=item format => $string

=over

=item json

Return the data as a JSON string.

=back

=item system => true/false

Return only types that are or are not 'system' types.

=back

=cut

sub types {
    my $params = shift || {};

    my $DB = MinorImpact::db();

    my $select = "SELECT * FROM object_type";
    my $where = "WHERE id > 0";
    if (defined($params->{readonly})) {
       $where .= " AND readonly = " . isTrue($params->{readonly});
    }
    if (defined($params->{system})) {
       $where .= " AND system = " . isTrue($params->{system});
    }

    my $data = $DB->selectall_arrayref("$select $where", {Slice=>{}});
    if ($params->{format} eq 'json') {
        return to_json($data);
    }

    my @types = ();
    foreach my $row (@$data) {
        push (@types, new MinorImpact::Object::Type($row->{id}));
    }

    return @types;
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

        my $sql = "SELECT name, plural FROM object_type WHERE $where";
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
        #MinorImpact::log('debug', "collecting object_data FROM cache");
        $self->{data} = $object_data->{data};
        $self->{type_data} = $object_data->{type_data};
        $self->{object_data} = $object_data->{object_data};
        $self->{tags} = $object_data->{tags};
        return 
    }

    $self->{data} = $self->{DB}->selectrow_hashref("SELECT * FROM object WHERE id=?", undef, ($object_id));
    $self->{type_data} = $self->{DB}->selectrow_hashref("SELECT * FROM object_type WHERE id=?", undef, ($self->typeID()));

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

    my $name = __PACKAGE__;
    my $type = MinorImpact::Object::Type::add({ name => $name, public=>1 });

    #MinorImpact::log('debug', "ending");
    return;
}

=head2 delete

=over

=item ->delete()

=back

Deletes an object and anything that references it.

  $OBJECT->delete();

=cut

sub delete {
    my $self = shift || return;
    my $params = shift || {};

    MinorImpact::log('debug', "starting(" . $self->id() . ")");

    die "invalid user" unless ($self->validUser({mode => 'delete' }));

    my $object_id = $self->id();
    my $DB = MinorImpact::db();

    my @children = $self->children();
    foreach my $child (@children) {
        $child->delete();
    }

    my $data = $DB->selectall_arrayref("SELECT * FROM object_text WHERE object_id=?", {Slice=>{}}, ($object_id)) || die $DB->errstr;
    foreach my $row (@$data) {
        $DB->do("DELETE FROM object_reference WHERE object_text_id=?", undef, ($row->{id})) || die $DB->errstr;
    }

    $DB->do("DELETE FROM object_data WHERE object_id=?", undef, ($object_id)) || die $DB->errstr;
    $DB->do("DELETE FROM object_text WHERE object_id=?", undef, ($object_id)) || die $DB->errstr;
    $DB->do("DELETE FROM object_reference WHERE object_id=? OR reference_object_id=?", undef, ($object_id, $object_id)) || die $DB->errstr;
    $DB->do("DELETE FROM object_tag WHERE object_id=?", undef, ($object_id)) || die $DB->errstr;
    $DB->do("DELETE FROM object WHERE id=?", undef, ($object_id)) || die $DB->errstr;

    $self->clearCache();
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

=head2 form

=over

=item ::form(\%params)

=item ->form(\%params)

=back

Depending on whether or not it's called as a package sub or an object method, 
form() returns a string containing a blank HTML form (for adding a new object), or a 
competed form (for editing an existing object);

  if ($entry) {
      $form = $entry->form();
  } else {
      $form = MinorImpact::entry::form();
  }
  print "<html><body>$form</body></html>\n";

=head3 params

=over

=item action => $string

Input will be handled by MinorImapct::WWW::$string(), instead of the default add() or edit(). 

=back

=cut

sub form {
    my $self = shift || {};
    my $params = shift || {};

    MinorImpact::log('debug', "starting");
    
    if (ref($self) eq "HASH") {
        $params = $self;
        undef($self);
    } elsif (!ref($self)) {
        undef($self);
    }

    my $CGI = MinorImpact::cgi();
    my $user = MinorImpact::user({ force => 1 });
    my $user_id = $user->id();

    my $local_params = cloneHash($params);

    $local_params->{object_type_id} = $self->typeID() if ($self);
    my $object_type_id = $local_params->{object_type_id} || $local_params->{type_id};
    die "no object type id" unless ($object_type_id);

    my $type = new MinorImpact::Object::Type($object_type_id);

    my $form;
 
    # Suck in any default values passed in the parameters.
    foreach my $field (keys %{$local_params->{default_values}}) {
        $CGI->param($field,$params->{default_values}->{$field});
    }

    my $fields;
    if ($self) {
        $fields = $self->fields(); #{object_data};
    } else {
        #MinorImpact::log('debug', "caching is " . ($local_params->{no_cache}?"off":"on"));
        #$fields = MinorImpact::Object::Type::fields($local_params);
        $fields = $type->fields();
    }

    my $action = (defined($params->{action}) && $params->{action})?$params->{action}:($self?"edit":"add");

    my $script;
    my $form_fields;
    foreach my $name (keys %$fields) {
        my $field = $fields->{$name};
        MinorImpact::log('debug', "\$field->name()='" . $field->name() . "'");
        my $field_type = $field->type();
        my @param_values = $CGI->param($name);
        my @values;
        if (scalar(@param_values) > 0) {
            foreach my $param_value (@param_values) {
                push (@values, $param_value) unless ($param_value eq '');
            }
        } else {
            @values = $field->value();
        }

        # If the values aren't already set, and the field is both required and 
        #   a MinorImpact::Object::Type, then set it to the last thing they were looking at.
        if (scalar(@values) == 0 && $field->isRequired() && ref($field_type)) {
            my $last_id = MinorImpact::WWW::viewHistory($field_type->name());
            push(@values, $last_id) if ($last_id);
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
                                    action         => $action,
                                    form_fields    => $form_fields,
                                    javascript     => $script,
                                    object         => $self,
                                    name           => $name,
                                    type           => $type,
                                    tags           => $tags,
                                }, \$form);
    MinorImpact::log('debug', "ending");
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
    my $VAR1 = $DB->selectall_hashref("SELECT name, count(*) as tag_count FROM object_tag WHERE object_id=? group by name", 'name', undef, ($self->id())) || die $DB->errstr;
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

    my $object_type_id;
    if (ref($self) eq 'HASH') {
        $object_type_id = $self->{object_type_id};
    } if (ref($self)) {
        $object_type_id = $self->typeID();
    } else {
        $object_type_id = $self;
    }

    my $type = new MinorImpact::Object::Type($object_type_id) || return;

    return $type->get($thingie);
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
                if (ref($value) && $value->name() =~/$test/) {
                    return $match;
                } elsif ($value =~/$test/) {
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

    $params->{mode} = 'read' unless (defined($params->{mode}) && $params->{mode});

    if ($params->{mode} eq 'read') {
        if ($self->isSystem() || $self->get('public')) {
            MinorImpact::log('debug', "Read access granted to " . $self->name() . ": system or public object");
            return 1;
        }
    }

    if ($params->{proxy_object_id} && $params->{proxy_object_id} =~/^\d+$/ && $params->{proxy_object_id} != $self->id()) {
        my $object = new MinorImpact::Object($params->{proxy_object_id}) || die "Cannot create proxy object for validation.";
        return $object->validUser($params);
    }

    my $test_user = $params->{user} || MinorImpact::user($params);
    unless ($test_user && ref($test_user) eq 'MinorImpact::User') {
        MinorImpact::log('debug', "Access denied to " . $self->name() . ": no test user");
        return 0;
    }

    if ($test_user->isAdmin()) {
        MinorImpact::log('debug', "Access granted to " . $self->name() . ": admin user");
        return 1;
    }

    if ($test_user->id() && $self->userID() && ($test_user->id() == $self->userID())) {
        MinorImpact::log('debug', "Access granted to " . $self->name() . ": owner");
        return 1;
    }
    MinorImpact::log('debug', "Access denied to " . $self->name() . ": no particular reason");
    MinorImpact::log('debug', "\$test_user->id()='" . $test_user->id() ."'");
    MinorImpact::log('debug', "\$self->userID()='" . $self->userID() ."'");
    return 0;
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
    MinorImpact::log('debug', "${class}::VERSION='$version'");
    return $version;
}

=head1 AUTHOR

Patrick Gillan <pgillan@minorimpact.com>

=cut

1;
