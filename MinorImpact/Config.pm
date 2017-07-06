package MinorImpact::Config;

use Time::Local;
use Cwd;
use Exporter 'import';
@EXPORT = (
            "readConfig", 
            "writeConfig",
          );

use MinorImpact::Util;

sub new {
    my $package = shift;
    my $params = shift || {};

    my $self = {};
    bless($self, $package);

    $self->{config} = readConfig($params->{config_file});

    return $self;
}

sub decode {
    my $string = shift || return;

    my $ret = ref($string)?$$string:$string;
    $ret =~s/_COLON_/:/g;
    $ret =~s/_LBRACKET_/[/g;
    $ret =~s/_RBRACKET_/]/g;

    $$string = $ret if (ref($string));
    return $ret;
}

sub encode {
    my $string = shift || return;

    my $ret = ref($string)?$$string:$string;

    $ret =~s/:/_COLON_/g;
    $ret =~s/\[/_LBRACKET_/g;
    $ret =~s/\]/_RBRACKET_/g;

    $$string = $ret if (ref($string));
    return $ret;
}


sub get {
    my $self = shift || return;
    my $category = shift || return;
    my $key = shift;

    if (!$key) {
        $key = $category;
        $category = "default";
    }

    return $self->{config}{$category}{$key};
}


sub readConfig {
    my $config_file = shift || return;

    my $config;
    my $category = 'default';
    my $key = '';

    if ($config_file !~/^\//) {
        $config_file = cwd() . "/" . $config_file;
    }
    return $config unless (-f $config_file);
    open(CONFIG, $config_file);
    while(<CONFIG>) {
        my $value;
        my $line = trim($_);
        next if (/^#/ || !$_);
        if (/^([^:]+):/ || /^\[(^\]]+)\]/) {
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
        decode(\$category);
        decode(\$key);
        decode(\$value);

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
        encode(\$conf_section);

        print CONFIG "$conf_section:\n";
        foreach my $key (keys %{$config->{$section}}) {
            next unless ($key);
            $value = $config->{$section}{$key};
            chomp($key);
            chomp($value);
            encode(\$key);
            encode(\$value);
            print CONFIG "    $key = \"$value\"\n";
        }
        print CONFIG "\n";
    }
    close(CONFIG);
}


1;
