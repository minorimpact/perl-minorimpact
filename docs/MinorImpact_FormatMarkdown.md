# NAME

HTML::FormatMarkdown - Format HTML as Markdown

# VERSION

version 2.12

# SYNOPSIS

    use HTML::FormatMarkdown;

    my $string = HTML::FormatMarkdown->format_file(
        'test.html'
    );

    open my $fh, ">", "test.md" or die "$!\n";
    print $fh $string;
    close $fh;

# DESCRIPTION

HTML::FormatMarkdown is a formatter that outputs Markdown.

HTML::FormatMarkdown is built on [HTML::Formatter](./HTML::Formatter) and documentation for that
module applies to this - especially ["new" in HTML::Formatter](./HTML::Formatter#new),
["format\_file" in HTML::Formatter](./HTML::Formatter#format_file) and ["format\_string" in HTML::Formatter](./HTML::Formatter#format_string).

# INSTALLATION

See perlmodinstall for information and options on installing Perl modules.

# BUGS AND LIMITATIONS

You can make new bug reports, and view existing ones, through the
web interface at [http://rt.cpan.org/Public/Dist/Display.html?Name=HTML-Format](http://rt.cpan.org/Public/Dist/Display.html?Name=HTML-Format).

# AVAILABILITY

The project homepage is [https://metacpan.org/release/HTML-Format](https://metacpan.org/release/HTML-Format).

The latest version of this module is available from the Comprehensive Perl
Archive Network (CPAN). Visit [http://www.perl.com/CPAN/](http://www.perl.com/CPAN/) to find a CPAN
site near you, or see [https://metacpan.org/module/HTML::Format/](https://metacpan.org/module/HTML::Format/).

# AUTHORS

- Nigel Metheringham <nigelm@cpan.org>
- Sean M Burke <sburke@cpan.org>
- Gisle Aas <gisle@ActiveState.com>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Nigel Metheringham, 2002-2005 Sean M Burke, 1999-2002 Gisle Aas.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
