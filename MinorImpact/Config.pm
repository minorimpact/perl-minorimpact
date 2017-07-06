package MinorImpact::Config;

use Time::Local;
use Cwd;
use Exporter 'import';
@EXPORT = (
            "readConfig", 
            "writeConfig",
          );

use MinorImpact::Util;

my $ENCODE_MAP = {
                ":" => "_COLON_",
                "\\[" => "_LBRACKET_",
                "\\]" => "_RBRACKET_",
            };

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

    foreach my $c (keys %$ENCODE_MAP) {
        my $e = $ENCODE_MAP->{$c};
        $ret =~s/$e/$c/g;
    }

    $$string = $ret if (ref($string));
    return $ret;
}

sub encode {
    my $string = shift || return;

    my $ret = ref($string)?$$string:$string;

    foreach my $c (keys %$ENCODE_MAP) {
        my $e = $ENCODE_MAP->{$c};
        $ret =~s/$c/$e/g;
    }

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
            undef($key);
            next;
        } elsif (/^([^=]+)\s?=\s?(.+)$/) {
            $key = trim($1);
            $value = trim($2);
        } elsif (/^\s+(.+)$/) {
            $value = trim($1);
        }
        $value =~s/^"//;
        $value =~s/"$//;
        next unless ($category && $key && $value);
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
        my $conf_section = encode($section);

        print CONFIG "$conf_section:\n";
        foreach my $key (keys %{$config->{$section}}) {
            my $conf_key = encode($key);
            next unless ($key);
            if (ref($config->{$section}{$key}) eq 'ARRAY') {
                my $loop = 0;
                foreach my $value (@{$config->{$section}{$key}}) {
                    chomp($value);
                    unless ($loop++) {
                        print CONFIG "    $conf_key = \"" . encode($value) . "\"\n";
                    } else {
                        print CONFIG "           \"" . encode($value) . "\"\n";
                    }
                }
            } else {
                $value = $config->{$section}{$key};
                print CONFIG "    $key = \"" . encode($value) . "\"\n";
            }
        }
        print CONFIG "\n";
    }
    close(CONFIG);
}


1;
