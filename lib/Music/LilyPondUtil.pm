# http://www.lilypond.org/ related utility code (mostly to
# transition between Perl processing integers and the related
# appropriate letter names for the black dots in lilypond).

package Music::LilyPondUtil;

use 5.010000;
use strict;
use warnings;
use Carp qw(croak);
use Scalar::Util qw(blessed looks_like_number);

our $VERSION = '0.01';

# Since dealing with lilypond, assume 12 pitch material
my $DEG_IN_SCALE = 12;
my $TRITONE      = 6;
# this used by both absoluate and relative mode
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
# mixing flats and sharps not supported, either one or other right now
my %P2N = (
  flats  => {qw/0 c 1 des 2 d 3 ees 4 e 5 f 6 ges 7 g 8 aes 9 a 10 bes 11 b/},
  sharps => {qw/0 c 1 cis 2 d 3 dis 4 e 5 f 6 fis 7 g 8 gis 9 a 10 ais 11 b/},
);
# Diabolus in Musica, indeed
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

  $self->{_mode} = $param{mode} || 'absolute';
  croak("mode must be 'absolute' or 'relative'")
    if $self->{_mode} ne 'absolute' and $self->{_mode} ne 'relative';

  $self->{_chrome} = $param{chrome} || 'sharps';
  croak("unknown CHROME conversion style")
    unless exists $P2N{ $self->{_chrome} };

  $self->{_p2n_hook} = $param{p2n_hook}
    || sub { $P2N{ $_[1] }->{ $_[0] % $DEG_IN_SCALE } };
  croak("P2N_HOOK must be code ref") unless ref $self->{_p2n_hook} eq 'CODE';

  bless $self, $class;
  return $self;
}

sub chrome {
  my ( $self, $chrome ) = @_;
  if ( defined $chrome ) {
    croak("unknown CHROME conversion style") unless exists $P2N{$chrome};
    $self->{_chrome} = $chrome;
  }
  return $self->{_chrome};
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

sub p2ly {
  my $self = shift;

  my ( @notes, $prev_pitch );
  for my $obj (@_) {
    my $pitch;
    if ( blessed $obj and $obj->can("pitch") ) {
      $pitch = $obj->pitch;
    } elsif ( looks_like_number $obj) {
      $pitch = $obj;
    } else {
      # pass through on unknowns (could be rests or who knows what)
      push @notes, $obj;
      next;
    }

    my $note = $self->{_p2n_hook}( $pitch, $self->{_chrome} );
    croak "could not lookup note for pitch '$pitch'" unless defined $note;

    my $register;
    if ( $self->{_mode} ne 'relative' ) {
      $register = $REGISTERS{ int $pitch / $DEG_IN_SCALE };
    } else {
      my $rel_reg = $REL_DEF_REG;
      if ( defined $prev_pitch ) {
        my $delta = $pitch - $prev_pitch;
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
      $register   = $REGISTERS{$rel_reg};
      $prev_pitch = $pitch;
    }
    croak "register out of range for pitch '$pitch'" unless defined $register;

    push @notes, $note . $register;
  }

  return @_ > 1 ? @notes : $notes[0];
}

1;
__END__

=head1 NAME

Music::LilyPondUtil - utility methods for lilypond data

=head1 SYNOPSIS

  use Music::LilyPondUtil;
  my $lyu Music::LilyPondUtil->new;

  $lyu->p2ly(60)  # c'

=head1 DESCRIPTION

Utility methods for interacting with lilypond.

=head1 METHODS

The module will throw errors via B<croak> if an abnormal condition is
encountered.

=over 4

=item B<new> I<optional params>

Constructor. Optional parameters are B<mode> to set C<absolute> or
C<relative> mode, B<chrome> to set the accidental style (C<sharps> or
C<flats), and B<p2n_hook> to set a custom code reference for the pitch
to note conversion (untested, see source for details).

=item B<chrome> I<optional sharps or flats>

Get/set accidental style.

=item B<mode> I<optional relative or absolute>

Get/set the mode of operation.

=item B<p2ly> I<list of pitches or whatnot>

Converts a list of pitches (integers or objects that have a B<pitch>
method that returns an integer) to a list of lilypond note names.
Unknown data will be passed through as is.

=back

=head1 SEE ALSO

http://www.lilypond.org/

=head1 AUTHOR

Jeremy Mates, E<lt>jmates@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Jeremy Mates

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.16.1 or, at
your option, any later version of Perl 5 you may have available.

=cut
