package Nullarbor::IsolateSet;
use Moo;
use Cwd qw(abs_path);
use Nullarbor::Isolate;

#.................................................................................

my %set;

#.................................................................................

sub ids {
  return sort keys %set;
}

#.................................................................................

sub isolates {
  return values %set;
}

#.................................................................................

sub num {
  return scalar keys %set;
}

#.................................................................................

sub print {
  $_->print for values %set;
}

#.................................................................................

sub _clean_id {
  my $s = shift;
  $s =~ s/[^\w._-]/~/g;
  #$s = quotemeta($s);
  return $s;
}

#.................................................................................

sub load {
  my($self, $fname) = @_;
  %set = ();
  open ISOLATES, '<', $fname;
  while (<ISOLATES>) {
    next if m/^#/;
    chomp;
    my($id, @reads) = split m/\t/;
    next unless $id and @reads >= 1;
    $id = _clean_id($id);
    exists $set{$id} and die "Duplicate ID '$id' in dataset '$fname'";
    for my $i (0 ..$#reads) {
      $reads[$i] = abs_path($reads[$i]);
      -r $reads[$i] or die "$id sequence file '$reads[$i]' is not readable";
    }
    my $isolate = Nullarbor::Isolate->new( id=>$id, reads=>[ @reads ]);
    $set{$id} = $isolate;
  }
  close ISOLATES;
}

#.................................................................................

1;

