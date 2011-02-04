package Dist::Zilla::Plugin::CheckPrereqsIndexed;
use Moose;

with 'Dist::Zilla::Role::BeforeRelease';

use List::MoreUtils qw(uniq);

use namespace::autoclean;

sub before_release {
  my ($self) = @_;

  my $prereqs  = $self->zilla->prereqs->as_string_hash;

  my @packages = sort { $a cmp $b } uniq
                 map {; keys %$_ }
                 map {; values %$_ }
                 values %$prereqs;

  # get names of all packages in any kind of requirement
  # look up each requirement in 02packages or cpandb or something
  # make a list of requirements that aren't found
  # if the list is empty, return
  # otherwise, prompt: abort or continue
  $self->log("@packages");
}

1;
