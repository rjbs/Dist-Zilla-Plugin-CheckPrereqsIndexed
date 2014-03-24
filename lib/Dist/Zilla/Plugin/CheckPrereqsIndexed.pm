package Dist::Zilla::Plugin::CheckPrereqsIndexed;
use Moose;
# ABSTRACT: prevent a release if you have prereqs not found on CPAN

use 5.10.0; # //

=head1 OVERVIEW

Sometimes, AutoPrereqs is a little overzealous and finds a prereq that you
wrote inline or have in your F<./t> directory.  Although AutoPrereqs should
grow more accurate over time, and avoid these mistakes, it's not perfect right
now.  CheckPrereqsIndexed will check every required package against the CPAN
index to ensure that they're all real, installable packages.

If any are unknown, it will prompt the user to continue or abort.

At present, CheckPrereqsIndexed queries CPANIDX, but this behavior is likely to
change or become pluggable in the future.  In the meantime, this makes
releasing while offline impossible... but it was anyway, right?

=cut

with 'Dist::Zilla::Role::BeforeRelease';

use List::MoreUtils qw(any uniq);

use namespace::autoclean;

sub mvp_multivalue_args { qw(skips) }
sub mvp_aliases { return { skip => 'skips' } }

=attr skips

This is an arrayref of regular expressions.  Any module names matching
any of these regex will not be checked.  This should only be necessary
if you have a prerequisite that is not available on CPAN (because it's
distributed in some other way).

=cut

has skips => (
  is      => 'ro',
  isa     => 'ArrayRef[Str]',
  default => sub { [] },
);

sub before_release {
  my ($self) = @_;

  require version;

  my $prereqs_hash  = $self->zilla->prereqs->as_string_hash;

  my @skips = map {; qr/$_/ } @{ $self->skips };

  my %requirement;

  # first level keys are phase; second level keys are types; we will just merge
  # everything -- rjbs, 2011-08-18
  for my $req_set (map { values %$_ } values %$prereqs_hash) {
    REQ_PKG: for my $pkg (keys %$req_set) {
      next if $pkg eq 'Config'; # special case -- rjbs, 2011-05-20
      next if $pkg eq 'perl';   # special case -- rjbs, 2011-02-05

      next if any { $pkg =~ $_ } @skips;

      my $ver = $req_set->{$pkg};

      $requirement{ $pkg } //= version->parse(0);

      # we have a complex requirement or awful version -- rjbs, 2014-03-23
      next REQ_PKG if not version::is_lax($ver);

      $requirement{ $pkg } = $ver
        if version->parse($ver) > $requirement{ $pkg };
    }
  }

  return unless keys %requirement; # no prereqs!?

  require Encode;
  require LWP::UserAgent;
  require JSON;

  my $ua = LWP::UserAgent->new(keep_alive => 1);
  $ua->env_proxy;

  my %missing;
  my %too_new;

  PKG: for my $pkg (sort keys %requirement) {
    my $res = $ua->get("http://cpanidx.org/cpanidx/json/mod/$pkg");
    unless ($res->is_success) {
      $missing{ $pkg } = 1;
      next PKG;
    }

    # JSON wants UTF-8 bytestreams, so we need to re-encode no matter what
    # encoding we got. -- rjbs, 2011-08-18
    my $yaml_octets = Encode::encode_utf8($res->decoded_content);
    my $payload = JSON::->new->decode($yaml_octets);

    unless (@$payload) {
      $missing{ $pkg } = 1;
      next PKG;
    }

    my $indexed_version = version->parse($payload->[0]{mod_vers});
    next PKG if $indexed_version >= $requirement{ $pkg };

    $too_new{ $pkg } = {
      required => $requirement{ $pkg },
      indexed  => $indexed_version,
    };
  }

  unless (keys %missing or keys %too_new) {
    $self->log("all prereqs appear to be indexed");
    return;
  }

  if (keys %missing) {
    my @missing = sort keys %missing;
    $self->log("the following prereqs could not be found on CPAN: @missing");
  }

  if (keys %too_new) {
    for my $pkg (sort keys %too_new) {
      $self->log([
        "you required %s version %s but CPAN only has version %s",
        $pkg,
        "$too_new{$pkg}{required}",
        "$too_new{$pkg}{indexed}",
      ]);
    }
  }

  return if $self->zilla->chrome->prompt_yn(
    "release despite missing prereqs?",
    { default => 0 }
  );

  $self->log_fatal("aborting release due to apparently unindexed prereqs");
}

1;
