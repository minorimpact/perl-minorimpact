#!/usr/bin/perl

use Cwd;
use File::Basename;
use Pod::Markdown;

my $parser = Pod::Markdown->new();
my $output_string;
$parser->output_string(\$output_string);
$dir = getcwd;
foreach $m (findModules("$dir")) {
    $output_string = '';
    my ($markdown_file) = $m =~/^$dir\/(.*).pm$/;
    $markdown_file =~s/\//_/g;
    $markdown_file = "$filename.md";
    $markdown_file = "$dir/docs/$markdown_file";

    print "parsing $m\n";
    $parser->parse_file($m);

    print "Writing output to $markdown_file\n";
    open(FILE, ">$dir/docs/$markdown_file");
    print FILE $output_string;
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


