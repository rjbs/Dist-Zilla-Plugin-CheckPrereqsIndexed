use strict;
use warnings;
use Test::More 0.88;
use Test::Fatal;

use lib 't/lib';

use Test::DZil;

sub new_tzil {
  my ($corpus_dir) = @_;
  my $tzil = Builder->from_config(
    { dist_root => $corpus_dir },
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
  my $tzil = new_tzil('corpus/DZT');

  my $err = exception { $tzil->release };

  like($err, qr/unindexed prereq/, "we aborted because we had weird prereqs");
  ok(
    (grep { /Zorch/ } @{ $tzil->log_messages }),
    "and we specifically mentioned the one we expected",
  );
}

{
  my $tzil = new_tzil('corpus/DZZ');

  my $err = exception { $tzil->release };

  is($err, undef, "we released with no errors");
}

done_testing;
