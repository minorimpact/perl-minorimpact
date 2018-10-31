# NAME

MinorImpact::Manual::Objects

# DESCRIPTION

## Types

Make a new object type:

    $type = MinorImpact:Object:Type::add({name => "vehicle" });
    $type->addField({ name => "door_count", type => "int" });

    MinorImpact::Object::Type("MinorImpact::entry");

## Fields

Creating a standalone field with a preset value:

    $field = new MinorImpact::Object::Field({ db=> { name => 'balloon_count', type=>'int' }, value => 5});

Including that field on on a form:

    $form .= $field->rowForm();

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
