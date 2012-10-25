# http://www.lilypond.org/

package Music::LilyPondUtil;

use 5.010000;
use strict;
use warnings;
use Carp qw(croak);
use Scalar::Util qw(blessed looks_like_number);

our $VERSION = '0.01';

my $DEG_IN_SCALE = 12;
my %REGISTERS    = (
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
my $REL_DEF_REG = 4;
my %P2N         = (
  'sharps' =>
    {qw/0 c 1 cis 2 d 3 dis 4 e 5 f 6 fis 7 g 8 gis 9 a 10 ais 11 b/},
  'flats' =>
    {qw/0 c 1 des 2 d 3 ees 4 e 5 f 6 ges 7 g 8 aes 9 a 10 bes 11 b/},
);

########################################################################
#
# SUBROUTINES

sub new {
  my ( $class, %param ) = @_;
  my $self = {};

  $self->{_mode} = $param{MODE} || 'absolute';
  croak("mode must be 'absolute' or 'relative'")
    if $self->{_mode} ne 'absolute' and $self->{_mode} ne 'relative';

  $self->{_chrome} = $param{CHROME} || 'sharps';
  croak("unknown CHROME conversion style")
    unless exists $P2N{ $self->{_chrome} };

  $self->{_p2n_hook} = $param{P2N_HOOK}
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
        if ( $delta % 6 == 0 ) {
          if ( $self->{_chrome} =~ m/(?i)flat/ ) {
            $delta += $delta > 0 ? 1 : -1;
          } else {
            $delta += $delta > 0 ? -1 : 1;
          }
        }
        if ( abs($delta) > 6 ) {
          $rel_reg += int( ( $delta - 6 ) / $DEG_IN_SCALE );
          $rel_reg++ if $delta > 0;
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
