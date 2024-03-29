package StateML::Machine;

=head1 NAME

StateML::Machine - a StateML state machine data structure

=head1 DESCRIPTION

Contains all events, arcs and states for a state machine.

=head1 METHODS

=over

=cut

use strict ;
use Carp ;
use StateML::Action ;
use StateML::Arc ;
use StateML::Class ;
use StateML::Event ;
use StateML::State ;
use StateML::Utils qw( empty as_str );

use base qw( StateML::Object ) ;

#use SelfTest ;

=for testing
    use Test ;
    use StateML::Machine ;
    plan tests => 0 ;

=item new

    my $m = StateML::Machine->new ;

=for testing
    my $m = StateML::Machine->new(
        EVENTS  => [1,2],
        ARCS    => [1,2,3],
        STATES  => [1,2,3,4],
    ) ;
    ok( ref $m ) ;

=cut

sub new {
    my $proto = shift ;

    my $self = $proto->SUPER::new(
        ACTIONS => [],
        ARCS    => [],
        CLASSES => [],
        EVENTS  => [],
        STATES  => [],
        OBJECTS => {},  ## All objects, indexed on id.
        MODES   => [],
        ALL_STATE => StateML::State->new( ID => "#ALL", ORDER => -1 ),
        @_,   ## TODO: Error check the args.
    ) ;

    ## Note that the #ALL state is not put in STATES.
    my $all = $self->{ALL_STATE} ;
    $all->machine( $self->{ID} ) ;
    $all->_set_number( -1 ) ;
    $all->{PARENT_ID} = $self->{ID} ;
    $self->{OBJECTS}->{"#ALL"} = $all ;
    $self->assert_valid ;
    return $self ;
}


=item autogenerated_message

Sets/gets a suitable warning message that can be placed in a template file.

Use only [\w :./!,-] in this warning message and no newlines, tabs, or other
control codes.

=cut

sub autogenerated_message {
    my $self = shift ;
    if ( @_ ) {
        my ( $message ) = @_ ;
Carp::confess unless defined $message;
        if ( $message =~ /([^\w\t :.\\\/!,-])/ ) {
            croak "Illegal characters ('$1') in message '$message'\n"
        }
        $self->{AUTOGENERATED_MESSAGE} = $message ;
    }
    return $self->{AUTOGENERATED_MESSAGE} || "AUTOGENERATED, DO NOT EDIT!!" ;
}

    


sub _number_states {
    ## We do this lazily so that changes to a state's id or to the
    ## list of states are always reflected in the numbers.  That might
    ## be overdesign, time will tell.
    my $self = shift ;
    my $i = 0 ;

    ## Number states startign at 1 so that 0 is left available for
    ## initting or "unknown".  #ALL is always -1.
    $_->_set_number( ++$i )
        for @{$self->{STATES}} ;
}


=item modes

Set/get the list of modes that will be used to control what portions of
the document get parsed.  This is used to conditionally control
inclusion of things like optional states or language-specific APIs.

=cut

sub modes {
    my $self = shift ;
    $self->{MODES} = [ @_ ] if @_ ;
    return @{$self->{MODES}};
}


=item all_state

Returns the "#ALL" state.

=cut

sub all_state { return shift()->{ALL_STATE} }

=item states

Returns a list of all states other than state #ALL.

=for testing
    ok( scalar $m->states, 4, "number of states" ) ;

=cut

sub states {
    my $self = shift ;
    $self->_number_states ;
    return sort {
        $a->number <=> $b->number
    } @{$self->{STATES}} ;
}


=item raw_states

Returns a list of all states including #ALL.

=for testing
    ok( scalar $m->states, 4, "number of states" ) ;

=cut

sub raw_states {
    my $self = shift ;
    $self->_number_states ;
    return sort {
        $a->number <=> $b->number
    } @{$self->{STATES}}, $self->{ALL_STATE} ;
}


=item description

Sets or gets a textual description of the machine

=cut

sub description {
    my $self = shift ;
    $self->{DESCRIPTION} = shift if @_ ;
    return $self->{DESCRIPTION};
}


=item actions

Returns a list of all actions.

=for testing
    ok( scalar $m->actions, 2, "number of actions" ) ;

=cut

sub actions {
    my $self = shift ;
    return @{$self->{ACTIONS}} ;
}


=item classes

Returns a list of all classes

=for testing
    ok( scalar $m->classes, 2, "number of classes" ) ;

=cut

