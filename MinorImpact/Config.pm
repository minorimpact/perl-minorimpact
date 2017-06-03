package MinorImpact::Config;

use Time::Local;
use Exporter 'import';
@EXPORT = (
            "readConfig", 
            "writeConfig",
          );

use MinorImpact::Util;

sub readConfig {
    my $config_file = shift || return;

    my $config;
    my $category = 'default';
    my $key = '';

    return $config unless (-f $config_file);
    open(CONFIG, $config_file);
    while(<CONFIG>) {
        my $value;
        my $line = trim($_);
        next if (/^#/ || !$_);
        if (/^([^:]+):/) {
            $category = $1;
            next;
        } elsif (/^([^=]+)\s?=\s?(.+)$/) {
            $key = trim($1);
            $value = trim($2);
        } elsif (/^\s+(.+)$/) {
            $value = trim($1);
        }
        $value =~s/^"//;
        $value =~s/"$//;
        next unless ($value);
        $category =~s/_COLON_/:/g;
        $key =~s/_COLON_/:/g;

        if ($config->{$category}->{$key}) {
            if (ref($config->{$category}->{$key}) eq 'ARRAY') {
                push(@{$config->{$category}->{$key}}, $value);
            } else  {
                my $old_value = $config->{$category}->{$key};
                my @values = ($old_value, $value);
                $config->{$category}->{$key} = \@values;
            }
        } else {
            $config->{$category}->{$key} = $value;
        }
    }
    return $config;
}

sub writeConfig {
    my $config_file = shift || return;
    my $config = shift || return;

    open(CONFIG, ">$config_file");
    foreach my $section (keys %$config) {
        my $conf_section = $section;
        $conf_section =~s/:/_COLON_/g;

        print CONFIG "$conf_section:\n";
        foreach my $key (keys %{$config->{$section}}) {
            next unless ($key);
            $value = $config->{$section}{$key};
            chomp($key);
            chomp($value);
            $key =~s/:/_COLON_/g;
            print CONFIG "    $key = \"$value\"\n";
        }
        print CONFIG "\n";
    }
    close(CONFIG);
}

1;
