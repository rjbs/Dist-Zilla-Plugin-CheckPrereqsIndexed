package Dist::Zilla::Plugin::CheckPrereqsIndexed;
use Moose;

with 'Dist::Zilla::Role::BeforeRelease';

use List::MoreUtils qw(uniq);
use LWP::UserAgent;

use namespace::autoclean;

sub before_release {
  my ($self) = @_;

  my $prereqs  = $self->zilla->prereqs->as_string_hash;

  my @packages = sort { $a cmp $b } uniq
                 map {; keys %$_ }
                 map {; values %$_ }
                 values %$prereqs;

  return unless @packages; # no prereqs!?

  my $ua = LWP::UserAgent->new(keep_alive => 1);

  my %missing;

  for my $pkg (@packages) {
    my $res = $ua->get("http://cpanmetadb.appspot.com/v1.0/package/$pkg");
    $missing{ $pkg } = 1 unless $res->is_success;
  }

  unless (keys %missing) {
    $self->log("all prereqs appear to be indexed");
    return;
  }

  my @missing = sort keys %missing;

  $self->log("the following prereqs could not be found on CPAN: @missing");
  return if $self->zilla->chrome->prompt_yn(
    "release despite missing prereqs?",
    { default => 0 }
  );

  $self->log_fatal("aborting release due to apparently unindexed prereqs");
}

1;
