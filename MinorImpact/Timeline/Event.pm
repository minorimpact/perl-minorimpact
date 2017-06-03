package MinorImpact::Timeline::Event;

use Time::Local;
use Data::Dumper;

use MinorImpact::Timeline;
use MinorImpact::Util;
use MinorImpact::User;

sub new {
    my $package = shift;
    my $params = shift;
    my $options = shift || {};

    my $self = {};
    bless($self, $package);

    $self->log(7, "starting");
    $self->{DB} = MinorImpact::getDB() || die("No database object.");
    $self->{CGI} = MinorImpact::getCGI() || die("No CGI object.");
    $self->{options} = $options if ($options && ref($options) eq 'HASH');

    my $event_id;
    if (ref($params) eq 'HASH') {
        #print "Content-type: text/plain\n\n";
        #print Dumper $params;
        $self->log(7, "Creating new event: $params->{'name'}");
        $self->{DB}->do("INSERT INTO event (name, data, start_date, end_date, timeline_id, location_id, create_date) VALUES (?, ?, ?, ?, ?, ?, NOW())", undef, ($params->{'name'}, $params->{data}, $params->{start_date}, $params->{end_date}, $params->{timeline_id}, $params->{location_id})) || die("Can't add new event:" . $self->{DB}->errstr);
        $event_id = $self->{DB}->{mysql_insertid};
        if ($event_id) {
            $self->log(7, "new event created: $event_id");
            if ($params->{tags}) {
                foreach my $tag (processTags($params->{tags})) {
                    $self->{DB}->do("INSERT INTO event_tag(event_id, name, create_date) VALUES (?, ?, NOW())", undef, ($event_id, $tag)) || die("Can't add new event tag ($event_id):" . $self->{DB}->errstr);
                }
            }
            $self->{date} = writeDate($event_id, $params);
            foreach my $date (@{$self->{date}}) { $self->log(8, "just created: $date->{rule} $date->{position} $date->{type} $date->{data}"); }
        }
    } elsif ($params =~/^\d+$/) {
        $event_id = $params;
    } else {
        $event_id = $self->{CGI}->param('event_id') || $self->{CGI}->param('id');
    }

    $self->{data} = $self->{DB}->selectrow_hashref("SELECT id, name, data, timeline_id, location_id, start_date, end_date, mod_date, create_date FROM event WHERE id=?", undef, ($event_id)) || die("Can't collect event data for $event_id:" . $self->{DB}->errstr);
    $self->{tags} = $self->{DB}->selectall_arrayref("SELECT * FROM event_tag WHERE event_id=?", {Slice=>{}}, ($event_id)) || [];
    unless ($self->{date}) {
        $self->{date} = $self->{DB}->selectall_arrayref("SELECT * FROM event_date WHERE event_id=?", {Slice=>{}}, ($event_id)) || [];
        foreach my $date (@{$self->{date}}) { $self->log(8, "read from database: $date->{rule} $date->{position} $date->{type} $date->{data}"); }
    }
    $self->{references} = $self->{DB}->selectall_arrayref("SELECT en.* FROM entry_reference en, event_reference ev WHERE ev.reference_id=en.id AND ev.event_id=?", {Slice=>{}}, ($event_id)) || [];

    my $date = $self->date();
    $self->log(8, "\$self->date()='$date'");
    if ($date eq "1969-12-31 16:00:00" || !$date) {
        $self->updateDate();
    }

    $self->log(7, "ending");

    return $self;
}

sub log {
    my $self = shift || return;
    my $level = shift || return;
    my $message = shift || return;

    MinorImpact::log($level, $message);
    return;
}

sub dateSelect {
    my $self = shift || return;

    return $self->getTimeline()->dateSelect($self);
}

sub getReferences {
    my $self = shift || return;

    return @{$self->{references}};
    $self->log(7, "starting");
    my @references = ();
    foreach my $reference (@{$self->{references}}) {
        push(@references, {data=>$reference->{data}});
    }
    $self->log(7, "ending");
    return @references;
}

sub tags {
    my $self = shift || return;

    return $self->getTags();
}

sub getTags {
    my $self = shift || return;

    my @tags = ();
    foreach my $data (@{$self->{tags}}) {
        push @tags, $data->{name};
    }
    return @tags;
}

sub id {
    my $self = shift || return;

    return $self->{data}->{id};
}

sub get {
    my $self = shift || return;
    my $name = shift || return;

    return $self->{data}->{$name};
}

