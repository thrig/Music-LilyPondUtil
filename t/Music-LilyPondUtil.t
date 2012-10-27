use strict;
use warnings;

use Test::More tests => 39;
BEGIN { use_ok('Music::LilyPondUtil') }

my $lyu = Music::LilyPondUtil->new;
isa_ok( $lyu, 'Music::LilyPondUtil' );

is( $lyu->notes2pitches("c"), 0, 'convert c to pitch' );
is_deeply( [ $lyu->notes2pitches(qw/c d e f/) ],
  [qw/0 2 4 5/], 'convert bunch of notes to pitches' );

########################################################################
#
# p2ly - absolute mode (default)

is( $lyu->p2ly(60), q{c'},  q{absolute 60 -> c'} );
is( $lyu->p2ly(59), q{b},   q{absolute 59 -> b} );
is( $lyu->p2ly(45), q{a,},  q{absolute 45 -> a,} );
is( $lyu->p2ly(74), q{d''}, q{absolute 74 -> d''} );

is( $lyu->p2ly(61), q{cis'}, q{absolute default chrome 61 -> cis'} );
$lyu->chrome('flats');
is( $lyu->p2ly(61), q{des'}, q{absolute flat chrome 61 -> des'} );
$lyu->chrome('sharps');
is( $lyu->p2ly(61), q{cis'}, q{absolute sharp chrome 61 -> cis'} );

is_deeply(
  [ $lyu->p2ly(qw{60 74 45}) ],
  [ "c'", "d''", "a," ],
  q{absolute various leaps}
);

########################################################################
#
# p2ly - relative, sharps

is( $lyu->mode('relative'), 'relative', 'switch to relative' );
is( $lyu->chrome('sharps'), 'sharps',   'switch to sharps' );

is_deeply( [ $lyu->p2ly(qw{0 2 4 5 7 9 11 12}) ],
  [qw{c d e f g a b c}], q{relative octave run} );

# tritones are tricky in relative mode
is_deeply(
  [ $lyu->p2ly(
      qw{59 53 59 60 66 60 61 55 61 62 68 62 63 57 63 64 70 64 65 71 65 66 60 66 67 73 67 68 62 68 69 75 69 70 64 70}
    )
  ],
  [ split ' ',
    q{b f b c fis c cis g cis d gis d dis a dis e ais e f b f fis c fis g cis g gis d gis a dis a ais e ais}
  ],
  'relative sharps tritone no leap'
);

is_deeply(
  [ $lyu->p2ly(
      qw{59 65 59 60 54 60 61 67 61 62 56 62 63 69 63 64 58 64 65 59 65 66 72 66 67 61 67 68 74 68 69 63 69 70 76 70}
    )
  ],
  [ split ' ',
    q{b f' b, c fis, c' cis g' cis, d gis, d' dis a' dis, e ais, e' f b, f' fis c' fis, g cis, g' gis d' gis, a dis, a' ais e' ais,}
  ],
  'relative sharps tritone leap'
);

