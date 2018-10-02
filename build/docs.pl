#!/usr/bin/perl

use Cwd;
use Pod::Markdown;

$dir = getcwd;
foreach $m (findModules("$dir")) {
    my ($markdown_file) = $m =~/^$dir\/(.*).pm$/;
    $markdown_file =~s/\//_/g;
    $markdown_file = "$markdown_file.md";
    $markdown_file = "$dir/docs/$markdown_file";

    print "parsing $m\n";

    print "Writing output to $markdown_file\n";
    open(FILE, ">$markdown_file");
    my $parser = Pod::Markdown->new(perldoc_url_prefix => './');
    $parser->output_fh(*FILE);
    $parser->parse_file($m);
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
            next unless ($f =~/\.pm$/);
        }
        push(@modules, "$dir/$f");
    }
    closedir($dh);
    return @modules;
}