sub getParagraphs {
    my $self = shift || return;
    my @paragraphs = ();

    #foreach my $tag ($self->tags()) {
    #    my $data = $self->{DB}->selectall_arrayref("SELECT paragraph_id FROM paragraph_tag WHERE name=?", {Slice=>{}}, ($tag));
    #    foreach my $row (@$data) {
    #        push(@paragraphs, new Timeline::Paragraph($row->{paragraph_id}));
    #    }
    #}

    my $data = $self->{DB}->selectall_arrayref("SELECT paragraph_id FROM paragraph_event WHERE event_id=?", {Slice=>{}}, ($self->id()));
    foreach my $row (@$data) {
        push(@paragraphs, new Journal::Entry::Paragraph($row->{paragraph_id}));
    }

    return @paragraphs;
}

sub update {
    my $self = shift || return;
    my $params = shift || return;

    $self->log(7, "starting");
    $self->{DB}->do("UPDATE event SET name=?, data=?, location_id=? WHERE id=?", undef, ($params->{name}, $params->{data}, $params->{location_id}, $self->id())) || return $self->{DB}->errstr;

    if ($params->{tags}) {
        $self->{DB}->do("DELETE FROM event_tag WHERE event_id=?", undef, ($self->id()));
        foreach my $tag (processTags($params->{tags})) {
            $self->{DB}->do("INSERT INTO event_tag (name, event_id) VALUES (?,?)", undef, ($tag, $self->id())) if ($tag);
        }
        $self->{tags} = $self->{DB}->selectall_arrayref("SELECT * FROM event_tag WHERE event_id=?", {Slice=>{}}, ($self->id())) || [];
    }

    my $error = $self->writeDate($params);
    $self->{date} = $self->{DB}->selectall_arrayref("SELECT * FROM event_date WHERE event_id=?", {Slice=>{}}, ($self->id())) || [];

    $self->updateDate();
    $self->log(7, "ending");
    return;
}

sub writeDate {
    my $self = shift || return;
    my $params = shift || return;
    my @rules;

    my $event_id = $self;
    if (ref($self) eq "Timeline::Event") {
        $event_id = $self->id();
    } else {
        $self = new Timeline::Event($event_id);
    }

    $self->log(7, "starting");

    foreach my $key (keys %$params) {
        if ($key =~/^rule_(\d+)$/) {
            my $rule;
            my $corollaries;
            my $i = $1;
            next if ($params->{"delete_$i"});
            $rule->{event_id} = $event_id;
            $rule->{rule} = $params->{"rule_$i"};
            $rule->{position} = $params->{"position_$i"};
            $rule->{type} = $params->{"type_$i"};
            my $date = $params->{"date_$i"};
            my $e_id = $params->{"event_$i"};
            if ($rule->{type} eq 'event' && $e_id) {
                $rule->{data} = $e_id;
            } elsif ($rule->{type} eq 'date' && $date) {
                $rule->{data} = $date;
            }
            if ($rule->{type} eq 'event') {
                my $DB = MinorImpact::getDB();
                #my $conflicts = $DB->selectall_arrayref("SELECT * FROM event_date WHERE event_id=? AND (position=? OR position='during') AND type='event' AND data = ?", {Slice=>{}}, ($rule->{data}, $rule->{position}, $event_id));
                # We can't allow adding a rule that depends on an event if that event also depends on us.
                my $conflicts = $DB->selectall_arrayref("SELECT * FROM event_date WHERE event_id=? AND type='event' AND data = ?", {Slice=>{}}, ($rule->{data}, $event_id));
                next if (scalar(@$conflicts));

                #if ($rule->{rule} eq 'start' && $rule->{position} eq 'after') {
                #    push(@corollaries, { event_id => $rule->{data}, data=>$event_id, type=>'event', rule=>"end", position=>"before"})
                ##} elsif ($rule->{rule} eq 'end' && $rule->{position} eq 'after') {
                ##    push(@corollaries, { event_id => $rule->{data}, data=>$event_id, type=>'event', rule=>"end", position=>"before"});
                ##} elsif ($rule->{rule} eq 'start' && $rule->{position} eq 'before') {
                ##    push(@corollaries, { event_id => $rule->{data}, data=>$event_id, type=>'event', rule=>"start", position=>"after"});
                #} elsif ($rule->{rule} eq 'end' && $rule->{position} eq 'before') {
                #    push(@corollaries, { event_id => $rule->{data}, data=>$event_id, type=>'event', rule=>"start", position=>"after"});
                #}
            }
            if ($rule && $rule->{rule} && $rule->{position} && $rule->{type} && $rule->{data} && !$params->{"delete_$i"}) {
                $self->log(8, "$rule->{rule} && $rule->{position} && $rule->{type} && $rule->{data}");
                push(@rules, $rule);
                push(@rules, @corollaries) if (scalar(@corollaries) > 0);
            }
        }
    }

    if (scalar(@rules)) {
        my $DB = MinorImpact::getDB();
        $DB->do("DELETE FROM event_date WHERE event_id=?", undef, ($event_id)) || return $self->{DB}->errstr;
        foreach my $rule (@rules) {
            $DB->do("INSERT INTO event_date (event_id, rule, position, type, data, create_date) VALUES (?, ?, ?, ?, ?, NOW())", undef, ($rule->{event_id}, $rule->{rule}, $rule->{position}, $rule->{type}, $rule->{data})) || die $self->{DB}->errstr;
        }
    }
    $self->log(7, "ending");
    return \@rules;
}

