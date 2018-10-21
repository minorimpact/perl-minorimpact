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
- MinorImpact::Object::new( { field => value\[, ...\] })

Create a new MinorImpact::Object.

## back

- back( \\%options )

Returns the url that makes the most sense when returning from viewing or editing this 
object. 

### options

- url

    Additional url parameters that you want to be included in the link.

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

Return the value of $name.

    # get the object's name
    $object_name = $OBJECT->get("name");
    # get the description, and convert it from markdown to HTML.
    $object_description = $OBJECT->get("description", { mardown => 1});

### params

- markdown

    Treat the field as a markdown field, and convert the data to HTML before returning it.

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

        JSON data object.

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

Returns an array of object type IDs.

    foreach $type_id (MinorImpact::Object::typeIDs()) {
      print $type_id . ": " . MinorImpact::Object::typeName($type_id) . "\n";
    }

## types

Returns an array of object\_type records.

    foreach my $type (MinorImpact::Object::types()) {
      print  $type->{id} . ": " . $type->{name} . "\n";
    }

## tags

- ::tags() 
- ->tags()
- ->tags(@tags)

Called as a package subroutine, returns a list of all the tags defined in the system
for all users and all objects.

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

## validateUser

- validateUser( \\%options ) 

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
