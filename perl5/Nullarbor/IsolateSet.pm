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
#      $reads[$i] or die "Sample '$id' read file #$i is null!";
#      my $old = $reads[$i];
#      print STDERR "# abs_path($old) = $reads[$i]\n";
      my $which = sprintf "#%d of %d", $i+1, $#reads;
      -r $reads[$i] or die "ERROR:\nIsolate '$id' - can not read sequence $which files:\n'$reads[$i]'";
      $reads[$i] = abs_path($reads[$i]);
      $reads[$i] or die "Isolate '$id' read file #$i did not survive absolution!";
    }
    my $isolate = Nullarbor::Isolate->new( id=>$id, reads=>[ @reads ]);
    $set{$id} = $isolate;
  }
  close ISOLATES;
}

#.................................................................................

1;

