# NAME 

MinorImpact::Object - The base class for MinorImpact objects.

# SYNOPSIS

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

# DESCRIPTION

On the use of the terms "parent" and "child": In defiance of logic and common sense, perhaps, 
the terms "parent" and "child" are used the opposite of how one might expect.  For example: take a
"car" object and an "engine" object.  The car has an "engine" field from which one
can select from a list of engine objects which were defined elsewhere.  Since the engine
object can exist on its own, without reference to the car, the engine is the parent.  The
car _requires_ an engine, therefore it is the child, despite the logical and intutive
assumption that the car would be the parent, since the engine "belongs" to it.

A better example of where this _does_ (kind of) make sense is a "project" object and a "task" object.
The task must include a reference to the project - therefore the project is the parent and the
task is the child, since the project exists on its own, but the task requires a project as part of
its definition.

# METHODS

## new

- MinorImpact::Object::new( $id )
- MinorImpact::Object::new( \\%params )

Create a new MinorImpact::Object.

### params

- name => $string
- object\_type\_id => $int
- $field => $value

## back

- back( \\%options )

Returns the url that makes the most sense when returning from viewing or editing this 
object. 

### options

- url

    Additional url parameters that you want to be included in the link.

## clearCache

Clear the cache of items related to $OBJECT.

    $OBJECT->clearCache();

## id

- id() 

Returns the id of the this objec.t

## name

- name( \\%options )

Returns the 'name' value for this object.   Shortcut for ->get('name', \\%options). 

## public

- ->public()

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

## user

- user()

Return the user object of the owner of this object.  

    $user = $OBJECT->user();

... is a shortcut for:

    $user = new MinorImpact::User($OBJECT->get('user_id'));

## userID

- userID()

The ID of the user this object belongs to.

    $user_id = $OBJECT->userID();

## userName

- ->userName()

Return the name of the user that owns this object.

    $name = $OBJECT->userName();

## get

- ->get($field)
- ->get($field, \\%params)

