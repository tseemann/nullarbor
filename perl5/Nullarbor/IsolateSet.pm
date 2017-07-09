package Nullarbor::IsolateSet;
use Moo;
use Cwd qw(abs_path);
use Nullarbor::Isolate;
use Nullarbor::Logger qw(msg err);

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
    exists $set{$id} and err("Duplicate ID '$id' in dataset '$fname'");
    for my $i (0 ..$#reads) {
#      $reads[$i] or die "Sample '$id' read file #$i is null!";
#      my $old = $reads[$i];
#      print STDERR "# abs_path($old) = $reads[$i]\n";
      my $which = sprintf "#%d of %d", $i+1, $#reads;
      -r $reads[$i] or err("Isolate '$id' - can not read sequence $which files: '$reads[$i]'");
      $reads[$i] = abs_path($reads[$i]);
      $reads[$i] or err("Isolate '$id' read file #$i did not survive absolution!");
    }
    if (@reads==2) {
      $reads[0] eq $reads[1] and err("$id: R1 and R2 are same file: $reads[0]");
    }
    my $isolate = Nullarbor::Isolate->new( id=>$id, reads=>[ @reads ]);
    $set{$id} = $isolate;
  }
  close ISOLATES;
}

#.................................................................................

1;

