use 5.010000;
use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'Music::LilyPondUtil',
  VERSION_FROM => 'lib/Music/LilyPondUtil.pm',
  LICENSE      => 'perl',
  PREREQ_PM    => {
    Carp         => 0,
    Scalar::Util => 0,
    Test::More   => 0,
  },
  ( $] >= 5.005
    ? (
      ABSTRACT_FROM => 'lib/Music/LilyPondUtil.pm',
      AUTHOR        => 'Jeremy Mates <jmates@cpan.org>'
      )
    : ()
  ),
);