sub updateDate {
    my $self = shift || return;
    my $param = shift || {};

    my $now = time(); 

    $self->log(7, "starting");
    my $event_id = $self->id();
    my ($start_date, $end_date) = $self->date();
    $self->log(8, "start_date='$start_date', end_date='$end_date'");
    my ($calc_start_date, $calc_end_date) = $self->calcDate($now);
    $self->log(8, "calc_start_date=$calc_start_date, calc_end_date=$calc_end_date");
    #if ($calc_start_date && $calc_end_date && (!$start_date || $start_date != $calc_start_date || !$end_date || $end_date != $calc_end_date)) {
    if ($start_date ne $calc_start_date || $end_date ne $calc_end_date) {
        $self->{DB}->do("UPDATE event SET start_date=?, end_date=?, recalc_date=? WHERE id=?", undef, ($calc_start_date, $calc_end_date, toMysqlDate($now), $self->id())) || die $self->{DB}->errstr;
        $self->{data} = $self->{DB}->selectrow_hashref("SELECT id, name, timeline_id, data, UNIX_TIMESTAMP(start_date) AS start_date, UNIX_TIMESTAMP(end_date) AS end_date, UNIX_TIMESTAMP(mod_date) AS mod_date, UNIX_TIMESTAMP(create_date) AS create_date FROM event WHERE id = ?", undef, ($self->id()));
        return if ($param->{no_recurse});
        $self->log(7, "updating event dependencies");
        my $others = $self->{DB}->selectall_arrayref("SELECT * FROM event_date WHERE type='event' AND data=?", {Slice=>{}}, ($self->id()));
        foreach my $o (@$others) {
            my $e_id = $o->{event_id};
            next if ($e_id eq $self->id());
            my $e = new Timeline::Event($e_id);
            $e->updateDate($now);
        }
    }
    $self->log(7, "ending");
    return;
}

sub date {
    my $self = shift || return;
    my @dates = ();

    #unless ($self->{data}->{start_date} && $self->{data}->{end_date}) {
    #    $self->updateDate();
    #}
    @dates = ($self->{data}->{start_date}, $self->{data}->{end_date});

    return wantarray?@dates:$dates[0];
}

sub calcDate {
    my $self = shift || return;
    my $now = shift || return;

    $self->log(7, "starting");
    my $event_id = $self->id();

    my $default_start_date = 0;
    my $default_end_date = $now; # was $now

    my $start_date = $default_start_date;
    my $end_date = $default_end_date;
    foreach my $row (@{$self->{date}}) {
        my ($rule, $position, $type, $data) = ($row->{rule}, $row->{position}, $row->{type}, $row->{data});
        $self->log(8, "rule='$rule', position='$position', type='$type', data='$data'");
        my $data1;
        my $data2;

        if ($type eq 'event' && $data =~/^\d+$/) {
            my $event =  new Timeline::Event($data);
            ($data1, $data2) = $event->date();
            $self->log(8, $event->name() . " (" . $event->id(). ") start_date=$data1, end_date=$data2");
            $data1 = fromMysqlDate($data1);
            $data2 = fromMysqlDate($data2);
        } else {
            $data1 = fleshDate($data);
            $data2 = $data1;
        }
       $self->log(8, "data1='$data1', data2='$data2'");

        if ($position eq 'before') {
            my $n = $data1 - 86400; 
            if ($rule eq "start") {
                $start_date = $n if ($n >= $start_date && $n < $end_date);
            } elsif ($rule eq "end") {
                $end_date = $n if ($n <= $end_date && $n > $start_date);
            }
        } elsif ($position eq 'after') {
            my $n = $data2 + 86400;
            if ($rule eq "start") {
                $start_date = $n if ($n >= $start_date && $n < $end_date);
            } elsif ($rule eq "end") {
                $end_date = $n  if ($n <= $end_date && $n > $start_date);
            }
        } elsif ($position eq 'during') {
            my $n = $data1 + 3600;
            my $n2 = $data2 - 3600;
            if ($rule eq "start") {
                $start_date = $n if ($n >= $start_date && $n < $end_date);
            } elsif ($rule eq "end") {
                $end_date = $n2 if ($n2 <= $end_date && $n2 > $start_date);
            }
        } elsif ($position eq 'is') {
            if ($rule eq "start") {
                $start_date = $data1;
            } elsif ($rule eq "end") {
                $end_date = $data2;
            }
        }
    }
    $end_date = $start_date + 86400 if ($end_date == $default_end_date);
    $start_date = $end_date  - 86400 if ($start_date == $default_start_date);
    $self->log(8, "start_date='$start_date',end_date='$end_date'");
    $self->log(7, "ending");
    return wantarray?(toMysqlDate($start_date),toMysqlDate($end_date)):toMysqlDate($start_date);
}

