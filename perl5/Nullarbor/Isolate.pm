package Nullarbor::Isolate;
use Moo;

#.................................................................................

has id => (
  is => 'ro',
);

has reads => (
  is => 'ro',
  isa => sub { ref $_[0] eq 'ARRAY' or die "reads() needs an arrayref"; },
);

has folder => (
  is => 'rw',
);

sub paired {
  my $self = shift;
  return @{ $self->reads } > 1;
}

sub print {
  my($self, $fh) = @_;
  $fh ||= \*STDOUT;
  print $fh join("\t", $self->id, @{$self->reads}),"\n";
}

#.................................................................................

1;