sub classes {
    my $self = shift ;
    return @{$self->{CLASSES}} ;
}


=item events

Returns a list of all events.

=for testing
    ok( scalar $m->events, 2, "number of events" ) ;

=cut

sub events {
    my $self = shift ;
    return @{$self->{EVENTS}} ;
}


=item arcs

Returns a list of all arcs.

=for testing
    ok( scalar $m->arcs, 3, "number of arcs" ) ;

=cut

sub arcs {
    my $self = shift ;
    return @{$self->{ARCS}} ;
}


=item preamble

Returns the preamble code.

=cut

sub preamble {
    my $self = shift ;
    return $self->{PREAMBLE}->[0] ;
}


=item postamble

Returns the postamble code.

=cut

sub postamble {
    my $self = shift ;
    return $self->{POSTAMBLE}->[0] ;
}


=item object_by_id

    my $object = $m->object_by_id( $id ) ;
    my $object = $m->object_by_id( $id, $require_type ) ;

Returns the state, event, or arc labelled $id or undef if one isn't found.

If present, $required_type is used to make sure that the object requested
if of the indicated type.

=cut

sub object_by_id {
    my $self = shift ;
    my ( $id, $type ) = @_ ;

    return undef unless defined $id;

    my $obj ; 
    if ( exists $self->{OBJECTS}->{$id} ) {
        $obj = $self->{OBJECTS}->{$id} ;
        die "$id is not a $type"
            if $type && ! $obj->isa( $type ) ;
        return $obj ;
    }
    return undef ;
}


=item action_by_id

Returns an action given it's id.  Dies if $id refers to a non-state.

=cut

sub action_by_id {
    my $self = shift ;
    return $self->object_by_id( shift, "StateML::Action" ) ;
}


=item class_by_id

Returns a class given it's id.  Dies if $id refers to a non-class.

In general this is not used because inheritance works across
all objects.

=cut

sub class_by_id {
    my $self = shift ;
    return $self->object_by_id( shift, "StateML::Class" ) ;
}


=item event_by_id

Returns a event given it's id.  Dies if $id refers to a non-event.

=cut

sub event_by_id {
    my $self = shift ;
    return $self->object_by_id( shift, "StateML::Event" ) ;
}


=item state_by_id

Returns a state given it's id.  Dies if $id refers to a non-state.

=cut

sub state_by_id {
    my $self = shift ;
    return $self->object_by_id( shift, "StateML::State" ) ;
}


=item add

    $m->add( $arc ) ;
    $m->add( $class ) ;
    $m->add( $event ) ;
    $m->add( $state ) ;

=cut

sub add {
    my $self = shift ;
    for ( @_ ) {
        my $id = $_->id ;
        if ( exists $self->{OBJECTS}->{$id} || $id eq $self->{ID} ) {
            my $new_type = ref $_ ;
            my $old_type = ref $self->{OBJECTS}->{$id} ;
            $old_type =~ s/^StateML::// ;
            $new_type =~ s/^StateML::// ;
            $new_type = $old_type eq $new_type ? "" : " (held by $new_type)" ;
            croak "Can't add $old_type with duplicate ID '$id'$new_type.\n"
        }
        $_->machine( $self ) ;
        $self->{OBJECTS}->{$_->id} = $_ ;
        my $t = $_->type;
        my $type = $t eq "CLASS" ? "${t}ES": "${t}S" ;
        push @{$self->{$type}}, $_ ;
    }
}


=item extract_output_machine 

    my $om = $m->extract_output_machine( \@types ) ;

Returns an output machine comprised of the events, arcs, and states
that match the \@types specified.

=cut

sub extract_output_machine {
    my $self = shift ;
    my $options = {@_} ;

    $options->{raw} = 1 ;

    my @events = $self->matching_events( $options ) ;
    warn "no events found\n" unless @events ;

    $self->_number_states ;
    my @arcs = map $self->arcs_for_event( $_, $options ), @events ;
    warn "no arcs found\n" unless @arcs ;

    my @states = map $self->states_for_arc( $_, $options ), @arcs ;
    warn "no states found\n" unless @states ;

    ## Remove #ALL and duplicate states.
    @states = values %{{ map {
        ( $_ => $_ )
    } grep $_->id ne "#ALL", @states }} ;

    @states = sort { $a->number <=> $b->number } @states ;

    my $clone = $self->new(
        ID          => $self->{ID},
        LOCATION    => $self->{LOCATION},
        ALL_STATE   => $self->{ALL_STATE},
        PREAMBLE    => $self->{PREAMBLE},
        POSTAMBLE   => $self->{POSTAMBLE},
        DESCRIPTION => $self->{DESCRIPTION},
        ATTRS       => $self->{ATTRS},
        MODES       => [ @{$self->{MODES}} ],
        AUTOGENERATED_MESSAGE => $self->{AUTOGENERATED_MESSAGE},
    ) ;

    $clone->add( @events, @states, @arcs, $self->classes, $self->actions ) ;

    return $clone ;
}

