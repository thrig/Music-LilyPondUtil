use strict;
use warnings;

use Test::More tests => 19;
BEGIN { use_ok('Music::LilyPondUtil') }

my $lyu = Music::LilyPondUtil->new;
isa_ok( $lyu, 'Music::LilyPondUtil' );

########################################################################
#
# absolute mode (default)

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
# relative, sharps

$lyu->mode('relative');
$lyu->chrome('sharps');

is_deeply( [ $lyu->p2ly(qw{0 2 4 5 7 9 11 12}) ],
  [qw{c d e f g a b c}], q{relative octave run} );

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
# relative, flats

$lyu->chrome('flats');

# If using flats, must leap up to the tritone (c up to g(flat))
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

# TODO test 'mode', 'chrome' param to new call
#$lyu = Music::LilyPondUtil->new();
#isa_ok( $lyu, 'Music::LilyPondUtil' );
