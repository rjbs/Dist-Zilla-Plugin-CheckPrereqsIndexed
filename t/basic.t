use strict;
use warnings;
use Test::More 0.88;
use Test::Fatal;

use lib 't/lib';

use Test::DZil;

sub new_tzil {
  my $tzil = Builder->from_config(
    { dist_root => 'corpus/DZT' },
    {
      add_files => {
        'source/dist.ini' => simple_ini(
          qw(GatherDir AutoPrereqs CheckPrereqsIndexed FakeRelease)
        ),
      },
    },
  );
}

{
  my $tzil = new_tzil;

  $tzil->release;

  diag $_ for @{ $tzil->log_messages };
}

done_testing;
