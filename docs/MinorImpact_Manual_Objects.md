# NAME

MinorImpact::Manual::Objects

# DESCRIPTION

## Types

Make a new object type named "vehicle":

    $type = MinorImpact:Object:Type::add({name => "vehicle" });

Add a field indicating the number of doors a "vehicle" object will have:

    $type->addField({ name => "door_count", type => "int" });

Create a new MinorImpact::Object::Type object to represent the "vehicle" type:

    $vehicle = new MinorImpact::Object::Type("vehicle");

Generate an html form for adding a new "vehicle":

    $form = $vehicle->form();

## Fields

Creating a standalone field with a preset value:

    $field = new MinorImpact::Object::Field({ db => { name => 'balloon_count', type=>'int' }, value => 5});

Including that field on on a form:

    $form .= $field->rowForm();

### Built in Fields

- create\_date

    The date the object was created.

- id

    The internal ID of the object.

- mod\_date

    The date the object was last modified.

- name

    The object's name.  Every object has one, even if it's just the UUID or part of another field.

- public

    Whether or not the object is available to be viewed by the general public.

### Types of User Fields

- boolean

    A TRUE/FALSE value, will be represented by a checkbox on web forms.

- datetime

    A datetime string, in the form "YYYY-MM-DD HH::mm::SS".  Appears as a calendar
    on forms.  (This is a bug, making it more of a "date" field than than a "dateime" field,
    but I haven't gotten to fixing it yet.)

- float

    A floating point number.

- int

    An integer.

- object

    A non-specificy type of MinorImpact::Object.

- password

    Essentially a string, but with a maximum length of 16 characters, and will be represnted by a
    'password' input type on html forms.

- string

    A standard string.

- text

    A long string, appears as a textarea field on forms.

- <Type>

    A particular type of MinorImpact::Object.

- url

    A web address.

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
