# NAME

MinorImpact::reference

# DESCRIPTION

An object for other linking two MinorImpact objects.

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