is_deeply(
  [ $lyu->p2ly(
      qw{60 62 60 65 60 66 60 67 60 69 60 78 60 79 60 62 67 62 68 62 69 62 80 62 81 62}
    )
  ],
  [ split ' ',
    q{c d c f c fis c g' c, a' c, fis' c, g'' c,, d g d gis d a' d, gis' d, a'' d,,}
  ],
  q{relative sharps positive}
);

# As before, just transposed the pitches down to ensure negative numbers
# processed the same (sometimes the pitch "0" means "middle c or
# something" below which the notes can wander).
is_deeply(
  [ $lyu->p2ly(
      qw{-12 -10 -12 -7 -12 -6 -12 -5 -12 -3 -12 6 -12 7 -12 -10 -5 -10 -4 -10 -3 -10 8 -10 9 -10}
    )
  ],
  [ split ' ',
    q{c d c f c fis c g' c, a' c, fis' c, g'' c,, d g d gis d a' d, gis' d, a'' d,,}
  ],
  q{relative sharps negative}
);

is_deeply(
  [ $lyu->p2ly(qw{60 54 60 55 60 62 56 62}) ],
  [ split ' ', q{c fis, c' g c d gis, d'} ],
  q{relative sharps positive downwards}
);

is_deeply(
  [ $lyu->p2ly(qw{-12 -18 -12 -17 -12 -10 -16 -10}) ],
  [ split ' ', q{c fis, c' g c d gis, d'} ],
  q{relative sharps negative downwards}
);

########################################################################
#
# p2ly - relative, flats

is( $lyu->chrome('flats'), 'flats', 'switch to flats' );

# tritones are tricky in relative mode
is_deeply(
  [ $lyu->p2ly(
      qw{59 53 59 60 54 60 61 67 61 62 56 62 63 69 63 64 58 64 65 71 65 66 72 66 67 61 67 68 74 68 69 63 69 70 76 70}
    )
  ],
  [ split ' ',
    q{b f b c ges c des g des d aes d ees a ees e bes e f b f ges c ges g des g aes d aes a ees a bes e bes}
  ],
  'relative sharps tritone no leap'
);

is_deeply(
  [ $lyu->p2ly(
      qw{59 65 59 60 66 60 61 55 61 62 68 62 63 57 63 64 70 64 65 59 65 66 60 66 67 73 67 68 62 68 69 75 69 70 64 70}
    )
  ],
  [ split ' ',
    q{b f' b, c ges' c, des g, des' d aes' d, ees a, ees' e bes' e, f b, f' ges c, ges' g des' g, aes d, aes' a ees' a, bes e, bes'}
  ],
  'relative sharps tritone leap'
);

is_deeply(
  [ $lyu->p2ly(
      qw{60 62 60 65 60 66 60 67 60 69 60 78 60 79 60 62 67 62 68 62 69 62 80 62 81 62}
    )
  ],
  [ split ' ',
    q{c d c f c ges' c, g' c, a' c, ges'' c,, g'' c,, d g d aes' d, a' d, aes'' d,, a'' d,,}
  ],
  q{relative flats positive}
);

is_deeply(
  [ $lyu->p2ly(
      qw{-24 -22 -24 -19 -24 -18 -24 -17 -24 -15 -24 -6 -24 -5 -24 -22 -17 -22 -16 -22 -15 -22 -4 -22 -3 -22}
    )
  ],
  [ split ' ',
    q{c d c f c ges' c, g' c, a' c, ges'' c,, g'' c,, d g d aes' d, a' d, aes'' d,, a'' d,,}
  ],
  q{relative flats negative}
);

is_deeply(
  [ $lyu->p2ly(qw{60 54 60 42 60 62 56 62 44 62}) ],
  [ split ' ', q{c ges c ges, c' d aes d aes, d'} ],
  q{relative flats positive downwards}
);

is_deeply(
  [ $lyu->p2ly(qw{-12 -18 -12 -30 -12 -10 -16 -10 -28 -10}) ],
  [ split ' ', q{c ges c ges, c' d aes d aes, d'} ],
  q{relative flats negative downwards}
);

########################################################################
#
# Various new() params

$lyu = Music::LilyPondUtil->new( mode => 'relative' );
is( $lyu->mode, 'relative' );

$lyu = Music::LilyPondUtil->new( chrome => 'flats' );
is( $lyu->chrome, 'flats' );

$lyu = Music::LilyPondUtil->new( keep_state => 0 );
ok( !$lyu->keep_state, 'keep_state is disabled' );

is_deeply( [ $lyu->p2ly(qw/0 12 24 36/) ],
  [qw/c c c c/], q{state disabled should nix registers relative} );

$lyu->mode('absolute');
is_deeply( [ $lyu->p2ly(qw/0 12 24 36/) ],
  [qw/c c c c/], q{state disabled should nix registers absolute} );

$lyu->keep_state(1);
ok( $lyu->keep_state, 'keep_state is enabled' );

$lyu = Music::LilyPondUtil->new( sticky_state => 1 );
ok( $lyu->sticky_state, 'sticky_state is enabled' );

$lyu->mode('relative');
my @notes = $lyu->p2ly(0);
for my $i ( 0 .. 2 ) {
  push @notes, $lyu->p2ly( 12 + $i * 12 );
}
is_deeply(
  \@notes,
  [ split ' ', "c c' c' c'" ],
  'sticky state across p2ly calls'
);

is( $lyu->prev_pitch, 36, 'previous sticky pitch' );
$lyu->clear_prev_pitch;
ok( !defined $lyu->prev_pitch, 'previous pitch cleared' );

$lyu->sticky_state(0);
ok( !$lyu->sticky_state, 'sticky_state is disabled' );
