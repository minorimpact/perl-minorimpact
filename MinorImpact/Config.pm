package MinorImpact::Config;

use Cwd;
use Exporter 'import';
use MinorImpact::Util;
use Time::Local;

=head1 NAME

MinorImpact::Config

=head1 DESCRIPTION

Subs for reading and writing configuration files.

=cut

@EXPORT = (
    "readConfig", 
    "writeConfig",
);


my $ENCODE_MAP = {
    ":" => "_COLON_",
    "\\[" => "_LBRACKET_",
    "\\]" => "_RBRACKET_",
};

=head1 METHODS

=head2 new

returns a new MinorImpact::Config object.

  $CONFIG = new MinorImpact::Config({ config_file=>"/etc/minorimpact.conf"});

=cut

sub new {
    my $package = shift;
    my $params = shift || {};

    my $self = {};
    bless($self, $package);

    $self->{config} = readConfig($params->{config_file});

    return $self;
}

=head1 SUBS

=head2 decode

=over

=item decode($string)

=item decode(\$string)

=back

Returns a version of C<$string> with special encoded/escaped converted
back to their unencoded values.  If C<$string> is a reference, the data
will be modified directly.

  $decoded_string = MinorImpact::Config::decode("This is a colon_COLON_ _COLON_");
  # $decoded_string = "This is a colon: :" 

=cut

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

=head2 readConfig

=over

=item readConfig($config_file)

=back

Reads configuration information from a given file and returns a hash containing
data.

  # cat /etc/minorimpact.conf
  # 
  # application_id = "minorimpact"
  #
  # [db]
  #   db_host = "localhost"

  $config = MinorImpact::Config::readConfig("/etc/minorimpact.conf");
  
  # $config = { 
  #   default => { 
  #     application_id => "minorimpact"
  #   },
  #   db => {
  #     db_host => "localhost"
  #   }
  # }

=cut

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
        my $value = '';
        my $line = trim($_);
        next if (/^#/ || !$_);
        if (/^([^:=]+):/ || /^\[([^\]]+)\]/) {
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

=head2 writeConfig

=over

=item writeConfig($config_file, \%config)

=back

Writes configuration data to a given file.

  MinorImpact::Config::writeConfig("/etc/minorimpact.conf", { 
    default => { 
      application_id => "minorimpact"
    },
    db => {
      db_host => "localhost"
    }
  });
  # cat /etc/minorimpact.conf
  # 
  # application_id = "minorimpact"
  #
  # [db]
  #   db_host = "localhost"

=cut

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

=head1 AUTHOR

Patrick Gillan <pgillan@minorimpact.com>

=cut

1;