=item matching_events

   my @events = $m->matching_events( types=>\@types ) ;
   my @events = $m->matching_events( types=>[ "ui", "io" ] ) ;

Gets all events that have type= attributes that match an entry in @types.
If no parameters are passed, all events are returned.

Events with a type of "#ANY" or "#ALL" (case insensitive) will show up
in all filter settings.  Passing "all", "any", "#all", or "#any" in the
typelist will cause all events to be returned.

=cut

sub matching_events {
    my $self = shift ;
    my $options = @_ && ref $_[-1] eq "HASH" ? pop : {} ;

    my $types = $options->{types} ;

    return @{$self->{EVENTS}} unless $types && @$types ;

    my %events ;
    my @specs ;
    my @not_specs ;

    for ( @$types ) {
        if ( substr( $_, 0, 1 ) eq "!" ) {
            push @not_specs, uc substr $_, 1 ;
        }
        else {
            push @specs, uc $_ ;
        }
    }

    for ( @{$self->{EVENTS}} ) {
        my $type_re = qr/^($_->{TYPE})$/i ;
        $events{$_} = $_
            if    "#ALL" =~ $type_re
               || "#ANY" =~ $type_re
               || ( ( ! @specs && @not_specs ) || grep $_ =~ $type_re, @specs )
               && ! grep( $_ =~ $type_re, @not_specs ) ;
    }

    return values %events ;
}


=item arcs_for_event

    my @arcs = $m->arcs_for_event( $event ) ;

Returns all arcs in the state machine for event $event.

A arc is an edge in the state machine diagram.

Unfolds arcs in state #ALL to be for all states.

=cut

sub arcs_for_event {
    my $self = shift ;
    my $options = @_ && ref $_[-1] eq "HASH" ? pop : {} ;
    my ( $event ) = @_ ;

    my %arcs ;
    my @arcs_for_all ;

    ## First, get all explicit ARCs, then inherit ARCs from #ALL if no
    ## explicit ARCS.
    my $uc_event_id = uc $event->id ;
    for my $arc ( $self->arcs ) {
        next unless uc $arc->event_id eq $uc_event_id ;
        if ( uc $arc->from eq "#ALL" ) {
            push @arcs_for_all, $arc ;
        }

        $arcs{uc $arc->from . ($arc->guard || "" )} = $arc ;
    }

    if ( exists $arcs{"#ALL"} && ! $options->{raw} ) {
        delete $arcs{"#ALL"} ;
        for my $arc ( @arcs_for_all ) {
            for my $from_state ( $self->states ) {
                ## #ALL arcs don't replace explicit arcs.  TODO: We may add
                ## a merge_with_overrides = "before" or "after" attr on #ALL
                ## arcs to allow handlers from both arcs to be run.
                next if exists $arcs{uc $from_state->id} ;
                $arcs{uc $from_state->id} = StateML::Arc->new(
                    %$arc,
                    ID   => $arc->id . "_" . $from_state->id,
                    FROM => $from_state->id,
                    TO   => uc $arc->to eq "#ALL"
                        ? $from_state->id
                        : $arc->to,
                    DESCRIPTION => $arc->description,
                ) ;
            }
        }
    }

    ## Return results in a stable order, one that agrees with the state enum
    ## and which perhaps is more likely to be easily optimizable by compilers.
    map warn( $_->id ), grep( ! defined $_->number,
       map( { ( $_->from_state, $_->to_state ) } values %arcs ) ) ;

    my @arcs = sort {
        $a->from_state->number <=> $b->from_state->number
    } values %arcs ;

    return @arcs ;
}


=item all_state_arcs_for_event

    my @arcs = $m->all_state_arcs_for_event( $event ) ;

Returns all arcs in the state machine for event $event.

A arc is an edge in the state machine diagram.

=cut

