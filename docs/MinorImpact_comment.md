# NAME

MinorImpact::comment

# DESCRIPTION

A comment object for other MinorImpact objects.

## back

- ->back()

Defaults to the object page for the entry this comment belongs to.

## cmp

Uses `create_date` for sorting.

See [MinorImpact::Object::cmp()](./MinorImpact_Object.md#cmp).

## toString

Overrides the `list` format to use `comment_list` instead of
`object_list`.

See [MinorImpact::Object::toString()](./MinorImpact_Object.md#tostring).

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
