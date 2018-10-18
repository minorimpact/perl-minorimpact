# NAME

MinorImpact::Manual::Templates

# DESCRIPTION

A collection of prebuilt application templates based on the [Template Toolkit](https://metacpan.org/pod/Template.md)
library and generated via the [MinorImpact::tt()](./MinorImpact.md#tt) subroutine.

# VARIABLES

Common variables that are supported by many MinorImpact [action](#action-templates) or [included](#included-templates) templates.

## errors

A list of strings to include as error messages to the user.
See [error](#error).

    push(@errors, "Invalid login.");
    MinorImpact::tt('login', { errors => [ @errors ] });

## objects

A list of [MinorImpact objects](./MinorImpact_Object.md) to display on a page.

    MinorImpact::tt("index", { objects => [ @objects ] });

## title

The page title.

    MinorImpact::tt($template_name, { title => "Page Name" });

# METHODS

A handful of MinorImpact methods are available to use from within templates.

## url

- url(\\%params)

    Generates an application URL. See [MinorImpact::url()](./MinorImpact.md#url).

    <a href='[% url({ action=>'add', object_type_id=>4 }) %]' title='Add Entry'>Add Entry</a>

### Parameters

- action
- object\_type\_id

# ACTION TEMPLATES

## index

Intended to be a generic landing page, this will generate a list of objects from the "objects"
variable.

    MinorImpact::tt("index", { objects => [ @objects ] });

### Includes

- [header](#header)
    - [header\_css](#header_css)
        - [css](#css)

            Note that header\_css creates an html stylesheet link to this resource; it's not technically an INCLUDE, it's actually
            served up as a top level page.

            - [css\_site](#css_site)
    - [header\_javascript](#header_javascript)
    - [header\_search](#header_search)
    - [header\_site](#header_site)
    - [sidebar\_site](#sidebar_site)
    - [error](#error)

- [list\_object](#list_object)
    - [list\_object\_site](#list_object_site)
    - [object](#object)

- [footer](#footer)
    - [copyright](#copyright)
    - [footer\_javascript](#footer_javascript)
        - [footer\_javascript\_site](#footer_javascript_site)

# INCLUDED TEMPLATES

Any of these templates can be overridden by creating a template with the same name in the
directory named in the template\_directory configuration setting. See [MinorImpact::Manual::Configuration](./Minorimpact_Manual_Configuration.md#settings).

## copyright

Dumps the value defined in the 'copyright' option in the 
[/etc/minorimpact.conf](./MinorImpact_Manual_Configuration.md#configurationfile) file.

## css

Site wide style sheet.

## css\_site

Included at the end of [css](#css); add custom style sheet entries here.

## error

The template for outputing error messages.  Displays errors passed as an array pointer to the 
[MinorImpact::tt()](./MinorImpact.md#tt) sub.

    push(@errors, "Invalid login.");
    MinorImpact::tt('login', { errors => [ @errors ] });

## footer

## footer\_javascript

Default site javascript that goes in <footer>.

## footer\_javascript\_site

Add custom javascript here.  You must include the surrounding <script> tags.

## header

Included at the top of most pages, includes DOCTYPE and meta tags, and CGI headers. If you override
this template with your own, remember to account for  the "Content-type: text/html\\n\\n" header, which is
included in the default.  The stock version of this template also includes generic top and side navigation
bars, a search box, and links to various site functions, including user login and settings.  Subject to change
and may not be suitable for some (or any) applications.

### Variables

- title

    Use this as the page <title>.  Can be set when the main page is called:

        MinorImpact::tt($template_name, { title => "Page Name" });

    ...or set from the calling template:

        [% INCLUDE header title='Page Name' %]

## header\_css

Includes external libraries and creates a html "stylesheet" link to [css](#css).

## header\_javascript

## header\_script

Default site javascript that goes in <head>.

## header\_site

Add custom html to the header here.

## list\_object

Generates a list of [object](#object) templates from the "objects" array passed to 
[MinorImpact::tt()](./MinorImpact.md#tt).

    MinorImpact::tt($template_name, { objects => [ @objects ] });

## list\_object\_site

Insert custom template output here.

## object

Called for each object in the "objects" array, this is a fairly complicated template designed to output
a [MinorImpact object](./MinorImpact_Object.md)'s [toString() method](./MinorImpact_Object.md#tostring), with the
"column" format.

## object\_link

The object's name as a link to the /object/<id> page.

## object\_page

A shorter version of [object](#object), but a longer version of [object\_link](#object_link).

## sidebar\_site

Add custom sidebare entries here.  Items should follow the format:

            <div class="w3-row">
                <div class="w3-col s3">
                    &nbsp;
                </div>
                <div class="w3-col s9">
                    <a class="w3-bar-item w3-button" href='[% url({ action=>'ACTION' }) %]'>TEXT</a>
                </div>
            </div>

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com>