sub all_state_arc_for_event {
    my $self = shift ;
    my $options = @_ && ref $_[-1] eq "HASH" ? pop : {} ;
    my ( $event ) = @_ ;

    my $uc_event_id = uc $event->id ;
    ## Note that there can be only one arc for a given even in the #ALL state.
    for my $arc ( $self->arcs ) {
        next unless uc $arc->event_id eq $uc_event_id
            && uc $arc->from eq "#ALL" ;
        return $arc ;
    }
    return undef ;
}


=item states_by_id

    my %states_by_id = $m->states_by_id ;

Returns a HASH ref of all states indexed by their id= attributes.

=cut

sub states_by_id {
    my $self = shift ;

    $self->_number_states ;

    return {
        map { ( $_->{ID} => $_ ) } @{$self->{STATES}}
    } ;

}


=item states_for_arc

    my @states = $m->states_for_arc( $arc ) ;

Returns all states that appear as starting or ending points for $arc
other than the "#ALL" state.  Will only return one state for loopbacks.

=cut

sub states_for_arc {
    my $self = shift ;
    my $options = @_ && ref $_[-1] eq "HASH" ? pop : {} ;
    my ( $arc ) = @_ ;

    my %states ;

    $states{$arc->from} = $arc->from_state ;
    $states{$arc->to}   = $arc->to_state ;

    return values %states ;
}


=item assert_valid

    $m->assert_valid ;

Dies if there are dangling references.  The error message contains all
undefined states, events, etc.

=cut

sub assert_valid {
    my $self = shift ;

    my @errors ;

    my %from_state_via_event ;
    my %states_with_mult_arcs_same_event ;

    for my $arc ( @{$self->{ARCS}} ) {
        my $unique_id = $arc->event_id;
        $unique_id .= "[" . $arc->guard . "]" if defined $arc->guard;

$DB::single = 1;
        if ( empty $arc->from ) {
            push @errors,
                "no from state (",
                as_str( $arc->from ),
                ") in arc$arc->{LOCATION}\n"
        }
        elsif ( ! $self->state_by_id( $arc->from ) ) {
            push @errors,
                "unknown from state ",
                as_str( $arc->from ),
                " in arc$arc->{LOCATION}\n";
        }
        else {
            $states_with_mult_arcs_same_event{$arc->from} = $unique_id
                if $from_state_via_event{$arc->from,$unique_id};
            $from_state_via_event{$arc->from,$unique_id} = $arc ;
        }

        if ( empty $arc->to ) {
            push @errors,
                "no to state (", as_str( $arc->to ), ") in arc$arc->{LOCATION}\n";
        }
        elsif ( ! $self->state_by_id( $arc->to ) ) {
            push @errors,
                "unknown to state ",
                as_str( $arc->to ),
                " in arc$arc->{LOCATION}\n";
        }

        if ( empty $arc->event_id ) {
            push @errors,
                "no event-id ",
                as_str( $arc->event_id ),
                " in arc$arc->{LOCATION}\n"
        }
        elsif ( ! $self->event_by_id( $arc->event_id ) ) {
            push @errors,
                "unknown event-id ",
                as_str( $arc->event_id ),
                " in arc$arc->{LOCATION}\n";
        }
    }

    ## TODO: Make this optional.
    for ( sort keys %states_with_mult_arcs_same_event ) {
        push @errors,
            "multiple arcs exit from state $_ by event ",
            $states_with_mult_arcs_same_event{$_},
            "\n" ;
    }

    my %dup_enum_ids ;
    {
        my %enum_ids ;
        for ( values %{$self->{OBJECTS}} ) {
            $dup_enum_ids{$_->enum_id} = $enum_ids{$_->enum_id}
                if exists $enum_ids{$_->enum_id} ;
            push @{$enum_ids{$_->enum_id}}, $_ ;
        }
    }

    for ( keys %dup_enum_ids ) {
        warn 
            "multiple objects with the enum_id '$_': ",
            join( " ", @{$dup_enum_ids{$_}} ),
            "\n" ;
    }

    die @errors if @errors ;

    return ;
}

=back

=head1 LIMITATIONS

Alpha code.  Ok test suite, but we may need to change things in
non-backward compatible ways.

=head1 COPYRIGHT

    Copyright 2003, R. Barrie Slaymaker, Jr., All Rights Reserved

=head1 LICENSE

You may use this module under the terms of the BSD, Artistic, or GPL licenses,
any version.

=head1 AUTHOR

Barrie Slaymaker <barries@slaysys.com>

=cut


1 ;
