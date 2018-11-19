# NAME

Net::Facebook::Oauth2 - a simple Perl wrapper around Facebook OAuth 2.0 protocol

<div>

    <a href="https://travis-ci.org/mamod/Net-Facebook-Oauth2"><img src="https://travis-ci.org/mamod/Net-Facebook-Oauth2.svg?branch=master"></a>
</div>

# FACEBOOK GRAPH API VERSION

This module complies to Facebook Graph API version 3.1, the latest
at the time of publication, **scheduled for deprecation not sooner than July 26th, 2020**.

# SYNOPSIS

Somewhere in your application's login process:

    use Net::Facebook::Oauth2;

    my $fb = Net::Facebook::Oauth2->new(
        application_id     => 'your_application_id', 
        application_secret => 'your_application_secret',
        callback           => 'http://yourdomain.com/facebook/callback'
    );

    # get the authorization URL for your application
    my $url = $fb->get_authorization_url(
        scope   => [ 'email' ],
        display => 'page'
    );

Now redirect the user to this `$url`.

Once the user authorizes your application, Facebook will send him/her back
to your application, on the `callback` link provided above. PLEASE NOTE
THAT YOU MUST PRE-AUTHORIZE YOUR CALLBACK URI ON FACEBOOK'S APP DASHBOARD.

Inside that callback route, use the verifier code parameter that Facebook
sends to get the access token:

    # param() below is a bogus function. Use whatever your web framework
    # provides (e.g. $c->req->param('code'), $cgi->param('code'), etc)
    my $code = param('code');

    use Try::Tiny;  # or eval {}, or whatever

    my ($unique_id, $access_token);
    try {
        $access_token = $fb->get_access_token(code => $code); # <-- could die!

        # Facebook tokens last ~2h, but you may upgrade them to ~60d if you want:
        $access_token = $fb->get_long_lived_token( access_token => $access_token );

        my $access_data = $fb->debug_token( input => $access_token );
        if ($access_data && $access_data->{is_valid}) {
            $unique_id = $access_data->{user_id};
            # you could also check here for what scopes were granted to you
            # by inspecting $access_data->{scopes}->@*
        }
    } catch {
        # handle errors here!
    };

If you got so far, your user is logged! Save the access token in your
database or session. As shown in the example above, Facebook also provides
a unique _user\_id_ for this token so you can associate it with a particular
user of your app.

Later on you can use that access token to communicate with Facebook on behalf
of this user:

    my $fb = Net::Facebook::Oauth2->new(
        access_token => $access_token
    );

    my $info = $fb->get(
        'https://graph.facebook.com/v3.1/me'   # Facebook API URL
    );

    print $info->as_json;

NOTE: if you skipped the call to `debug_token()` you can still find the
unique user id value with a call to the 'me' endpoint shown above, under
`$info->{id}`

# DESCRIPTION

Net::Facebook::Oauth2 gives you a way to simply access FaceBook Oauth 2.0
protocol.

The example folder contains some snippets you can look at, or for more
information just keep reading :)

# SEE ALSO

For more information about Facebook Oauth 2.0 API