Return the value of $name. Will return an @array if $field is 
defined as an array.  See [MinorImpact::Object::Field::add()](./MinorImpact_Object_Field.md#add).

    # get the object's name
    $object_name = $OBJECT->get("name");
    # get the description, and convert it from markdown to HTML.
    $object_description = $OBJECT->get("description", { mardown => 1});

### params

- markdown => true/false

    Treat the field as a markdown field, and convert the data to HTML before returning it.

- one\_line => true/false

    For text fields, only data up to the first CR.

        $OBJECT->update({ decription => "This is\ntwo lines." });
        # get the description
        $short_desc = $OBJECT->get('description', { one_line => 1});
        # RESULT: $sort_desc = "This is";

- ptrunc => $count

    Split the field into paragraphs, and only return the first $count.

        $OBJECT->get('content', { ptrunc => 2 });

- truncate => $count

    Only return up to $count characters of data.

        $OBJECT->update({ decription => "This is\ntwo lines." });
        # get the description
        $short_desc = $OBJECT->get('description', { truncate => 5});
        # RESULT: $sort_desc = "This";

## toData

Returns an object as a pure hash.

## toString

- toString(\\%params)

Output the object as a string in a specified format.

    foreach $OBJECT (@OBJECTS) {
        $object_list .= $OBJECT->toString({format => 'row'});
    }

If no formatting is specified, outputs using the `object_link` template, 
which is the name of the object as a link to the "object" page - the equivilant
of either of:

    $OBJECT->toString({template => 'object_link'});
    $OBJECT->toString({format => 'link'});

### params

- format

    Which output format to use.

    - page

        Standard full page representation.  Each field is processed and then formatted
        via the `row_column` template, using the variables `name` and `value`.  You can
        override the default template by passing a different tempalte name using
        the `template` parameter.

        The 'column' output also includes a &lt;!-- CUSTOM --&gt; string at the end, suitable
        for replacement later.

    - json

        Calls [MinorImpact::Object::toData()](./MinorImpact_Object.md#todata) and returns the
        result as a JSON formatted string.

    - link

        Use the "object\_link" template.  Equivilant to:

            $output = $OBJECT->toString({template=>'object_link'});

    - list

        Use the "object\_list" template.  Equivilant to:

            $output = $OBJECT->toString({template=>'object_list'});

        Intended to fall somewhere between the 'page' format and the 'link' format.

    - row

        A horizontal represenation, each field as a table row of cells.

    - text

        Just the object's name, no formating or markup.  Equivilant to [$object-](./$object-.md)name()|MinorImpact::Object/name>.

- no\_references

    If set, this prevents the 'column' format from displaying a list of objects
    that reference this object.

- template

    Output the object using a template.

        $output = $OBJECT->toString({template => 'object_template'});

    The template will have access to the object via the `object` variable.

## update

- update( { field => value \[,...\] })

Update the value of one or more of the object fields.

# SUBROUTINES

## getTypeID

- ::getTypeID()

Returns the 'default' type id for the current application, for when we 
desperately need some kind of object, but we don't know what, and we
don't much care.  This is used extensively in MinorImpact to fill
random lists and miscellaneous pages.

By default it will return if the id of the package named in the
[default\_object\_type](./MinorImpact_Manual_Configuration.md#settings) configuration
setting.  If unset, it will look for an object that isn't referenced
by another object (i.e, a "top level" object), or, if barring that, any 
object type that's not designated as 'system' or 'readonly'.

    # Generate a list of objects to display on the index page.
    @objects = MinorImpact::Object::search({ object_type_id => MinorImpact::Object::getTypeID(), 
                                             public => 1
                                           });
    MinorImpact::tt('index', { objects => [ @objects ] });

## typeIDs

- ::typeIDs()
- ::typeIDs(\\%params)

Returns an array of object type IDs.

    foreach $type_id (MinorImpact::Object::typeIDs()) {
      print $type_id . ": " . MinorImpact::Object::typeName($type_id) . "\n";
    }

### params

- admin => true/false

    Only return types that are or are not 'admin' types.

- system => true/false

    Only return types that are or are not 'system' types.

## types

- ::types()
- ::types(\\%params)

Returns an array of object\_type records.

    foreach my $type (MinorImpact::Object::types()) {
      print  $type->{id} . ": " . $type->{name} . "\n";
    }

### params

- admin => true/false

    Return only types that are or are not 'admin' types.

- format => $string
    - json

        Return the data as a JSON string.
- system => true/false

    Return only types that are or are not 'system' types.

## tags

- ::tags(\[\\%params\])
- ->tags(\[\\%params\])
- ->tags(@tags)

Called as a package subroutine, returns a list of all the tags defined for all
objects owned by the logged in user, or tags for all public objects owned by 
all admin users if the no one is logged in.

    @all_tags = MinorImpact::Object::tags();

Called as an object method, returns the tags assigned to an object.

    @tags = $OBJECT->tags();

Called as an object method with an array of @tags, replaces the objects tags.

    @tags = ("tag1", "tag2");
    $OBJECT->tags(@tags);

## getChildTypeIDs

- ::getChildTypeIDs(\\%params)
- ->getChildTypeIDs()

Returns a list of oject types ids that have fields of a particular object type.
If called as a subroutine, requires `object_type_id` as a parameter.

    @type_ids = MinorImpact::Object::getChildTypeIDs({object_type_id => $object_type_id});

If called as an object method, uses that object's type\_id.

    @type_ids = $OBJECT->getChildTypeIDs();

... is equivilant to:

    @type_ids = MinorImpact::Object::getChildTypeIDs({object_type_id => $OBJECT->type_id()});

### params

- object\_type\_id

    Get a list of types that reference this type of object.
    REQUIRED

## getChildren

- ->getChildren(\\%params)

Returns a list of objects with fields that refer to $OBJECT.

    $OBJECT->getChildren({ object_type_id => 'MinorImpact::comment' });

### params

See [MinorImpact::Object::Search::search()](./MinorImpact_Object_Search.md#search) for
a complete list of suppoerted parameters.

- object\_type\_id => $string

    Get childen of a particular type.

## form

- ::form(\\%params)
- ->form(\\%params)

Depending on whether or not it's called as a package sub or an object method, 
form() returns a string containing a blank HTML form (for adding a new object), or a 
competed form (for editing an existing object);

    if ($entry) {
        $form = $entry->form();
    } else {
        $form = MinorImpact::entry::form();
    }
    print "<html><body>$form</body></html>\n";

### params

- action => $string

    Input will be handled by MinorImapct::WWW::$string(), instead of the default add() or edit(). 

## cmp

- ->cmp()
- ->cmp($comparison\_object)

Used to compare one object to another for purposes of sorting.
Without an argument, return the $value of the sortby field.

    # @sorted_object_list = sort { $a->cmp() cmp $b->cmp(); } @object_list;

With an object parameter, returns 0 if the cmp() value from both
objects are the same, <0 if $comparison\_object->cmp() is larger,
or <0 if it's smaller.

    # @sorted_object_list = sort { $a->cmp($b); } @object_list;

## isType

- ::isType($object\_type\_id, $setting )
- ->isType($setting)

Return the value of a particular $setting for a specified object type.

    # check to see if the MinorImpact::entry type supports tags.
    if (isType('MinorImpact::entry', 'no_tags')) {
      # tag stuff
    }

See [MinorImpact::Object::Type::add()](./MinorImpact_Object_Type.md#add) for 
more information on various settings when creating new MinorImpact types.

## search

- ::search(\\%params)

Search for objects.

    # get a list of public 'car' objects for a particular users.
    @objects = MinorImpact::Object::search({query => {object_type_id => 'car',  public => 1, user_id => $user->id() } });

This documentation is incomplete, as this is a shortcut to [MinorImpact::Object::Search::search()](./MinorImpact_Object_Search.md#search).
Please visit the documentation for that function for more information.

### params

#### query

- id\_only

    Return an array of object IDs, rather than complete objects.

        # get just the object IDs of dogs named 'Spot'.
        @object_ids = MinorImpact::Object::search({query => {object_type_id => 'dog', name => "Spot", id_only => 1}});

## validUser

- validUser( \\%options ) 

Verify that a given user has permission to instantiate this object.  Returns true for "system"
object types. Options:

### options

- user

    A MinorImpact::User object.  Defaults to the the current logged 
    in user if one exists.

## version

- version()

The value of the $VERSION variable of the inherited class, or 0.

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
