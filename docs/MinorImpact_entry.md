# NAME

MinorImpact::entry - A 'blog entry' object.

# SYNOPSIS

    use MinorImpact;

    $entry = new MinorImpact::entry({ 
      name => 'Tuesday', 
      content => "I've never quite gotten the hang of Tuesdays.",
      publish_date => "1992-04-06"m
      public => 1,
    });

# DESCRIPTION

Part of the default/example MinorImpact application, this is a very simple "blog entry" object
inherited from [MinorImpact::Object](./MinorImpact_Object.md).

# METHODS

## cmp

Overrides the default and Uses 'publish\_date' for sorting.

## get

Overrides the 'public' value to also check whether or not 'publish\_date' has
passed.

## toString

Overrides 'page' and 'list' with custom templates.

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
