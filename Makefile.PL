use 5.010000;

use strict;
use warnings;
use ExtUtils::MakeMaker;

my %params = (
  NAME         => 'Music::LilyPondUtil',
  VERSION_FROM => 'lib/Music/LilyPondUtil.pm',
  PREREQ_PM    => {
    Carp              => 0,
    'Scalar::Util'    => 0,
    'Test::Exception' => 0,
    'Test::More'      => 0,
    'Try::Tiny'       => 0,
  },
  ( $] >= 5.005
    ? (
      ABSTRACT_FROM => 'lib/Music/LilyPondUtil.pm',
      AUTHOR        => 'Jeremy Mates <jmates@cpan.org>'
      )
    : ()
  ),
);

if ( $ExtUtils::MakeMaker::VERSION =~ /^\d\.\d\d$/ and $ExtUtils::MakeMaker::VERSION > 6.30 ) {
  $params{LICENSE} = 'perl';
}

if ( $ExtUtils::MakeMaker::VERSION ge '6.46' ) {
  $params{META_MERGE} = {
    resources => {
      homepage   => 'https://github.com/thrig/Music-LilyPondUtil',
      license    => 'http://dev.perl.org/licenses/',
      repository => 'https://github.com/thrig/Music-LilyPondUtil',
    }
  };
}

WriteMakefile(%params);
