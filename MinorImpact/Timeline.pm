package MinorImpact::Timeline;

use DBI;
use CGI;
use Data::Dumper;

use MinorImpact::Util;
use MinorImpact::Timeline::Event;
use MinorImpact::User;

sub new {
    my $package = shift;
    my $params = shift;
    my $options = shift || {};

    my $self = {};
    bless($self, $package);
    
    $self->log(7, "starting");
    $self->{DB} = MinorImpact::getDB();
    $self->{CGI} = MinorImpact::getCGI();
    $self->{options} = $options;

    my $timeline_id;
    if (ref($params) eq 'HASH') {
        if ($params->{name}) {
            $self->{DB}->do("INSERT INTO timeline(name, description, journal_id, create_date) VALUES (?, ?, ?, NOW())", undef, ($params->{'name'}, $params->{'description'}, $params->{journal_id})) || die("Can't add new timeline:" . $self->{DB}->errstr);
            $timeline_id = $self->{DB}->{mysql_insertid};
        }
    } elsif ($params =~/^\d+$/) {
        $timeline_id = $params;
    } else {
        $timeline_id = $self->{CGI}->param('timeline_id') || $MinorImpact::SELF->redirect('timelines.cgi');
    }

    if ($timeline_id) {
        my $sql = "SELECT id, name, description, journal_id FROM timeline WHERE id = ?";
        $self->{data} = $self->{DB}->selectrow_hashref("SELECT id, name, description, journal_id FROM timeline WHERE id = ?", undef, ($timeline_id)) || die "$sql ($timeline_id):" . $self->{DB}->errstr;
    }

    $self->log(7, "ending");
    return $self;
}

sub getEvents {
    my $self = shift || return;
    my $params = shift || {};

    my @events = ();
    my $local_params = cloneHash($params);
    $local_params->{timeline_id} = $self->id();
    my @events = ();
    foreach my $event_id (Timeline::Event::_search($local_params)) {
        $self->log(8, "event_id=$event_id");
        if ($params->{id_only} == 1) {
            push(@events, $event_id);
        } else {
            push(@events, new Timeline::Event($event_id, $self->{options}));
        }
    }
    $self->log(7, 'ending');

    return @events;
}

sub getEntry {
    my $self = shift || return;
    my $entry_id = shift || $self->{CGI}->param('entry_id') || $self->{CGI}->param('id');

    return new Entry($entry_id);
}

