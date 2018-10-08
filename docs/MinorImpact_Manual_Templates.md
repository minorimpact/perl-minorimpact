# NAME

MinorImpact::Manual::Templates

# DESCRIPTION

See [Template](./Template.md).

# VARIABLES

## 

# METHODS

A handful of MinorImpact methods are automatically  available to use from within templates.

## url

- url(\\%params)

    Generates an application URL. See [MinorImpact::url()](./MinorImpact.md#url).

    <a href='[% url({ action=>'add', object_type_id=>4 }) %]' title='Add Entry'>Add Entry</a>

### Parameters

- action
- object\_type\_id

# DEFAULT LAYOUT

## index

- header
    - header\_css
        - css

            Note that header\_css creates an html stylesheet link to this resource; it's not technically an INCLUDE, it's actually
            served up as a top level page.

            - css\_site

                Create a css\_site template in your application's template directory to add custom style sheet entries if you choose not
                to override the css template completely.
    - header\_javascript
    - header\_search
    - header\_sort
    - header\_site

        Add custom html to the header here.

    - sidebar\_site

        Add custom sidebare entries here.  Items should follow the format:

                    <div class="w3-row">
                        <div class="w3-col s3">
                            &nbsp;
                        </div>
                        <div class="w3-col s9">
                            <a class="w3-bar-item w3-button" href='[% url({ action=>'ACTION' }) %]'>TEXT</a>
                        </div>
                    </div>

    - error

        The template for outputing error messages.  Displays errors passed as an array pointer to the 
        [MinorImpact::tt()](./MinorImpact.md#tt) sub.

            push(@errors, "Invalid login.");
            MinorImpact::tt('login', { errors => [ @errors ] });
            
- footer
    - copyright

        Dumps the value defined in the 'copyright' option in the 
        ["/etc/minorimpact.conf"](./MinorImpact.md#configuration) file.

    - footer\_javascript
        - footer\_javascript\_site

            Add custom javascript here.  You must include the surrounding <script> tags.

# AUTHOR

Patrick Gillan <pgillan@minorimpact.com.>
