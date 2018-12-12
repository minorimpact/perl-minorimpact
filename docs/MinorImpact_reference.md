# NAME

MinorImpact::reference

# DESCRIPTION

An object for other linking two MinorImpact objects.

## addLink

- ->addLink($data)

Applies the link in this reference to `$data`;

## match

- ->match($text)

Returns true if the reference object's `data` matches `$text`.

    $REFERENCE->update('data', "foo");
    $REFERENCE->match("This is foolhardy nonsense."); # returns TRUE

## toString

Overrides the `list` format to use `reference_list` instead of
`object_list`.

See [MinorImpact::Object::toString()](./MinorImpact_Object.md#tostring).

## verify

- ->verify()

Verify that the string in this reference is still part of the original object. Returns
1 if the reference is still good, 0 otherwise.

    # cleanup references after object update
    foreach $REFERENCE ($OBJECT->references()) {
      $REFERENCE->delete() unless ($REFERENCE->verify());
    }

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
