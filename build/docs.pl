#!/usr/bin/perl

use Cwd;
use Pod::Markdown;

$dir = getcwd;
foreach $m (findModules("$dir")) {
    my ($markdown_file) = $m =~/^$dir\/(.*).(pm|pod|pl)$/;
    $markdown_file =~s/\//_/g;
    $markdown_file = "$markdown_file.md";
    $markdown_file = "$dir/docs/$markdown_file";

    print "parsing $m\n";

    print "Writing output to $markdown_file\n";

    my $parser = Pod::Markdown->new(perldoc_url_prefix => './');
 
    open(FILE, ">$markdown_file");

    # Old method that outputs directly to the file.
    #$parser->output_fh(*FILE);
    #$parser->parse_file($m);

    # New method that gives us an intermediate string to fuck with.
    my $output_string = '';
    $parser->output_string(\$output_string);
    $parser->parse_file($m);
    #foreach my $text ($output_string =~/\[([^\]]+)\],\(([^\)]+)\)/g) {
    my $new_output_string = $output_string;
    while ($output_string =~/\[([^\]]+)\]\(([^\)]+)\)/g) {
        my $text = $1;
        my $old_url = $2;
        my $new_url = $old_url;
        $new_url =~s/::/_/g;
        if ($new_url =~/.+#/ && $url !~/\.md#/) {
            $new_url =~/^([^#]+)#(.*)$/;
            my $f = $1;
            my $a = lc($2);
            $new_url = "$f.md#$a";
        } elsif ($new_url !~/^#/ && $url !~/\.md$/) {
            $new_url .= ".md";
        }
        $new_output_string =~s/\[\Q$text\E\]\(\Q$old_url\E\)/\[$text\]\($new_url\)/;
    }
    print FILE $new_output_string;

    close(FILE);


    # I want to eliminate maintenance of the README file, so I'm going to use the
    #   contents of the "main" module (which includes a basic description, 
    #   synopsis and simplified installation and configuration instructions) as the
    #   README file, minus the code reference sections.  In this package, and
    #   probably most packages that use this same model, the main module comes up
    #   last in the list of files, so I'm going to rely on that and just write every
    #   module's documentation to the file - trusting that the last one is one that'll
    #   get kept - rather than try to come up with some clever way to identify the "main"
    #   package.
    my $readme = $new_output_string;
    # Remove the entire METHODS section
    $readme =~ s/^# METHODS\n.*?\n# /# /sm;

    # Remove the entire SUBROUTINES section.
    $readme =~ s/^# SUBROUTINES\n.*?\n# /# /sm;
    open(FILE, ">README.md");
    print FILE $readme;
    close(FILE);
}

sub findModules {
    my $dir = shift || return;
    return unless (-d $dir);

    my @modules = ();

    opendir(my $dh, "$dir");
    foreach $f ( readdir($dh)) {
        next if ($f =~/^\./);
        if (-d "$dir/$f") {
            push (@modules, findModules("$dir/$f"));
            next;
        } else {
            next unless ($f =~/\.(pm|pod|pl)$/);
        }
        push(@modules, "$dir/$f");
    }
    closedir($dh);
    return @modules;
}