sub delete {
    my $self = shift || return;

    $self->log(7, "starting");
    #my $DB = MinorImpact::{DB};
    $self->{DB}->do("DELETE FROM event_date WHERE event_id=?", undef, ($self->id()));
    $self->{DB}->do("DELETE FROM event_date WHERE type='event' AND data=?", undef, ($self->id()));
    $self->{DB}->do("DELETE FROM paragraph_event WHERE event_id=?", undef, ($self->id()));
    $self->{DB}->do("DELETE FROM entry_event WHERE event_id=?", undef, ($self->id()));
    $self->{DB}->do("DELETE FROM event_tag WHERE event_id=?", undef, ($self->id()));
    $self->{DB}->do("DELETE FROM event_reference WHERE event_id=?", undef, ($self->id()));
    $self->{DB}->do("DELETE FROM event WHERE id=?", undef, ($self->id()));
    $self->log(7, "ending");
}

sub getDateRules {
    my $self = shift || return;

    return $self->{date};
}

sub name {
    my $self = shift || return;

    return $self->get('name');
}


sub getUser {
    my $self = shift || return;

    $self->log(7, "starting");
    my $timeline = $self->getTimeline() || return;
    my $user = $timeline->user() || return;
    $self->log(7, "ending");
    return $user;
}

sub user_id {
    my $self = shift || return;

    $self->log(7, "starting");
    my $user = $self->getUser();
    $self->log(7, "ending");

    return $user->id();
}

sub getTimeline {
    my $self = shift || return;

    return new Timeline($self->get('timeline_id'));
}

sub getLocation {
    my $self = shift || return;

    $self->log(7, "starting");
    my $location;
    if ($self->get('location_id')) {
        $location = new Location($self->get('location_id'));
    }
    
    return $location;
}

sub _search {
    my $args = shift || {};

    MinorImpact::log(7, "starting");
    my $DB = MinorImpact::getDB();

    my $select = "SELECT distinct(e.id) AS id FROM event e JOIN timeline t ON t.id=e.timeline_id JOIN journal j on j.id=t.journal_id LEFT JOIN event_tag et ON e.id=et.event_id";
    my $where = "WHERE e.id > 0";

    if ($args->{user_id}) {
        $where .= " AND j.user_id=$args->{user_id}";
    }
    if ($args->{timeline_id}) {
        $where .= " AND e.timeline_id=" . $args->{timeline_id};
    }
    if ($args->{tag}) {
        $where .= " AND et.name='$args->{tag}'";
    }
    if ($args->{search}) {
        $where .= " AND e.data like '%$args->{search}%'";
    }
    if ($args->{location_id}) {
        $where .= " AND e.location_id = $args->{location_id}";
    }

    my $sql = "$select $where";
    MinorImpact::log(8, "sql='$sql'");

    my $journals = $DB->selectall_arrayref($sql, {Slice=>{}});

    MinorImpact::log(7, "starting");
    return map { $_->{id}; } @$journals;
}

sub search {
    my $args = shift || {};

    MinorImpact::log(7, "starting");
    my @ids = _search($args);
    return @ids if ($args->{id_only});
    my @events;
    foreach my $id (@ids) {
        my $event = new Timeline::Event($id);
        push(@events, $event);
    }
    MinorImpact::log(7, "ending");
    return sort {$a->date() cmp $b->date(); } @events;
}

sub toString {
    my $self = shift || return;
    $self->log(7, "starting");
    my $string;
    $string .= "<a href=event.cgi?id=" . $self->id() . ">" . $self->name() . "</a>";
    $self->log(7, "ending");
    return $string;
}

sub header {
    my $self = shift || return;

    my $event_id = $self->id();
    my $header = <<HEADER;
    <div id=view>
    <span id=view_back><a href=timeline.cgi?timeline_id=${\ $self->get('timeline_id'); }>Back</a></span>
    <div id=view_menu>
        <a href='event_edit.cgi?event_id=$event_id'>edit</a>
        <a href='event_delete.cgi?event_id=$event_id'>delete</a>
    </div>
    <span id=view_name>${\ $self->name(); }</span>
HEADER
    return $header;
}

sub footer {
    my $self = shift || return;

    my $footer = <<FOOTER;
    </div>
FOOTER
    return $footer;
}

1;
