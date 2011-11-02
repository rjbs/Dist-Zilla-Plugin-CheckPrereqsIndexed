use strict;
use warnings;
use Test::More 0.88;
use Test::Fatal;

use lib 't/lib';

use Test::DZil;

sub new_tzil {
  my ($corpus_dir, @skips) = @_;
  my $tzil = Builder->from_config(
    { dist_root => $corpus_dir },
    {
      add_files => {
        'source/dist.ini' => simple_ini(
          qw(GatherDir AutoPrereqs FakeRelease),
          [ CheckPrereqsIndexed => (@skips ? { skips => \@skips } : ()) ],
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
  my $tzil = Builder->from_config(
    { dist_root => 'corpus/DZZ' },
    {
      add_files => {
        'source/dist.ini' => simple_ini(
          qw(GatherDir AutoPrereqs CheckPrereqsIndexed FakeRelease),
          [ Prereqs => { 'Dist::Zilla' => 99 } ],
        ),
      },
    },
  );

  my $err = exception { $tzil->release };

  like($err, qr/unindexed prereq/, "we aborted because we had weird prereqs");

  ok(
    (grep { /you required Dist::Zilla version 99/ } @{ $tzil->log_messages }),
    "it complained that we wanted a too-new version",
  );
}

{
  # This is to test that we don't have any problems with libraries that are in
  # our own dist.
  my $tzil = new_tzil('corpus/DZZ');

  my $err = exception { $tzil->release };

  is($err, undef, "we released with no errors");
}

{
  my $tzil = new_tzil('corpus/DZT', '^Zorch::');

  my $err = exception { $tzil->release };

  is($err, undef, "skipping Zorch:: allows release");
}

done_testing;