Please Check
[http://developers.facebook.com/docs/](http://developers.facebook.com/docs/.md)

get/post Facebook Graph API
[http://developers.facebook.com/docs/api](http://developers.facebook.com/docs/api.md)

# USAGE

## `Net::Facebook::Oauth->new( %args )`

Returns a new object to handle user authentication.
Pass arguments as a hash. The following arguments are _REQUIRED_
unless you're passing an access\_token (see optional arguments below):

- `application_id`

    Your application id as you get from facebook developers platform
    when you register your application

- `application_secret`

    Your application secret id as you get from facebook developers platform
    when you register your application

The following arguments are _OPTIONAL_:

- `access_token`

    If you want to instantiate an object to an existing access token, you may
    do so by passing it to this argument.

- `browser`

    The user agent that will handle requests to Facebook's API. Defaults to
    LWP::UserAgent, but can be any method that implements the methods `get`,
    `post` and `delete` and whose response to such methods implements
    `is_success` and `content`.

- `display`

    See `display` under the `get_authorization_url` method below.

- `api_version`

    Use this to replace the API version on all endpoints. The default
    value is 'v3.1'. Note that defining an api\_version parameter together with
    `authorize_url`, `access_token_url` or `debug_token_url` is a fatal error.

- `authorize_url`

    Overrides the default (3.1) API endpoint for Facebook's oauth.
    Used mostly for testing new versions.

- `access_token_url`

    Overrides the default (3.1) API endpoint for Facebook's access token.
    Used mostly for testing new versions.

- `debug_token_url`

    Overrides the default (3.1) API endpoint for Facebook's token information.
    Used mostly for testing new versions.

## `$fb->get_authorization_url( %args )`

Returns an authorization URL for your application. Once you receive this
URL, redirect your user there in order to authorize your application.

The following argument is _REQUIRED_:

- `callback`

        callback => 'http://example.com/login/facebook/success'

    The callback URL, where Facebook will send users after they authorize
    your application. YOU MUST CONFIRM THIS URL ON FACEBOOK'S APP DASHBOARD.

    To do that, go to the App Dashboard, click Facebook Login in the right-hand
    menu, and check the **Valid OAuth redirect URIs** in the Client OAuth Settings
    section.

This method also accepts the following _OPTIONAL_ arguments:

- `scope`

        scope => ['user_birthday','user_friends', ...]

    Array of Extended permissions as described by the Facebook Oauth API.
    You can get more information about scope/Extended Permission from

    [https://developers.facebook.com/docs/facebook-login/permissions/](https://developers.facebook.com/docs/facebook-login/permissions/.md)

    Please note that requesting information other than `name`, `email` and
    `profile_picture` **will require your app to be reviewed by Facebook!**

- `state`

        state => '123456abcde'

    An arbitrary unique string provided by you to guard against Cross-site Request
    Forgery. This value will be returned to you by Facebook, unchanged. Note that,
    as of Facebook API v3.0, this argument is _mandatory_, so if you don't
    provide a 'state' argument, we will default to `time()`.

- `auth_type`

    When a user declines a given permission, you must reauthorize them. But when
    you do so, any previously declined permissions will not be asked again by
    Facebook. Set this argument to `'rerequest'` to explicitly tell the dialog
    you're re-asking for a declined permission.

- `display`

        display => 'page'

    How to display Facebook Authorization page. Defaults to `page`.
    Can be any of the following:

    - `page`

        This will display facebook authorization page as full page

    - `popup`

        This option is useful if you want to popup authorization page
        as this option tell facebook to reduce the size of the authorization page

    - `wab`

        From the name, for wab and mobile applications this option is the best, as
        the facebook authorization page will fit there :)

- `response_type`

        response_type => 'code'

    When the redirect back to the app occurs, determines whether the response
    data is in URL parameters or fragments. Defaults to `code`, which is
    Facebook's default and useful for cases where the server handles the token
    (which is most likely why you are using this module), but can be also be
    `token`, `code%20token`, or `granted_scopes`. Note that changing this to
    anything other than 'code' might change the login flow described in this
    documentation, rendering calls to `get_access_token()` pointless.
    Please see
    [Facebook's login documentation](https://developers.facebook.com/docs/facebook-login/manually-build-a-login-flow.md)
    for more information.

## `$fb->get_access_token( %args )`

This method issues a GET request to Facebook's API to retrieve the
access token string for the specified code (passed as an argument).

Returns the access token string or raises an exception in case of errors
(**make sure to trap calls with eval blocks or a try/catch module**). Note
that Facebook's access tokens are short-lived, around 2h of idle time
before expiring. If you want to "upgrade" the token to a long lived one
(with around 60 days of idle time), use this token to feed the
`get_long_lived_token()` method.

You should call this method inside the route for the callback URI defined
in the `get_authorization_url` method. It receives the following arguments:

- `code`

    This is the verifier code that Facebook sends back to your
    callback URL once user authorize your app, you need to capture
    this code and pass to this method in order to get the access token.

    Verifier code will be presented with your callback URL as code
    parameter as the following:

    http://your-call-back-url.com?code=234er7y6fdgjdssgfsd...

    Note that if you have fiddled with the `response_type` argument,
    you might not get this parameter properly.

When the access token is returned you need to save it in a secure
place in order to use it later in your application. The token indicates
that a user has authorized your site/app, meaning you can associate that
token to that user and issue API requests to Facebook on their behalf.

To know _WHICH_ user has granted you the authorization (e.g. when building
a login system to associate that token with a unique user on your database),
you must make a request to fetch Facebook's own unique identifier for that
user, and then associate your own user's unique id to Facebook's.

This was usually done by making a GET request to the `me` API endpoint and
looking for the 'id' field. However, Facebook has introduced a new endpoint
for that flow that returns the id (this time as 'user\_id') and some extra
validation data, like whether the token is valid, to which app it refers to,
what scopes the user agreed to, etc, so now you are encouraged to call the
`debug_token()` method as shown in the SYNOPSIS.

**IMPORTANT:** Expect that the length of all access token types will change
over time as Facebook makes changes to what is stored in them and how they
are encoded. You can expect that they will grow and shrink over time.
Please use a variable length data type without a specific maximum size to
store access tokens.

## `$fb->get_long_lived_token( access_token => $access_token )`

Asks facebook to retrieve the long-lived (~60d) version of the provided
short-lived (~2h) access token retrieved from `get_access_token()`. If
successful, this method will return the long-lived token, which you can
use to replace the short-lived one. Otherwise, it croaks with an error
message, in which case you can continue to use the short-lived version.

[See here](https://developers.facebook.com/docs/facebook-login/access-tokens/refreshing.md)
for the gory details.

## `$fb->debug_token( input => $access_token )`

This method should be called right after `get_access_token()`. It will
query Facebook for details about the given access token and validate that
it was indeed granted to your app (and not someone else's).

It requires a single argument, `input`, containing the access code obtained
from calling `get_access_token`.

It croaks on HTTP/connection/Facebook errors, returns nothing if for whatever
reason the response is invalid without errors (e.g. no app\_id and no user\_id),
and also if the returned app\_id is not the same as your own application\_id
(pass a true value to `skip_check` to skip this validation).

If all goes well, it returns a hashref with the JSON structure returned by
Facebook.

## `$fb->get( $url, $args )`

Sends a GET request to Facebook and stores the response in the given object.

- `url`

    Facebook Graph API URL as string. You must provide the full URL.

- `$args`

    hashref of parameters to be sent with graph API URL if required.

You can access the response using the following methods:

- `$response>as_json`

    Returns response as json object

- `$response>as_hash`

    Returns response as perl hashref

For more information about facebook graph API, please check
http://developers.facebook.com/docs/api

## `$fb->post( $url, $args )`

Send a POST request to Facebook and stores the response in the given object.
See the `as_hash` and `as_json` methods above for how to retrieve the
response.

- `url`

    Facebook Graph API URL as string

- `$args`

    hashref of parameters to be sent with graph API URL

For more information about facebook graph API, please check
[http://developers.facebook.com/docs/api](http://developers.facebook.com/docs/api.md)

## `$fb->delete( $url, $args )`

Send a DELETE request to Facebook and stores the response in the given object.
See the `as_hash` and `as_json` methods above for how to retrieve the
response.

- `url`

    Facebook Graph API URL as string

- `$args`

    hashref of parameters to be sent with graph API URL

# AUTHOR

Mahmoud A. Mehyar, <mamod.mehyar@gmail.com>

# CONTRIBUTORS

Big Thanks To

- Takatsugu Shigeta [@comewalk](https://github.com/comewalk.md)
- Breno G. de Oliveira [@garu](https://github.com/garu.md)
- squinker [@squinker](https://github.com/squinker.md)
- Valcho Nedelchev [@valchonedelchev](https://github.com/valchonedelchev.md)

# COPYRIGHT AND LICENSE

Copyright (C) 2012-2016 by Mahmoud A. Mehyar

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.

# POD ERRORS

Hey! **The above document had some coding errors, which are explained below:**

- Around line 574:

    Unterminated C<...> sequence