sub getParagraphs {
    my $self = shift || return;
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

sub update {
    my $self = shift || return;
    my $params = shift || return;

    $self->log(7, "starting");
    $self->{DB}->do("UPDATE timeline SET name=?, journal_id=?, description=? WHERE id=?", undef, ($params->{'name'}, $params->{journal_id}, $params->{'description'}, $self->id())) || die("Can't update timeline:" . $self->{DB}->errstr);
    $self->log(7, "ending");
    return;
}

sub name {
    my $self = shift || return;

    return $self->get('name');
}

sub user_id {
    my $self = shift || return;

    return $self->user()->id();
}

sub getJournal {
    my $self = shift || return;

    return new Journal($self->get('journal_id'));
}

sub getUser {
    my $self = shift || return;
    return $self->getJournal()->getUser();
}

sub user {
    my $self = shift || return;
    return $self->getUser();
}

sub _search {
    my $args = shift || {};
    my $DB = MinorImpact::getDB();

    my $select = "SELECT DISTINCT(id) FROM timeline";
    my $where = "WHERE id > 0";

    if ($args->{user_id}) {
        $where .= " AND user_id=" . $args->{user_id};
    }

    if ($args->{journal_id}) {
        $where .= " AND journal_id=" . $args->{journal_id};
    }
    my $sql = "$select $where";

    #print "$sql\n";
    my $timelines = $DB->selectall_arrayref($sql, {Slice=>{}});

    return map { $_->{id}; } @$timelines;
}

sub getEntries {
    my $self = shift || return;
    my $params = shift || {};

    my $local_params = cloneHash($params);
    $local_params->{timeline_id} = $self->id();

    foreach my $entry_id (Entry::_search($local_params)) {
        if ($params->{id_only} == 1) {
            push(@entries, $event_id);
        } else {
            push(@entries, new Entry($entry_id));
        }
    }
    return @entries;
}

sub getEvent {
    my $self = shift || return;
    my $event_id = shift || return;

    return new Timeline::Event($event_id);
}

sub delete {
    my $self = shift || return;

    foreach my $event ($self->getEvents()) {
        $event->delete();
    }
        
    $self->{DB}->do("DELETE FROM timeline WHERE id=?", undef, ($self->id()));
}

sub eventSelect {
    my $self = shift || return;

    $self->log(7, "starting");
    my $event_select = "<select name='event_'>\n";
    $event_select .= "<option value=''></option>\n";
    my @events = $self->getEvents();
    foreach my $event (sort {lc($a->name()) cmp lc($b->name())} @events) {
        $self->log(8, "event->id()=" . $event->id());
        $event_select .= "<option value='" . $event->id() . "'>" . $event->get('name') . "</option>\n";
    }
    $event_select .= "</select>\n";
    $self->log(7, "ending");
    return $event_select;
}

sub dateSelect {
    my $self = shift || return;
    my $event = shift;

    $self->log(7, "starting");
    my $i = 1;
    my @rule = ("start", "end");
    my @pos = ("is", "before", "during", "after");

    my $rule_select = "<select name='rule_' >\n";
    foreach my $rule (@rule) {
        $rule_select .= "<option value='$rule'>$rule</option>\n";
    }
    $rule_select .= "</select>\n";

    my $position_select = "<select name='position_' >\n";
    foreach my $pos (@pos) {
        $position_select .= "<option value='$pos'>$pos</option>\n";
    }
    $position_select .= "</select>\n";

    my $event_select = $self->eventSelect();

    my $date_select;
    if ($event && ref($event) eq 'Timeline::Event') {
        my $event_id = $event->id();
        $event_select =~s/<option value='$event_id'>[^\n]+\n//;
        foreach my $row (@{$event->{date}}) {
            my $rselect = $rule_select;
            $rselect =~s/name='rule_'/name='rule_$i'/;
            $rselect =~s/value='$row->{rule}'/value='$row->{rule}' selected/;
            my $pselect = $position_select;
            $pselect =~s/name='position_'/name='position_$i'/;
            $pselect =~s/value='$row->{position}'/value='$row->{position}' selected/;
            my $eselect = $event_select;
            $eselect =~s/name='event_'/name='event_$i'/;
            if ($row->{type} eq 'event') {
                $eselect =~s/value='$row->{data}'/value='$row->{data}' selected/;
            }

            my $typeevent = "<table>\n";
            $typeevent .= "<tr><td><input type=radio name=type_$i value=event" . ($row->{type} eq 'event'?' checked':'') . "> Event</td><td>$eselect</td></tr>\n";
            $typeevent .= "</td><td><input type=radio name=type_$i value=date" . ($row->{type} eq 'date'?' checked':'') . "> Date</td><td><input type=text name=date_$i value='" . (($row->{type} eq 'date')?$row->{data}:'') . "'></td></tr>\n";
            $typeevent .= "</table>\n";

            $date_select .= "<table><tr><td valign=middle>$rselect</td><td valign=middle>$pselect</td><td valign=middle>$typeevent</td><td><input type=checkbox name='delete_$i'>X</td></tr></table>\n";
            $i++;
        }
    }

    $rule_select =~s/name='rule_'/name='rule_$i'/;
    $position_select =~s/name='position_'/name='position_$i'/;
    $event_select =~s/name='event_'/name='event_$i'/;
    my $typeevent = "<table>\n";
    $typeevent .= "<tr><td><input type=radio name=type_$i value=event> Event</td><td>$event_select</td></tr>\n";
    $typeevent .= "</td><td><input type=radio name=type_$i value=date> Date</td><td><input type=text name=date_$i value=''></td></tr>\n";
    $typeevent .= "</table>\n";
    $date_select .= "<table><tr><td valign=middle>$rule_select</td><td valign=middle>$position_select</td><td valign=middle>$typeevent</td></tr></table>\n";

    $self->log(7, "ending");
    return $date_select;
}

sub log {
    my $self = shift || return;
    my $level = shift || return;
    my $message = shift || return;

    MinorImpact::log($level, $message);
    return;
}

sub toString {
    my $self = shift || return;

    $self->log(7, "starting");
    my $string = "<a href=timeline.cgi?timeline_id=" . $self->id() . ">" . $self->name() . "</a>";
    $self->log(7, "ending");
    return $string;
}
sub search {
    my $args = shift || {};

    my @ids = _search($args);
    return @ids if ($args->{id_only});
    my @timelines;
    foreach my $id (@ids) {
        my $timeline = new Timeline($id);
        push(@timelines, $timeline);
    }
    return @timelines;
}

sub header {
    my $self = shift || return;

    my $header = <<HEADER;
HEADER
    return $header;
}

1;
