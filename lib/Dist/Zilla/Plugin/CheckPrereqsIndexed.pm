package Dist::Zilla::Plugin::CheckPrereqsIndexed;
use Moose;
# ABSTRACT: prevent a release if you have prereqs not found on CPAN

=head1 OVERVIEW

Sometimes, AutoPrereqs is a little overzealous and finds a prereq that you
wrote inline or have in your F<./t> directory.  Although AutoPrereqs should
grow more accurate over time, and avoid these mistakes, it's not perfect right
now.  CheckPrereqsIndexed will check every required package against the CPAN
index to ensure that they're all real, installable packages.

If any are unknown, it will prompt the user to continue or abort.

At present, CheckPrereqsIndexed queries CPANMetaDB, but this behavior is likely
to change or become pluggable in the future.  In the meantime, this makes
releasing while offline impossible... but it was anyway, right?

=cut

with 'Dist::Zilla::Role::BeforeRelease';

use List::MoreUtils qw(uniq);
use LWP::UserAgent;

use namespace::autoclean;

sub before_release {
  my ($self) = @_;

  my $prereqs  = $self->zilla->prereqs->as_string_hash;

  my @packages = sort { $a cmp $b } uniq
                 grep { $_ ne 'Config' } # special case -- rjbs, 2011-05-20
                 grep { $_ ne 'perl' } # special case -- rjbs, 2011-02-05
                 map  {; keys %$_ }
                 map  {; values %$_ }
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
