# Introduction

## MinorImpact.pm

    use MinorImpact;

    $MINORIMPACT = new MinorImpact();

    # define a new object type
    MinorImpact::Object::Type::add({name => 'test'});

    # create a new object 
    $test = new MinorImpact::Object({ object_type_id => 'test', name => "test-$$" });
    print $test->id() . ": " . $test->get('name') . "\n";

    # retrieve a second copy of the same object using just the id
    $test2 = new MinorImpact::Object($test->id());
    print $test2->id() . ": " . $test2->get('name') . "\n";

    # add a field to the object definition
    MinorImpact::Object::Type::addField({ object_type_id => $test->typeID(), name => 'field_1', type => 'string' });
    $test->update({field_1 => 'one'});

    print $test->get('field_1') . "\n";

### Passing Parameters

    sub({ parameter1 => 'one', parameter2 => 'two' });

### Examples

index.cgi:

    use MinorImpact;

    MinorImpact::www({ actions => { index => \&hello, hello=> \&hello } });

    sub hello {
        print "Content-type: text/html\n\n";
        print "Hello world\n";
    }

http://\<server\>/cgi-bin/index.cgi?a=hello  
http://\<server\>/cgi-bin/hello

Output:

    Hello World


