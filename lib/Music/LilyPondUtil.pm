# http://www.lilypond.org/ related utility code (mostly to transition
# between Perl processing integers and the related appropriate letter
# names for the black dots in lilypond).

package Music::LilyPondUtil;

use 5.010000;
use strict;
use warnings;
use Carp qw(croak);
use Scalar::Util qw(blessed looks_like_number);

our $VERSION = '0.30';

# Since dealing with lilypond, assume 12 pitch material
my $DEG_IN_SCALE = 12;
my $TRITONE      = 6;

# same register characters used by both absolute and relative mode
my %REGISTERS = (
  0 => q(,,,,),
  1 => q(,,,),
  2 => q(,,),
  3 => q(,),
  4 => q(),
  5 => q('),
  6 => q(''),
  7 => q('''),
  8 => q(''''),
  9 => q('''''),
);
my $REL_DEF_REG = 4;    # for relative mode, via %REGISTERS

# and the reverse for notes2pitches
my %REVREGS = (
  q(,,,,)  => 0,
  q(,,,)   => 1,
  q(,,)    => 2,
  q(,)     => 3,
  q()      => 4,
  q(')     => 5,
  q('')    => 6,
  q(''')   => 7,
  q('''')  => 8,
  q(''''') => 9,
);

# Just the note and register information - the 0,6 bit grants perhaps
# too much leeway for relative motion (silly things like c,,,,,,,
# relative to the top note on a piano) but there are other bounds on the
# results so that they lie within the span of the MIDI note numbers.
my $LY_NOTE_RE = qr/(([a-g])(?:eses|isis|es|is)?)(([,'])\g{-1}{0,6})?/;

my %N2P = (
  qw/bis 0 c 0 deses 0 bisis 1 cis 1 des 1 cisis 2 d 2 eeses 2 dis 3 ees 3 feses 3 disis 4 e 4 fes 4 eis 5 f 5 geses 5 eisis 6 fis 6 ges 6 fisis 7 g 7 aeses 7 gis 8 aes 8 gisis 9 a 9 beses 9 ais 10 bes 10 ceses 10 aisis 11 b 11 ces 11/
);
# mixing flats and sharps not supported, either one or other right now
my %P2N = (
  flats  => {qw/0 c 1 des 2 d 3 ees 4 e 5 f 6 ges 7 g 8 aes 9 a 10 bes 11 b/},
  sharps => {qw/0 c 1 cis 2 d 3 dis 4 e 5 f 6 fis 7 g 8 gis 9 a 10 ais 11 b/},
);

# Diabolus in Musica, indeed (direction tritone heads in relative mode)
my %TTDIR = (
  flats  => {qw/0 -1 1 1 2 -1 3 1 4 -1 5 1 6 1 7 -1 8 1 9 -1 10 1 11 -1/},
  sharps => {qw/0 1 1 -1 2 1 3 -1 4 1 5 1 6 -1 7 1 8 -1 9 1 10 -1 11 -1/},
);

########################################################################
#
# SUBROUTINES

sub new {
  my ( $class, %param ) = @_;
  my $self = {};

  $self->{_chrome} = $param{chrome} || 'sharps';
  croak("chrome must be 'sharps' or 'flats'")
    unless exists $P2N{ $self->{_chrome} };

  $self->{_keep_state}      = $param{keep_state}      // 1;
  $self->{_ignore_register} = $param{ignore_register} // 0;

  # Default min_pitch of 21 causes too many problems for existing code,
  # so minimum defaults to 0, which is a bit beyond the bottom of 88-key
  # pianos. 108 is the top of a standard 88-key piano.
  $self->{_min_pitch} = $param{min_pitch} // 0;
  $self->{_max_pitch} = $param{max_pitch} // 108;

  $self->{_mode} = $param{mode} || 'absolute';
  croak("'mode' must be 'absolute' or 'relative'")
    if $self->{_mode} ne 'absolute' and $self->{_mode} ne 'relative';

  $self->{_p2n_hook} = $param{p2n_hook}
    || sub { $P2N{ $_[1] }->{ $_[0] % $DEG_IN_SCALE } };
  croak("'p2n_hook' must be code ref")
    unless ref $self->{_p2n_hook} eq 'CODE';

  $self->{_sticky_state} = $param{sticky_state} // 0;
  $self->{_strip_rests}  = $param{strip_rests}  // 0;

  bless $self, $class;
  return $self;
}

sub chrome {
  my ( $self, $chrome ) = @_;
  if ( defined $chrome ) {
    croak("chrome must be 'sharps' or 'flats'") unless exists $P2N{$chrome};
    $self->{_chrome} = $chrome;
  }
  return $self->{_chrome};
}

# diatonic (piano white key) pitch number for a given input note (like
# prev_note() below except without side-effects).
sub diatonic_pitch {
  my ( $self, $note ) = @_;

  croak "note not defined" unless defined $note;

  my $pitch;
  if ( $note =~ m/^$LY_NOTE_RE/ ) {
    # TODO duplicates (portions of) same code, below
    my $real_note     = $1;
    my $diatonic_note = $2;
    my $reg_symbol    = $3 // '';

    croak "unknown lilypond note $note" unless exists $N2P{$real_note};
    croak "register out of range for note $note"
      unless exists $REVREGS{$reg_symbol};

    $pitch = $N2P{$diatonic_note} + $REVREGS{$reg_symbol} * $DEG_IN_SCALE;
    $pitch %= $DEG_IN_SCALE if $self->{_ignore_register};

    if ( $pitch < $self->{_min_pitch} or $pitch > $self->{_max_pitch} ) {
      croak "pitch $pitch is out of range\n";
    }

  } else {
    croak("unknown note $note");
  }

  return $pitch;
}

sub ignore_register {
  my ( $self, $state ) = @_;
  $self->{_ignore_register} = $state if defined $state;
  return $self->{_ignore_register};
}

sub keep_state {
  my ( $self, $state ) = @_;
  $self->{_keep_state} = $state if defined $state;
  return $self->{_keep_state};
}

sub mode {
  my ( $self, $mode ) = @_;
  if ( defined $mode ) {
    croak("mode must be 'absolute' or 'relative'")
      if $mode ne 'absolute' and $mode ne 'relative';
    $self->{_mode} = $mode;
  }
  return $self->{_mode};
}

########################################################################
#
# lilypond notes to pitch numbers

{
  my $prev_note;

  sub clear_prev_note {
    my ($self) = @_;
    undef $prev_note;
  }

  # MUST NOT accept raw pitch numbers, as who knows if "61" is a "cis"
  # or "des" or the like, which will in turn affect the relative
  # calculations!
  sub prev_note {
    my ( $self, $pitch ) = @_;
    if ( defined $pitch ) {
      if ( $pitch =~ m/^$LY_NOTE_RE/ ) {
        # TODO duplicates (portions of) same code, below
        my $real_note     = $1;
        my $diatonic_note = $2;
        my $reg_symbol    = $3 // '';

        croak "unknown lilypond note $pitch" unless exists $N2P{$real_note};
        croak "register out of range for note $pitch"
          unless exists $REVREGS{$reg_symbol};

        # for relative-to-this just need the diatonic
        $prev_note =
          $N2P{$diatonic_note} + $REVREGS{$reg_symbol} * $DEG_IN_SCALE;

      } else {
        croak("unknown pitch '$pitch'");
      }
    }
    return $prev_note;
  }

  sub notes2pitches {
    my $self = shift;
    my @pitches;

    for my $n (@_) {
      # pass through what hopefully are raw pitch numbers, otherwise parse
      # note from subset of the lilypond note format
      if ( !defined $n ) {
        # might instead blow up? or have option to blow up...
        push @pitches, undef unless $self->{_strip_rests};

      } elsif ( $n =~ m/^(-?\d+)$/ ) {
        push @pitches, $n;

      } elsif ( $n =~ m/^(?i)[rs]/ or $n =~ m/\\rest/ ) {
        # rests or lilypond 'silent' bits
        push @pitches, undef unless $self->{_strip_rests};

      } elsif ( $n =~ m/^$LY_NOTE_RE/ ) {
        # "diatonic" (here, the white notes of a piano) are necessary
        # for leap calculations in relative mode, as "cisis" goes down
        # to "aeses" despite the real notes ("d" and "g," in absolute
        # mode) being a fifth apart. Another way to think of it: the
        # diatonic "c" and "a" of "cisis" and "aeses" are within three
        # stave lines of one another; anything involving three or more
        # stave lines is a leap.
        my $real_note     = $1;
        my $diatonic_note = $2;
        my $reg_symbol    = $3 // '';

        croak "unknown lilypond note $n" unless exists $N2P{$real_note};

        my ( $diatonic_pitch, $real_pitch );
        if ( $self->{_mode} ne 'relative' ) {    # absolute
          croak "register out of range for note $n"
            unless exists $REVREGS{$reg_symbol};

          # TODO see if can do this code regardless of mode, and still
          # sanity check the register for absolute/relative-no-previous,
          # but not for relative-with-previous, to avoid code
          # duplication in abs/r-no-p blocks - or call subs with
          # appropriate register numbers.
          ( $diatonic_pitch, $real_pitch ) =
            map { $N2P{$_} + $REVREGS{$reg_symbol} * $DEG_IN_SCALE }
            $diatonic_note, $real_note;

          # Account for edge cases of ces and bis and the like
          my $delta = $diatonic_pitch - $real_pitch;
          if ( abs($delta) > $TRITONE ) {
            $real_pitch += $delta > 0 ? $DEG_IN_SCALE : -$DEG_IN_SCALE;
          }

        } else {    # relatively more complicated

          if ( !defined $prev_note ) {    # absolute if nothing prior
            croak "register out of range for note $n"
              unless exists $REVREGS{$reg_symbol};

            ( $diatonic_pitch, $real_pitch ) =
              map { $N2P{$_} + $REVREGS{$reg_symbol} * $DEG_IN_SCALE }
              $diatonic_note, $real_note;

            # Account for edge cases of ces and bis and the like
            my $delta = $diatonic_pitch - $real_pitch;
            if ( abs($delta) > $TRITONE ) {
              $real_pitch += $delta > 0 ? $DEG_IN_SCALE : -$DEG_IN_SCALE;
            }

          } else {    # meat of relativity
            my $reg_number =
              int( $prev_note / $DEG_IN_SCALE ) * $DEG_IN_SCALE;

            my $reg_delta = $prev_note % $DEG_IN_SCALE - $N2P{$diatonic_note};
            if ( abs($reg_delta) > $TRITONE ) {
              $reg_number += $reg_delta > 0 ? $DEG_IN_SCALE : -$DEG_IN_SCALE;
            }

            # adjust register by the required relative offset
            my $reg_offset = _symbol2relreg($reg_symbol);
            if ( $reg_offset != 0 ) {
              $reg_number += $reg_offset * $DEG_IN_SCALE;
            }

            # confine things to MIDI pitch numbers
            if ( $reg_number < 0 or $reg_number > 96 ) {
              croak "register out of range for $n\n";
            }

            ( $diatonic_pitch, $real_pitch ) =
              map { $reg_number + $N2P{$_} } $diatonic_note, $real_note;

            my $delta = $diatonic_pitch - $real_pitch;
            if ( abs($delta) > $TRITONE ) {
              $real_pitch += $delta > 0 ? $DEG_IN_SCALE : -$DEG_IN_SCALE;
            }
          }

          $prev_note = $diatonic_pitch if $self->{_keep_state};
        }

        push @pitches, $real_pitch;

      } else {
        croak "unknown note '$n'";
      }
    }

    if ( $self->{_ignore_register} ) {
      for my $p (@pitches) {
        $p %= $DEG_IN_SCALE if defined $p;
      }
    }

    undef $prev_note unless $self->{_sticky_state};

    return @pitches > 1 ? @pitches : $pitches[0];
  }

  sub _symbol2relreg {
    my ($symbol) = @_;
    $symbol ||= q{};

    # no leap, within three stave lines of previous note
    return 0 if length $symbol == 0;

    die "invalid register symbol $symbol\n"
      if $symbol !~ m/^(([,'])\g{-1}*)$/;

    my $count = length $1;
    $count *= $2 eq q{'} ? 1 : -1;

    return $count;
  }

}

########################################################################
#
# pitch numbers to lilypond notes

{
  my $prev_pitch;

  sub clear_prev_pitch {
    my ($self) = @_;
    undef $prev_pitch;
  }

  sub prev_pitch {
    my ( $self, $pitch ) = @_;
    if ( defined $pitch ) {
      if ( blessed $pitch and $pitch->can("pitch") ) {
        $prev_pitch = $pitch->pitch;
      } elsif ( looks_like_number $pitch ) {
        $prev_pitch = $pitch;
      } else {
        croak("unknown pitch '$pitch'");
      }
    }
    return $prev_pitch;
  }

  # Converts pitches to lilypond names
  sub p2ly {
    my $self = shift;

    my @notes;
    for my $obj (@_) {
      my $pitch;
      if ( !defined $obj ) {
        croak "cannot convert undefined value to lilypond element\n";
      } elsif ( blessed $obj and $obj->can("pitch") ) {
        $pitch = $obj->pitch;
      } elsif ( looks_like_number $obj) {
        $pitch = $obj;
      } else {
        # pass through on unknowns (could be rests or who knows what)
        push @notes, $obj;
        next;
      }

      if ( $pitch < $self->{_min_pitch} or $pitch > $self->{_max_pitch} ) {
        croak "pitch $pitch is out of range\n";
      }

      my $note = $self->{_p2n_hook}( $pitch, $self->{_chrome} );
      croak "could not lookup note for pitch '$pitch'" unless defined $note;

      my $register;
      if ( $self->{_mode} ne 'relative' ) {
        $register = $REGISTERS{ int $pitch / $DEG_IN_SCALE };

      } else {    # relatively more complicated
        my $rel_reg = $REL_DEF_REG;
        if ( defined $prev_pitch ) {
          my $delta = int( $pitch - $prev_pitch );
          if ( abs($delta) >= $TRITONE ) {    # leaps need , or ' variously
            if ( $delta % $DEG_IN_SCALE == $TRITONE ) {
              $rel_reg += int( $delta / $DEG_IN_SCALE );

              # Adjust for tricky changing tritone default direction
              my $default_dir =
                $TTDIR{ $self->{_chrome} }->{ $prev_pitch % $DEG_IN_SCALE };
              if ( $delta > 0 and $default_dir < 0 ) {
                $rel_reg++;
              } elsif ( $delta < 0 and $default_dir > 0 ) {
                $rel_reg--;
              }

            } else {    # not tritone, but leap
                        # TT adjust is to push <1 leaps out so become 1
              $rel_reg +=
                int( ( $delta + ( $delta > 0 ? $TRITONE : -$TRITONE ) ) /
                  $DEG_IN_SCALE );
            }
          }
        }
        $register = $REGISTERS{$rel_reg};
        $prev_pitch = $pitch if $self->{_keep_state};
      }

      # Do not care about register (even in absolute mode) if keeping state
      if ( $self->{_keep_state} ) {
        croak "register out of range for pitch '$pitch'"
          unless defined $register;
      } else {
        $register = '';
      }
      push @notes, $note . $register;
    }

    undef $prev_pitch unless $self->{_sticky_state};
    return @_ > 1 ? @notes : $notes[0];
  }
}

sub sticky_state {
  my ( $self, $state ) = @_;
  $self->{_sticky_state} = $state if defined $state;
  return $self->{_sticky_state};
}

sub strip_rests {
  my ( $self, $state ) = @_;
  $self->{_strip_rests} = $state if defined $state;
  return $self->{_strip_rests};
}

1;
__END__

=head1 NAME

Music::LilyPondUtil - utility methods for lilypond data

=head1 SYNOPSIS

  use Music::LilyPondUtil;
  my $lyu   = Music::LilyPondUtil->new;

  my $pitch = $lyu->notes2pitches("c'") # 60
  $lyu->diatonic_pitch("ces'")          # 60

  $lyu->ignore_register(1);
  $lyu->notes2pitches("c'")             # 0
  $lyu->diatonic_pitch("ces'")          # 0


  my $note  = $lyu->p2ly(60)            # c'

  $lyu->mode('relative');
  my @bach  = $lyu->p2ly(qw/60 62 64 65 62 64 60 67 72 71 72 74/)
      # c d e f d e c g' c b c d

  $lyu->keep_state(0);
  $lyu->p2ly(qw/0 1023 79 77 -384/);   # c dis g f c

  $lyu->chrome('flats');
  $lyu->p2ly(qw/2 9 5 2 1 2/);         # d a f d des d

=head1 DESCRIPTION

Utility methods for interacting with lilypond (as of version 2.16), most
notably for the conversion of random integers to lilypond note names
(there, and back again). The Western 12-tone system is assumed.

The note conversions parse the lilypond defaults, including enharmonic
equivalents such as C<bes> or C<ceses> (for C double flat or more simply
B flat) and C<bis> (B sharp or C natural) but not any microtonal C<cih>,
C<beh> nor any other conventions. Lilypond output is restricted to all
sharps or all flats (set via a parameter), and never emits double sharps
nor double flats. Pitch numbers are integers, and might be the MIDI note
numbers, or based around 0, or whatever, depending on the need and the
parameters set.

=head1 METHODS

The module will throw errors via B<croak> if an abnormal condition is
encountered.

=over 4

=item B<new> I<optional params>

Constructor. Optional parameters include:

=over 4

=item *

B<chrome> to set the accidental style (C<sharps> or C<flats>). Mixing
flats and sharps is not supported. (Under no circumstances are double
sharps or double flats emitted, though the module does know how to
read those.)

=item *

B<ignore_register> a boolean that if set causes the B<diatonic_pitch>
and B<notes2pitches> methods to only return values from 0..11. The
default is to include the register information in the resulting pitch.
Set this option if feeding data to atonal routines, for example those in
L<Music::AtonalUtil>.

=item *

B<keep_state> a boolean, enabled by default, that will maintain state on
the previous pitch in the B<p2ly> call. State is not maintained across
separate calls to B<p2ly> (see also the B<sticky_state> param).

Disabling this option will remove all register notation from both
C<relative> and C<absolute> modes.

=item *

B<min_pitch> integer, by default 0, below which pitches passed to
B<diatonic_pitch> or B<p2ly> will cause the module to throw an
exception. To constrain pitches to what an 88-key piano is
capable of, set:

  Music::LilyPondUtil->new( min_pitch => 21 );

Too much existing code allows for zero as a minimum pitch to set 21 by
default, or if B<ignore_register> is set, pitches from B<notes2pitches>
are constrained to zero through eleven, and relative lilypond notes can
easily be generated from those...so 0 is the minimum.

=item *

B<max_pitch> integer, by default 108 (the highest note on a standard 88-
key piano), above which pitches passed to B<diatonic_pitch> or B<p2ly>
will cause the module to throw an exception.

=item *

B<mode> to set C<absolute> or C<relative> mode. Default is C<absolute>.
Altering this changes how both B<notes2pitches> and B<p2ly> operate.
Create two instances of the object if this is a problem, and set the
appropriate mode for the appropriate routine.

=item *

B<p2n_hook> to set a custom code reference for the pitch to note
conversion (see source for details, untested, use at own risk, blah
blah blah).

=item *

B<sticky_state> a boolean, disabled by default, that if enabled,
will maintain the previous pitch state across separate calls to
B<p2ly>, assuming B<keep_state> is also enabled, and again only in
C<relative> B<mode>.

=item *

B<strip_rests> boolean that informs B<notes2pitches> as to whether rests
should be omitted. By default, rests are returned as undefined values.

(Canon or fugue related calculations, in particular, need the rests, as
otherwise the wrong notes line up with one another in the comparative
lists. An alternative approach would be to convert notes to start
times and durations (among other metadata), and ignore rests, but that
would take more work to implement. It would, however, better suit
larger data sets.)

=back

=item B<chrome> I<optional sharps or flats>

Get/set accidental style.

=item B<clear_prev_note>

For use with B<notes2pitches>. Wipes out the previous note (the state
variable used with B<sticky_state> enabled in C<relative> B<mode> to
maintain state across multiple calls to B<notes2pitches>.

=item B<clear_prev_pitch>

For use with B<p2ly>. Wipes out the previous pitch (the state variable
used with B<sticky_state> enabled in C<relative> B<mode> to maintain
state across multiple calls to B<p2ly>). Be sure to call this method
after completing any standalone chord or phrase, as otherwise any
subsequent B<p2ly> calls will use the previously cached pitch.

=item B<diatonic_pitch> I<note>

Returns the diatonic (here defined as the white notes on the piano)
pitch number for a given lilypond absolute notation note, for example
C<ceses'>, C<ces'>, C<c'>, C<cis'>, and C<cisis'> all return 60. This
method is influenced by the B<ignore_register>, B<min_pitch>, and
B<max_pitch> parameters.

=item B<ignore_register> I<optional boolean>

Get/set B<ignore_register> param.

=item B<keep_state> I<optional boolean>

Get/set B<keep_state> param.

=item B<mode> I<optional relative or absolute>

Get/set the mode of operation.

=item B<notes2pitches> I<list of note names or pitch numbers>

Converts note names to pitches. Raw pitch numbers (integers) are passed
through as is. Lilypond non-note C<r> or C<s> in any case are converted
to undefined values (likewise for notes adorned with C<\rest>).
Otherwise, lilypond note names (C<c>, C<cis>, etc.) and registers
(C<'>, C<''>, etc.) are converted to a pitch number. The
B<ignore_register> and B<strip_rests> options can influence the output.
Use the B<prev_note> method to set what a C<\relative d'' { ...>
statement in lilypond would do:

  $lyu->prev_note(q{d''});
  $lyu->notes2pitches(qw/d g fis g a g fis e/);

Returns list of pitches (integers), or single pitch as scalar if only a
single pitch was input.

=item B<p2ly> I<list of pitches or whatnot>

Converts a list of pitches (integers or objects that have a B<pitch>
method that returns an integer) to a list of lilypond note names.
Unknown data will be passed through as is. Returns said converted list.
The behavior of this method depends heavily on various parameters that
can be passed to B<new> or called as various methods.

=item B<prev_note> I<optional note>

For use with B<notes2pitches>. Get/set previous note (the state variable
used with B<sticky_state> enabled in C<relative> B<mode> to maintain
state across multiple calls to B<p2ly>). Optionally accepts only a note
(for example, C<ces,> or C<f''>), and always returns the current
previous note (which may be unset), which will be the pitch of the
diatonic of the note provided (e.g. C<ces,> will return the pitch for
C<c,>, and C<fisfis'''> the pitch for C<f'''>).

=item B<prev_pitch> I<optional pitch>

For use with B<p2ly>. Get/set previous pitch (the state variable used
with B<sticky_state> enabled in C<relative> B<mode> to maintain state
across multiple calls to B<p2ly>).

=item B<sticky_state> I<optional boolean>

Get/set B<sticky_state> param.

=item B<strip_rests> I<optional boolean>

Get/set B<strip_rests> param.

=back

=head1 SEE ALSO

=over 4

=item *

http://www.lilypond.org/ and most notably the Learning and
Notation manuals.

=item *

L<App::MusicTools> whose command line tools make use of this module.

=back

=head1 AUTHOR

Jeremy Mates, E<lt>jmates@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Jeremy Mates

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.16 or, at
your option, any later version of Perl 5 you may have available.

=cut
